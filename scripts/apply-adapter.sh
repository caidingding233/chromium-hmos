#!/usr/bin/env bash

set -euo pipefail

readonly expected_revision="3ff7ac5a9224be9156d7f8703a06e22890aafd34"
readonly project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly chromium_src="${1:-}"

if [[ -z "${chromium_src}" || ! -d "${chromium_src}/.git" ]]; then
  echo "usage: $0 /path/to/chromium/src" >&2
  exit 2
fi

actual_revision="$(git -C "${chromium_src}" rev-parse HEAD)"
if [[ "${actual_revision}" != "${expected_revision}" ]]; then
  echo "expected Chromium ${expected_revision}, got ${actual_revision}" >&2
  exit 1
fi

if [[ -n "$(git -C "${chromium_src}" status --porcelain)" ]]; then
  echo "Chromium checkout must be clean before applying the adapter." >&2
  exit 1
fi

git -C "${chromium_src}" apply --binary \
  "${project_root}/patches/chromium-150-harmonyos.patch"
rsync -a "${project_root}/overlay/" "${chromium_src}/"

deps_root="$(dirname "${chromium_src}")/deps_code/webview"
mkdir -p "${deps_root}"
rsync -a "${project_root}/external/deps_code/webview/" "${deps_root}/"

echo "Adapter applied. Configure src/ohos_sdk locally before gn gen."

