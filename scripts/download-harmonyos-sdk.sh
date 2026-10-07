#!/usr/bin/env bash

set -euo pipefail

: "${HARMONYOS_SDK_URL:?HARMONYOS_SDK_URL must point to the official HarmonyOS SDK archive}"
: "${HARMONYOS_SDK_SHA256:?HARMONYOS_SDK_SHA256 must pin the SDK archive digest}"

readonly project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly workspace_root="${GITHUB_WORKSPACE:-$PWD}"
readonly out_root="${workspace_root}/harmonyos-sdk"
readonly archive="${RUNNER_TEMP:-/tmp}/harmonyos-sdk.archive"
rm -rf "${out_root}"
mkdir -p "${out_root}/root"

curl --fail --location --retry 3 --retry-delay 2 --output "${archive}" "${HARMONYOS_SDK_URL}"
echo "${HARMONYOS_SDK_SHA256}  ${archive}" | sha256sum --check --strict

# The CI package is normally a tarball containing a host directory with one
# zip per SDK component. Some mirrors expose a zip (or a signed URL without
# an extension), so detect the format from the bytes rather than the URL.
if unzip -t "${archive}" >/dev/null 2>&1; then
  unzip -q "${archive}" -d "${out_root}/root"
elif tar -tf "${archive}" >/dev/null 2>&1; then
  tar -xf "${archive}" -C "${out_root}/root"
else
  echo 'The HarmonyOS SDK archive is neither a readable zip nor tar archive.' >&2
  exit 1
fi

# Locate the Linux host package by its native component. Do not use
# `ohos_build` as a marker: that path belongs to the adapter overlay copied
# into the Chromium checkout, and is not part of the official SDK package.
linux_root=""
while IFS= read -r -d '' candidate; do
  if compgen -G "${candidate}/native-linux-*.zip" >/dev/null ||
     [[ -d "${candidate}/native" ]]; then
    linux_root="${candidate}"
    break
  fi
done < <(find "${out_root}/root" -type d -name linux -print0 | sort -z)

# A few package revisions omit the `linux` directory and place the native
# component directly in the archive root. Accept that layout as well.
if [[ -z "${linux_root}" ]]; then
  native_archive="$(find "${out_root}/root" -type f -iname 'native-linux-*.zip' -print -quit || true)"
  if [[ -n "${native_archive}" ]]; then
    linux_root="$(dirname "${native_archive}")"
  fi
fi

if [[ -z "${linux_root}" || ! -d "${linux_root}" ]]; then
  echo 'Unable to locate an OpenHarmony Linux SDK package containing native-linux-*.zip.' >&2
  exit 1
fi

# Expand all Linux components (native, ets, js, previewer, toolchains). The
# HAP packaging tools use more than the native NDK, while the native build
# uses native/{llvm,sysroot}. Keep component archives out of the artifact so
# the build job receives a normal SDK tree.
shopt -s nullglob
component_archives=("${linux_root}"/*-linux-*.zip)
if ((${#component_archives[@]})); then
  for component in "${component_archives[@]}"; do
    unzip -q "${component}" -d "${linux_root}"
    rm -f "${component}"
  done
fi
shopt -u nullglob

sdk_root="${linux_root}"
for component in native ets js previewer toolchains; do
  [[ -d "${sdk_root}/${component}" ]] || {
    printf 'The OpenHarmony SDK is missing the %s component.\n' "${component}" >&2
    exit 1
  }
done
native_root="$(find "${sdk_root}" -mindepth 1 -maxdepth 2 -type d -name native -print -quit || true)"
if [[ -z "${native_root}" ]]; then
  echo 'The OpenHarmony SDK package did not contain an extracted native component.' >&2
  exit 1
fi

# Validate the actual NDK contract consumed by build/config/ohos/config.gni.
# These checks intentionally reject a public archive that was only partially
# expanded or a package for another host/architecture before HAP compilation.
for required_path in \
  "${native_root}/oh-uni-package.json" \
  "${native_root}/llvm/bin/clang" \
  "${native_root}/sysroot/usr/include" \
  "${native_root}/sysroot/usr/lib/aarch64-linux-ohos"; do
  [[ -e "${required_path}" ]] || {
    printf 'The OpenHarmony native SDK is missing %s.\n' "${required_path}" >&2
    exit 1
  }
done
[[ -x "${native_root}/llvm/bin/clang" ]] || {
  printf 'The OpenHarmony native compiler is not executable: %s\n' \
    "${native_root}/llvm/bin/clang" >&2
  exit 1
}

# Every component must describe the same API level. An explicit API pins
# the exact package; otherwise derive the minimum compatible API from this
# adapter's chromium-ui build profile so a pinned but too-old SDK is rejected.
expected_api="${HARMONYOS_SDK_API_VERSION:-}"
expected_api_exact="${HARMONYOS_SDK_API_VERSION:+true}"
if [[ -z "${expected_api}" && -f "${project_root}/overlay/chromium-ui/build-profile.json5" ]]; then
  expected_api="$(sed -nE 's/.*"compatibleSdkVersion"[[:space:]]*:[[:space:]]*"[^"]*\(([0-9]+)\)".*/\1/p' \
    "${project_root}/overlay/chromium-ui/build-profile.json5" | head -n 1)"
fi

api_values=()
for package_file in "${sdk_root}"/*/oh-uni-package.json; do
  [[ -f "${package_file}" ]] || continue
  api="$(sed -nE 's/.*"apiVersion"[[:space:]]*:[[:space:]]*"?([0-9]+)"?.*/\1/p' \
    "${package_file}" | head -n 1)"
  [[ -n "${api}" ]] && api_values+=("${api}")
done
if ((${#api_values[@]} == 0)); then
  echo 'No OpenHarmony component API metadata (oh-uni-package.json) was found.' >&2
  exit 1
fi
for api in "${api_values[@]}"; do
  if [[ "${api}" != "${api_values[0]}" ]]; then
    echo 'OpenHarmony SDK components have mismatched API versions.' >&2
    exit 1
  fi
done
if [[ -n "${expected_api}" ]]; then
  if [[ -n "${expected_api_exact}" && "${api_values[0]}" != "${expected_api}" ]]; then
    printf 'OpenHarmony SDK API %s does not match requested API %s.\n' \
      "${api_values[0]}" "${expected_api}" >&2
    exit 1
  fi
  if [[ -z "${expected_api_exact}" && $((10#${api_values[0]})) -lt $((10#${expected_api})) ]]; then
    printf 'OpenHarmony SDK API %s is older than adapter minimum API %s.\n' \
      "${api_values[0]}" "${expected_api}" >&2
    exit 1
  fi
fi

printf '%s\n' "${sdk_root#"${workspace_root}/"}" > "${out_root}/sdk_root.relative"
printf '%s\n' "${native_root#"${workspace_root}/"}" > "${out_root}/sdk_native.relative"
printf 'Verified OpenHarmony SDK archive at %s (native: %s, API: %s)\n' \
  "${sdk_root}" "${native_root}" "${api_values[0]}"

