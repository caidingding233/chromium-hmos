# Chromium 155 HarmonyOS adapter refresh

Baseline: Chromium Stable `155.0.8059.39`

Revision: `3ff7ac5a9224be9156d7f8703a06e22890aafd34`

## Initial compatibility failure

The pre-refresh `patches/chromium-150-harmonyos.patch` was replayed against the exact revision with `git apply --check --binary`. It failed before any build stage. The first failures were:

```text
error: patch failed: BUILD.gn:1551
error: patch failed: base/posix/unix_domain_socket.cc:168
error: patch failed: base/process/launch_posix.cc:37
error: patch failed: build/config/clang/BUILD.gn:230
error: patch failed: build/config/compiler/BUILD.gn:303
error: patch failed: chrome/app/chrome_main_delegate.cc:180
```

The complete first-pass output was retained during the refresh run. Stale hunks were dropped where Chromium 155 had already moved or removed the surrounding code; surviving HarmonyOS adapter hunks were rebased into a new patch while preserving the existing overlay and CI gates.

## Verification

- The refreshed patch passes `git apply --check --binary` on the exact revision above
- Applying the patch and copying `overlay/` passes the existing overlay checks for `AuraShell.ets`, `ohos_chrome_main_runner.cc`, and the `ohos_nweb` symlink
- `git diff --check` passes on the applied tree
- `adapter-ci.yml`, `apply-adapter.sh`, and the stable baseline now use the 155 revision

This verifies source compatibility and overlay integrity only. It does not prove a native HAP was built or that a device boots it.
