#!/usr/bin/env bash

set -euo pipefail

: "${HARMONYOS_SDK_URL:?HARMONYOS_SDK_URL must point to the official HarmonyOS SDK archive}"
: "${HARMONYOS_SDK_SHA256:?HARMONYOS_SDK_SHA256 must pin the SDK archive digest}"

readonly out_root="${GITHUB_WORKSPACE:-$PWD}/harmonyos-sdk"
readonly archive="${RUNNER_TEMP:-/tmp}/harmonyos-sdk.archive"
rm -rf "${out_root}"
mkdir -p "${out_root}/root"

curl --fail --location --retry 3 --retry-delay 2 --output "${archive}" "${HARMONYOS_SDK_URL}"
echo "${HARMONYOS_SDK_SHA256}  ${archive}" | sha256sum --check --strict

case "${HARMONYOS_SDK_URL}" in
  *.zip|*.ZIP) unzip -q "${archive}" -d "${out_root}/root" ;;
  *) tar -xf "${archive}" -C "${out_root}/root" ;;
esac

sdk_root="$(find "${out_root}/root" -type d -name ohos_build -print -quit | xargs -r dirname)"
if [[ -z "${sdk_root}" || ! -d "${sdk_root}" ]]; then
  echo 'Unable to locate an extracted HarmonyOS SDK root containing ohos_build.' >&2
  exit 1
fi

devecocli="$(find "${sdk_root}" -type f \( -name devecocli -o -name devecocli.sh \) -perm -u+x -print -quit || true)"
if [[ -z "${devecocli}" ]]; then
  echo 'The SDK archive does not contain an executable devecocli; provide the official DevEco CLI in the archive.' >&2
  exit 1
fi

printf '%s\n' "${sdk_root#"${GITHUB_WORKSPACE:-$PWD}/"}" > "${out_root}/sdk_root.relative"
printf '%s\n' "${devecocli#"${GITHUB_WORKSPACE:-$PWD}/"}" > "${out_root}/devecocli.relative"
printf 'Verified HarmonyOS SDK archive at %s\n' "${sdk_root}"
