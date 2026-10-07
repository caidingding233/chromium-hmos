#!/usr/bin/env bash

set -euo pipefail

: "${HARMONYOS_CLT_URL:?HARMONYOS_CLT_URL must point to the official Linux Command Line Tools archive}"
: "${HARMONYOS_CLT_SHA256:?HARMONYOS_CLT_SHA256 must pin the Command Line Tools archive digest}"

readonly workspace_root="${GITHUB_WORKSPACE:-$PWD}"
readonly out_root="${workspace_root}/harmonyos-cli"
readonly archive="${RUNNER_TEMP:-/tmp}/harmonyos-cli.archive"
rm -rf "${out_root}"
mkdir -p "${out_root}/root"
curl --fail --location --retry 3 --retry-delay 2 --output "${archive}" "${HARMONYOS_CLT_URL}"
echo "${HARMONYOS_CLT_SHA256}  ${archive}" | sha256sum --check --strict

if unzip -t "${archive}" >/dev/null 2>&1; then
  unzip -q "${archive}" -d "${out_root}/root"
elif tar -tf "${archive}" >/dev/null 2>&1; then
  tar -xf "${archive}" -C "${out_root}/root"
else
  echo 'The HarmonyOS Command Line Tools archive is neither a readable zip nor tar archive.' >&2
  exit 1
fi

hvigorw="$(find "${out_root}/root" -type f -name hvigorw -perm -u+x -print -quit || true)"
ohpm="$(find "${out_root}/root" -type f -name ohpm -perm -u+x -print -quit || true)"
[[ -n "${hvigorw}" && -n "${ohpm}" ]] || {
  echo 'Command Line Tools archive is missing executable hvigorw or ohpm.' >&2
  exit 1
}
clt_root="$(find "${out_root}/root" -type d -name command-line-tools -print -quit || true)"
if [[ -z "${clt_root}" ]]; then
  clt_root="$(dirname "$(dirname "${hvigorw}")")"
fi
printf '%s\n' "${hvigorw#"${workspace_root}/"}" > "${out_root}/hvigor.relative"
printf '%s\n' "${ohpm#"${workspace_root}/"}" > "${out_root}/ohpm.relative"
printf '%s\n' "${clt_root#"${workspace_root}/"}" > "${out_root}/clt_root.relative"
printf 'Verified HarmonyOS Command Line Tools (root=%s, hvigorw=%s, ohpm=%s)\n' \
  "${clt_root}" "${hvigorw}" "${ohpm}"
