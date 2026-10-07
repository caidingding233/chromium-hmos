# GitHub-hosted HAP build

The `Track Chromium Stable` workflow can run the HAP build on a GitHub-hosted `ubuntu-24.04` runner.

Repository configuration required:

- Variable `ENABLE_HARMONYOS_GITHUB_HOSTED_BUILD=true`
- Secret `HARMONYOS_SDK_URL`: an official HarmonyOS SDK archive URL approved for this repository
- Variable `HARMONYOS_SDK_SHA256`: SHA-256 digest of that archive
- Optional secret `HARMONYOS_SIGNING_CONFIG_B64`: base64-encoded `build-profile.json5` when a signed HAP is required

The SDK preparation job downloads the archive, verifies its digest, extracts it, and requires both an `ohos_build` directory and an executable `devecocli`. It passes the verified SDK to the build job through a short-lived workflow artifact.

Use `workflow_dispatch` with `adapter_ref` set to the target adapter branch. Keep `publish_release=false` for a validation build. Set it to `true` only when the resulting HAP should be uploaded to a GitHub Release; optionally provide `release_tag`.

A successful source/overlay check or HAP build does not prove device boot or runtime compatibility.
