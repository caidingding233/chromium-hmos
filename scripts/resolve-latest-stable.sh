#!/usr/bin/env bash

set -euo pipefail

readonly release_url='https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Linux&num=1'
readonly chromium_remote='https://github.com/chromium/chromium.git'
readonly baseline_version='155.0.8059.39'

release_json="$(curl --fail --location --silent --show-error "${release_url}")"
stable_version="$(python3 -c \
  'import json, sys; print(json.load(sys.stdin)[0]["version"])' \
  <<<"${release_json}")"
stable_revision="$(git ls-remote "${chromium_remote}" "refs/tags/${stable_version}" | awk 'NR == 1 {print $1}')"

if [[ -z "${stable_revision}" ]]; then
  printf 'Could not resolve Chromium tag %s\n' "${stable_version}" >&2
  exit 1
fi

newest_version="$(printf '%s\n%s\n' "${baseline_version}" "${stable_version}" | sort -V | tail -n 1)"
is_newer=false
if [[ "${stable_version}" != "${baseline_version}" && "${newest_version}" == "${stable_version}" ]]; then
  is_newer=true
fi

printf 'Chromium stable: %s (%s)\n' "${stable_version}" "${stable_revision}"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'version=%s\n' "${stable_version}" >>"${GITHUB_OUTPUT}"
  printf 'revision=%s\n' "${stable_revision}" >>"${GITHUB_OUTPUT}"
  printf 'is_newer=%s\n' "${is_newer}" >>"${GITHUB_OUTPUT}"
fi
