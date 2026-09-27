# Native runtime libraries

Prebuilt Gelide + PDFium binaries used by desktop builds.

```
native-libs/
  windows-x64/
    gelide_core.dll
    pdfium.dll
  linux-x64/
    libgelide_core.so
    libpdfium.so
  macos-arm64/
    libgelide_core.dylib
    libpdfium.dylib
```

These files are **copied into the app bundle at build time**:

| Platform | Install location |
|----------|------------------|
| Windows  | Next to `askopdf.exe` |
| Linux    | `bundle/lib/` (`$ORIGIN/lib`) |
| macOS    | `App.app/Contents/Frameworks/` |

Do **not** put runtime DLLs under `windows/runner/third_party` anymore.

Replace a binary by overwriting the matching file here, then rebuild.
