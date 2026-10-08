# Build Notes

## Prerequisites

- A complete Chromium checkout with `depot_tools` and all DEPS synchronized.
- Linux or WSL for Chromium native compilation.
- A compatible HarmonyOS SDK/NDK and Rust toolchain supplied by the developer.
- DevEco Studio/Hvigor for the ArkUI HAP shell.

The SDK and signing files are intentionally not redistributed by this project.
For an OpenHarmony CI full/public archive, unpack the outer tarball and the
Linux component ZIPs, then place or link the resulting `linux` directory at
`src/ohos_sdk` after applying the adapter. It must contain `native/{llvm,sysroot}`
and the matching `ets`, `js`, `previewer`, and `toolchains` components.
The `ohos_build` entry point comes from this adapter's overlay. Hvigor and
ohpm come from the separately installed command-line-tools package; set
`HARMONYOS_HVIGOR` and `HARMONYOS_OHPM` when invoking the CI build script.
The adapter also expects the WebView interface tree at
`../deps_code/webview`; `scripts/apply-adapter.sh` installs the published copy.

## Prepare Chromium

```bash
ADAPTER_ROOT=/path/to/chromium-hmos-adapter
git -C /path/to/chromium/src checkout f405107495a07cb1bfcf687d4af8d91117098db6
gclient sync -D
"${ADAPTER_ROOT}/scripts/apply-adapter.sh" /path/to/chromium/src
mkdir -p /path/to/chromium/src/out/plan_kirin_pc
cp "${ADAPTER_ROOT}/config/args.plan_kirin_pc.gn" \
  /path/to/chromium/src/out/plan_kirin_pc/args.gn
```

## Native Targets

From the Chromium source directory:

```bash
gn gen out/plan_kirin_pc
autoninja -C out/plan_kirin_pc \
  chrome libweb_engine web_render libnweb_render
```

The tested configuration uses Chromium branding, keeps V8 JavaScript enabled
in JITless mode, and executes WebAssembly through the DrumBrake interpreter.
It also enables the Chromium AAC/H.264 build switches used by the validated
test package. Those switches do not grant codec patent or distribution rights;
distributors remain responsible for the licenses required in their markets.

## HAP

The ArkUI project is under `chromium-ui`. Configure signing locally in DevEco
Studio. Do not commit generated signing blocks or `.cer`, `.p12`, or `.p7b`
files. The native build must be staged into the ArkUI project before running
`hvigorw --mode=module clean -p debuggable=false assembleHap --no-daemon` (with `ohpm install` first).

This publication is a source snapshot, not a promise that every third-party
machine has the same private SDK build used for the original test package.
