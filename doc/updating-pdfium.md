# Updating PDFium

pdfrx uses [bblanchon/pdfium-binaries](https://github.com/bblanchon/pdfium-binaries)
on every platform. `packages/pdfium_dart/pdfium.json` pins the release and the
SHA-256 of every archive, the web `pdfium.wasm` and the Apple XCFramework.
The `Upstream watch` workflow alerts when a newer release is out.

| Where | Reads |
|---|---|
| `packages/pdfium_dart/hook/build.dart` (Android, Linux, macOS, Windows) | `pdfium.json`: downloads the archive and checks its SHA-256 |
| `packages/pdfium_dart/tool/ffigen.dart` (bindings) | `pdfium.json`: headers from the pinned linux-x64 archive |
| `packages/pdfrx/assets/pdfium.wasm` (web) | copied from the pinned `wasm` archive |
| `packages/pdfium_flutter/darwin/` podspec and `Package.swift` (iOS, macOS) | the XCFramework URL and SHA-256, by hand |

`packages/pdfium_dart/test/pdfium_pins_test.dart` fails when the podspec,
`Package.swift`, the WASM or the XCFramework does not match `pdfium.json`.
`packages/pdfrx/test/pdfium_wasm_imports_test.cjs` fails when the WASM needs
an import `pdfium_worker.js` does not supply.

## Steps

1. **Pins and WASM.** From `packages/pdfium_dart`:

   ```sh
   dart tool/update_pdfium.dart 8138
   ```

   It checks each archive against the digest GitHub reports, writes
   `pdfium.json`, installs `pdfium.wasm`, and keeps the archives in
   `.dart_tool/pdfium_archives/<build>/`. It drops the `xcframework` pin,
   which belongs to the old release.

2. **Bindings.** `dart tool/ffigen.dart`. Check what changed in
   `lib/src/pdfium_bindings.dart`: new functions are fine; changed signatures
   or struct layouts need code changes.

3. **Web.** `node --test packages/pdfrx/test/*.cjs`. If the imports test lists
   a missing function, add it to `emEnv` or `wasi` in
   `packages/pdfrx/assets/pdfium_worker.js` (Emscripten's `pdfium.js` in the
   `wasm` archive shows what it does).

4. **XCFramework** (macOS with Xcode). From the repository root:

   ```sh
   ARCHIVE_DIR=$PWD/packages/pdfium_dart/.dart_tool/pdfium_archives/8138 \
     VERSION=159.0.8138.0 RELEASE_TAG=chromium/8138 \
     WORK_DIR=/tmp/xcf_work OUTPUT_DIR=/tmp/xcf_out \
     packages/pdfium_flutter/tool/build_xcframework.sh
   ```

   `VERSION` is in `pdfium.json`. The script checks every archive against
   `pdfium.json`. Publish the zip, its `.sha256` and a `provenance.txt` (the
   input and output hashes) as a new prerelease,
   `pdfium-xcframework-chromium-<build>`. Never replace a file a checked-in
   hash refers to. Then put the URL and SHA-256 in `pdfium.json`
   (`xcframework`, with `release`), the podspec and `Package.swift`.

5. **Test**: Unit's steps, then Integration (started by hand on the branch:
   `gh workflow run integration.yml --ref <branch>`), which covers iOS,
   macOS, Android, Windows, Linux and the web.

## Notes

- pdfium-binaries builds its Apple libraries with a recent SDK's minimum OS
  (iOS 17 and macOS 13 for 8138). The XCFramework script lowers it to iOS 13
  and macOS 10.15, as upstream's does, because pdfrx supports iOS 15 and
  macOS 12; Integration's iOS and macOS jobs run the result.
- `link.dart` keeps macOS apps from bundling both the XCFramework and the
  hook's `libpdfium.dylib`.
