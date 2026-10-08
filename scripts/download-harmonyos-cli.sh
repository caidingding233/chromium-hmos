#!/usr/bin/env bash

set -euo pipefail

asset_name="${HARMONYOS_CLT_ASSET_NAME:-commandline-tools-linux-2.0.0.2.zip}"
clt_url="${HARMONYOS_CLT_URL:-}"
clt_sha256="${HARMONYOS_CLT_SHA256:-}"
if [[ -z "${clt_url}" ]]; then
  command -v jq >/dev/null || { echo 'jq is required when resolving the public CLI release.' >&2; exit 1; }
  release_json="$(curl --fail --location --retry 3 --retry-delay 2     -H 'Accept: application/vnd.github+json'     'https://api.github.com/repos/harmonyos-dev/hos-sdk/releases/latest')"
  clt_url="$(jq -r --arg name "${asset_name}" '.assets[] | select(.name == $name) | .browser_download_url' <<<"${release_json}")"
  digest="$(jq -r --arg name "${asset_name}" '.assets[] | select(.name == $name) | .digest // empty' <<<"${release_json}")"
  [[ -n "${clt_url}" && "${clt_url}" != null ]] || { printf 'CLI asset %s was not found in the public release.\n' "${asset_name}" >&2; exit 1; }
  if [[ -z "${clt_sha256}" && "${digest}" == sha256:* ]]; then
    clt_sha256="${digest#sha256:}"
  fi
fi
: "${clt_sha256:?HARMONYOS_CLT_SHA256 is required when the release asset has no digest}"

readonly workspace_root="${GITHUB_WORKSPACE:-$PWD}"
readonly out_root="${workspace_root}/harmonyos-cli"
readonly archive="${RUNNER_TEMP:-/tmp}/harmonyos-cli.archive"
rm -rf "${out_root}"
mkdir -p "${out_root}/root"
curl --fail --location --retry 3 --retry-delay 2 --output "${archive}" "${clt_url}"
echo "${clt_sha256}  ${archive}" | sha256sum --check --strict

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
