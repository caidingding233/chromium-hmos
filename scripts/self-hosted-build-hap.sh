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
devecocli_cmd="${HARMONYOS_DEVECOLI:-}"
if [[ -z "${devecocli_cmd}" ]]; then
  devecocli_cmd="$(command -v devecocli || true)"
fi
if [[ -z "${devecocli_cmd}" || ! -x "${devecocli_cmd}" ]]; then
  echo 'devecocli is required; set HARMONYOS_DEVECOLI or install it on the runner.' >&2
  exit 1
fi
: "${HARMONYOS_SDK_ROOT:?HARMONYOS_SDK_ROOT must point to a licensed local SDK}"

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
  "${devecocli_cmd}" build --product default --modules entry@default --build-mode release
)

built_hap="$(find "${chromium_src}/chromium-ui/entry/build/default" \
  -type f -name '*-signed.hap' | LC_ALL=C sort | tail -n 1)"
if [[ -z "${built_hap}" ]]; then
  built_hap="$(find "${chromium_src}/chromium-ui/entry/build/default" \
    -type f -name '*-unsigned.hap' | LC_ALL=C sort | tail -n 1)"
fi
[[ -n "${built_hap}" ]] || {
  echo 'devecocli did not produce a Chromium HarmonyOS Adapter HAP.' >&2
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
