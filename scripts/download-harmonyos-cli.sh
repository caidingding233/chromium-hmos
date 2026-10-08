#!/usr/bin/env bash

set -euo pipefail

readonly workspace_root="${GITHUB_WORKSPACE:-$PWD}"
readonly out_root="${workspace_root}/harmonyos-cli"
readonly archive="${RUNNER_TEMP:-/tmp}/harmonyos-cli.tar.gz"
readonly version="${HARMONYOS_CLT_VERSION:-6.0.0.858}"
readonly release_api="https://api.github.com/repos/ErBWs/ohos-sdk/releases/tags/${version}"
rm -rf "${out_root}"
mkdir -p "${out_root}/root"

# ErBWs/ohos-sdk publishes the complete Linux CLI/SDK as split GitHub release
# assets, with a checksum sidecar. This includes hvigorw and ohpm, unlike the
# lightweight sdkmgr-only commandline-tools archive.
command -v jq >/dev/null || { echo 'jq is required to resolve the public CLI release.' >&2; exit 1; }
release_json="$(curl --fail --location --retry 3 --retry-delay 2 \
  -H 'Accept: application/vnd.github+json' "${release_api}")"
asset_url() {
  jq -r --arg name "$1" '.assets[] | select(.name == $name) | .browser_download_url' <<<"${release_json}"
}
part_a="$(asset_url ohos-sdk-linux-amd64.tar.gz.aa)"
part_b="$(asset_url ohos-sdk-linux-amd64.tar.gz.ab)"
checksum_url="$(asset_url ohos-sdk-linux-amd64.tar.gz.sha256)"
[[ -n "${part_a}" && -n "${part_b}" && -n "${checksum_url}" ]] || {
  echo "The public CLI release ${version} is missing Linux archive parts or checksum." >&2
  exit 1
}
curl --fail --location --retry 3 --retry-delay 2 --output "${archive}.aa" "${part_a}"
curl --fail --location --retry 3 --retry-delay 2 --output "${archive}.ab" "${part_b}"
curl --fail --location --retry 3 --retry-delay 2 --output "${archive}.sha256" "${checksum_url}"
cat "${archive}.aa" "${archive}.ab" > "${archive}"
expected_sha="$(awk '{print $1}' "${archive}.sha256")"
echo "${expected_sha}  ${archive}" | sha256sum --check --strict
rm -f "${archive}.aa" "${archive}.ab" "${archive}.sha256"
tar -xzf "${archive}" -C "${out_root}/root"

hvigorw="$(find "${out_root}/root" -type f -name hvigorw -print -quit || true)"
ohpm="$(find "${out_root}/root" -type f -name ohpm -print -quit || true)"
[[ -n "${hvigorw}" && -n "${ohpm}" ]] || {
  echo 'Public CLI archive is missing hvigorw or ohpm.' >&2
  exit 1
}
chmod +x "${hvigorw}" "${ohpm}"
clt_root="$(find "${out_root}/root" -type d -name command-line-tools -print -quit || true)"
if [[ -z "${clt_root}" ]]; then
  clt_root="$(dirname "$(dirname "${hvigorw}")")"
fi
printf '%s\n' "${hvigorw#"${workspace_root}/"}" > "${out_root}/hvigor.relative"
printf '%s\n' "${ohpm#"${workspace_root}/"}" > "${out_root}/ohpm.relative"
printf '%s\n' "${clt_root#"${workspace_root}/"}" > "${out_root}/clt_root.relative"
printf 'Verified public HarmonyOS CLI release %s (root=%s, hvigorw=%s, ohpm=%s)\n' \
  "${version}" "${clt_root}" "${hvigorw}" "${ohpm}"
