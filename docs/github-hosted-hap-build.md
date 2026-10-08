# GitHub-hosted HAP build

The `Track Chromium Stable` workflow can run the HAP build on a GitHub-hosted `ubuntu-24.04` runner.

Repository configuration required:

- Variable `ENABLE_HARMONYOS_GITHUB_HOSTED_BUILD=true`
- Secret `HARMONYOS_SDK_URL`: an official OpenHarmony `ohos-sdk-full` or `ohos-sdk-public` archive URL approved for this repository
- Variable `HARMONYOS_SDK_SHA256`: SHA-256 digest of that outer archive
- Optional variable `HARMONYOS_SDK_API_VERSION`: exact native SDK API to accept (otherwise the adapter's `compatibleSdkVersion` is used as a minimum)
- Secret `HARMONYOS_CLT_URL`: an official Linux HarmonyOS Command Line Tools archive URL approved for this repository
- Variable `HARMONYOS_CLT_SHA256`: SHA-256 digest of that Command Line Tools archive
- Optional secret `HARMONYOS_SIGNING_CONFIG_B64`: base64-encoded `build-profile.json5` when a signed HAP is required

The OpenHarmony CI archive is a tarball whose Linux directory contains nested component ZIPs. The SDK preparation job verifies the outer archive digest, extracts the Linux `native`, `ets`, `js`, `previewer`, and `toolchains` components, and validates their API metadata and native `llvm/sysroot` contract. It writes only the verified SDK root to a short-lived workflow artifact. The adapter's `ohos_build` entry point is supplied by the Chromium overlay, not by the SDK archive.

Hvigor and ohpm are not part of the public/full SDK archive. The preparation job downloads and verifies the separate Command Line Tools archive, then passes its verified `hvigorw` and `ohpm` executables to the build job. No Huawei account token is stored in the repository workflow.

Use `workflow_dispatch` with `adapter_ref` set to the target adapter branch. Keep `publish_release=false` for a validation build. Set it to `true` only when the resulting HAP should be uploaded to a GitHub Release; optionally provide `release_tag`.

A successful source/overlay check or HAP build does not prove device boot or runtime compatibility.
