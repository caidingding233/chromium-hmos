#!/usr/bin/env bash

set -euo pipefail

readonly project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly version="${1:?usage: $0 VERSION REVISION}"
readonly revision="${2:?usage: $0 VERSION REVISION}"
readonly work_root="${RUNNER_TEMP:?RUNNER_TEMP is required}/chromium-hmos-${GITHUB_RUN_ID:-manual}"
readonly chromium_src="${work_root}/src"
readonly artifact_dir="${GITHUB_WORKSPACE:-${project_root}}/artifacts"

command -v fetch >/dev/null || {
  echo 'depot_tools fetch is required on the self-hosted runner.' >&2
  exit 1
}
hvigor_cmd="${HARMONYOS_HVIGOR:-}"
if [[ -z "${hvigor_cmd}" ]]; then
  hvigor_cmd="$(command -v hvigorw || true)"
fi
ohpm_cmd="${HARMONYOS_OHPM:-}"
if [[ -z "${ohpm_cmd}" ]]; then
  ohpm_cmd="$(command -v ohpm || true)"
fi
if [[ -z "${hvigor_cmd}" || ! -x "${hvigor_cmd}" ]]; then
  echo 'Hvigor is required; set HARMONYOS_HVIGOR to command-line-tools/bin/hvigorw.' >&2
  exit 1
fi
if [[ -z "${ohpm_cmd}" || ! -x "${ohpm_cmd}" ]]; then
  echo 'ohpm is required; set HARMONYOS_OHPM to command-line-tools/bin/ohpm.' >&2
  exit 1
fi
: "${HARMONYOS_SDK_ROOT:?HARMONYOS_SDK_ROOT must point to a licensed local SDK}"
hap_sdk_root="${HARMONYOS_HAP_SDK_ROOT:-${HARMONYOS_SDK_ROOT}}"

mkdir -p "${work_root}" "${artifact_dir}"
cd "${work_root}"
fetch --nohooks chromium
git -C "${chromium_src}" fetch --depth=1 origin "${revision}"
git -C "${chromium_src}" checkout --detach FETCH_HEAD
gclient sync -D

"${project_root}/scripts/apply-adapter.sh" "${chromium_src}"
ln -s "${HARMONYOS_SDK_ROOT}" "${chromium_src}/ohos_sdk"
if [[ -n "${HARMONYOS_SIGNING_CONFIG_PATH:-}" ]]; then
  cp "${HARMONYOS_SIGNING_CONFIG_PATH}" \
    "${chromium_src}/chromium-ui/build-profile.json5"
fi

mkdir -p "${chromium_src}/out/plan_kirin_pc"
cp "${project_root}/config/args.plan_kirin_pc.gn" \
  "${chromium_src}/out/plan_kirin_pc/args.gn"
"${chromium_src}/ohos_build/build.sh" -j "${NINJA_JOBS:-8}" -t n plan_kirin_pc

(
  cd "${chromium_src}/chromium-ui"
  export OHOS_BASE_SDK_HOME="${hap_sdk_root}"
  export DEVECO_SDK_HOME="${hap_sdk_root}"
  "${ohpm_cmd}" --strict_ssl false install
  "${hvigor_cmd}" --mode=module clean -p debuggable=false \
    -p product=default -p buildMode=release assembleHap --no-daemon
)

built_hap="$(find "${chromium_src}/chromium-ui/entry/build/default" \
  -type f -name '*-signed.hap' | LC_ALL=C sort | tail -n 1)"
if [[ -z "${built_hap}" ]]; then
  built_hap="$(find "${chromium_src}/chromium-ui/entry/build/default" \
    -type f -name '*-unsigned.hap' | LC_ALL=C sort | tail -n 1)"
fi
[[ -n "${built_hap}" ]] || {
  echo 'Hvigor did not produce a Chromium HarmonyOS Adapter HAP.' >&2
  exit 1
}

hap_entries="$(unzip -Z1 "${built_hap}")"
for required_entry in \
  libs/arm64-v8a/libweb_engine.so \
  libs/arm64-v8a/libnweb_render.so \
  libs/arm64-v8a/libEGL_angle.so \
  libs/arm64-v8a/libGLESv2_angle.so \
  resources/rawfile/chromium/icudtl.dat \
  resources/rawfile/chromium/resources.pak; do
  grep -Fxq "${required_entry}" <<<"${hap_entries}" || {
    printf 'Built HAP is missing %s\n' "${required_entry}" >&2
    exit 1
  }
done

cp "${built_hap}" "${artifact_dir}/Chromium-HarmonyOS-${version}.hap"
