<p align="center">
  <img
    width="760"
    alt="AskoPDF"
    src="https://github.com/user-attachments/assets/45532307-eeae-4e34-a219-c3234836fe13"
  />
</p>

<p align="center">
  <b>A free PDF viewer for all</b><br/>
  Page groups, OCR, text-to-speech, annotations and split view — all in one app.
</p>

<p align="center">
  <a href="https://github.com/askoq/askopdf/releases/latest">
    <img
      src="https://img.shields.io/github/v/release/askoq/askopdf?style=for-the-badge&color=007AFF&label=DOWNLOAD%20LATEST"
      alt="Download Latest Version"
    />
  </a>
  <a href="https://askopdf.github.io">
    <img
      src="https://img.shields.io/badge/WEBSITE-askopdf.github.io-555?style=for-the-badge"
      alt="Website"
    />
  </a>
  <a href="https://github.com/askoq/askopdf/blob/main/LICENSE">
    <img
      src="https://img.shields.io/github/license/askoq/askopdf?style=for-the-badge&color=2EA043"
      alt="License"
    />
  </a>
</p>

<p align="center">
  <img
    width="900"
    alt="AskoPDF screenshot"
    src="https://github.com/user-attachments/assets/fb8a2292-8a57-4dd8-84fb-d6d9f5088960"
  />
</p>

## Download

| Platform | Download |
|---|---|
| **Windows** (x64) | [Installer (.msi)](https://github.com/askoq/askopdf/releases/latest) · [Portable (.zip)](https://github.com/askoq/askopdf/releases/latest) |
| **macOS** (Apple Silicon, macOS 13+) | [.zip](https://github.com/askoq/askopdf/releases/latest) |
| **Linux** (x64) | [AppImage](https://github.com/askoq/askopdf/releases/latest) · [.deb](https://github.com/askoq/askopdf/releases/latest) · [.tar.gz](https://github.com/askoq/askopdf/releases/latest) |

All files are on the [latest release](https://github.com/askoq/askopdf/releases/latest) page. The [website](https://askopdf.github.io) picks the right one for your system.

## Features

- **Page groups** - collect pages from anywhere in a file into a named, colored group, then read, print or export just those pages. The file itself stays as it is. See the [Groups guide](GROUPS_GUIDE.md).
- **Fast and smooth** - pages are rendered by PDFium through Gelide, AskoPDF's own core, built to stay smooth on large documents.
- **Tabs, Split View and Projects** - open documents side by side and keep sets of files together as a project that remembers your workspace.
- **Annotations** - highlight, underline, strikethrough, squiggly underline and notes on selected text, then export an annotated copy.
- **OCR** - recognize text from a page or a selected area, in several languages, with a recognition history.
- **Text-to-Speech** - select text and listen to it, with Supertonic or Kokoro voices.
- **PDF tools** - black out text, add a visual signature, merge files, set a password, print.
- **Navigation** - page thumbnails, outline (table of contents), search, and page reordering or deletion.
- **Comfortable reading** - dark mode, document background themes, a Clean Screen mode and keyboard shortcuts.
- **5 languages** - English, Russian, Chinese (Simplified), Portuguese and Spanish.

## Build from source

<details>
<summary>Requirements, running and release builds</summary>

This repository contains the source code based on version 1.0.0, along with later fixes and improvements. The Gelide core is included as prebuilt binaries.

### Requirements

[Git](https://git-scm.com/downloads) and [Flutter](https://docs.flutter.dev/get-started/install) with desktop support enabled, plus the build tools for your system:

* Windows: Visual Studio with the Desktop development with C++ workload
* Linux: a C++ compiler and GTK development packages
* macOS: Xcode with the command-line tools installed

Check that Flutter is set up:

```bash
flutter doctor
```

### Run

```bash
git clone https://github.com/askoq/askopdf.git
cd askopdf
flutter pub get
flutter run -d windows   # or: -d linux, -d macos
```

The Gelide core and PDFium libraries are already in [`native-libs/`](native-libs/); the build copies the right ones for each platform, so no extra setup is needed.

### Release build

```bash
flutter build windows --release   # or: linux, macos
```

The finished app is placed in the matching platform folder inside `build/`.

</details>

---

## Credits

AskoPDF is built on these projects. Models are downloaded from their original pages on first use and keep their own licenses:

- [PDFium](https://pdfium.googlesource.com/pdfium/) - PDF rendering
- [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR) models - text recognition ([monkt/paddleocr-onnx](https://huggingface.co/monkt/paddleocr-onnx)) and page layout detection ([PP-DocLayout-S ONNX](https://huggingface.co/stefanj0/PP-DocLayout-S-ONNX))
- [Supertonic 3](https://huggingface.co/Supertone/supertonic-3) by Supertone - text-to-speech, model under the OpenRAIL-M license (its use restrictions apply)
- [Kokoro-82M](https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX) - text-to-speech

---

## License

AskoPDF and the Gelide core (binaries included in [`native-libs/`](native-libs/)) are licensed under the [Apache License 2.0](LICENSE).
