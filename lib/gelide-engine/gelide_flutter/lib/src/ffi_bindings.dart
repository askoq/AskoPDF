part of '../gelide.dart';

int _nativeUtf8AllocationSize(String value) {
  var byteLength = 1;
  for (final codePoint in value.runes) {
    byteLength += switch (codePoint) {
      <= 0x7F => 1,
      <= 0x7FF => 2,
      <= 0xFFFF => 3,
      _ => 4,
    };
  }
  return byteLength;
}

void _wipeNativeUtf8(Pointer<Utf8> value, int allocationSize) {
  value.cast<Uint8>().asTypedList(allocationSize).fillRange(
        0,
        allocationSize,
        0,
      );
}

class _GelideEngine {
  static const bool _allowSystemNativeLibraries = bool.fromEnvironment(
    'ASKO_ALLOW_SYSTEM_NATIVE_LIBS',
    defaultValue: false,
  );

  late DynamicLibrary _lib;
  Pointer<Void>? _handle;

  late final Pointer<Void> Function(Pointer<Utf8>) _createEngine;
  late final void Function(Pointer<Void>) _destroyEngine;
  late final Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>) _openDocument;
  late final Pointer<Void> Function(
    Pointer<Void>,
    Pointer<Utf8>,
    Pointer<Utf8>,
  ) _openDocumentWithPassword;
  late final void Function(Pointer<Void>) _closeDocument;
  late final int Function(Pointer<Void>) _pageCount;
  late final _GelideBitmapDataNative Function(Pointer<Void>, int, double)
      _renderPage;
  late final _GelideBitmapDataNative Function(Pointer<Void>, int, int, int)
      _renderPageSized;
  late final _GelideBitmapDataNative Function(
      Pointer<Void>, int, int, int, int, int, int, int) _renderTile;
  late final void Function(_GelideBitmapDataNative) _freeBitmap;
  late final _GelidePageInfoNative Function(Pointer<Void>, int) _getPageInfo;
  late final _GelidePageInfosNative Function(Pointer<Void>) _getPageInfos;
  late final void Function(_GelidePageInfosNative) _freePageInfos;
  late final void Function(Pointer<Utf8>) _freeString;
  late final Pointer<Utf8> Function(Pointer<Void>) _getTitle;
  late final Pointer<Utf8> Function(Pointer<Void>) _getAuthor;
  late final Pointer<Utf8> Function() _getLastErrorMessage;
  late final int Function() _getLastErrorCode;

  Future<void> init(String pdfiumPath) async {
    _lib = _loadLibrary();
    _initBindings();

    final pathPtr = pdfiumPath.toNativeUtf8();
    try {
      _handle = _createEngine(pathPtr.cast());
      if (_handle == nullptr) {
        final details = _consumeNativeErrorMessage();
        final pdfiumName = _pdfiumLibraryName;
        throw Exception(
          details == null
              ? 'Failed to initialize PDF engine. Check $pdfiumName path: $pdfiumPath'
              : 'Failed to initialize PDF engine: $details',
        );
      }
    } finally {
      calloc.free(pathPtr);
    }
  }

  DynamicLibrary _loadLibrary() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;

    if (Platform.isWindows) {
      final local = '$exeDir${Platform.pathSeparator}gelide_core.dll';
      if (File(local).existsSync()) {
        return DynamicLibrary.open(local);
      }
      if (_allowSystemNativeLibraries) {
        return DynamicLibrary.open('gelide_core.dll');
      }
      throw UnsupportedError('Bundled native library is missing: $local');
    }

    if (Platform.isAndroid) {
      return DynamicLibrary.open('libgelide_core.so');
    }

    if (Platform.isLinux) {
      final candidates = [
        '$exeDir${Platform.pathSeparator}lib${Platform.pathSeparator}libgelide_core.so',
        '$exeDir${Platform.pathSeparator}libgelide_core.so',
      ];
      for (final path in candidates) {
        if (File(path).existsSync()) {
          return DynamicLibrary.open(path);
        }
      }
      if (_allowSystemNativeLibraries) {
        return DynamicLibrary.open('libgelide_core.so');
      }
      throw UnsupportedError(
        'Bundled native library libgelide_core.so was not found next to the application.',
      );
    }

    if (Platform.isMacOS || Platform.isIOS) {
      String? frameworksDir;
      try {
        frameworksDir = Directory(
          '$exeDir${Platform.pathSeparator}..${Platform.pathSeparator}Frameworks',
        ).resolveSymbolicLinksSync();
      } catch (_) {
        frameworksDir = null;
      }
      final candidates = <String>[
        if (frameworksDir != null)
          '$frameworksDir${Platform.pathSeparator}libgelide_core.dylib',
        '$exeDir${Platform.pathSeparator}libgelide_core.dylib',
      ];
      for (final path in candidates) {
        if (File(path).existsSync()) {
          return DynamicLibrary.open(path);
        }
      }
      if (_allowSystemNativeLibraries) {
        return DynamicLibrary.open('libgelide_core.dylib');
      }
      throw UnsupportedError(
        'Bundled native library libgelide_core.dylib was not found in the application bundle.',
      );
    }

    throw UnsupportedError('Platform not supported');
  }

  void _initBindings() {
    _createEngine = _lib.lookupFunction<Pointer<Void> Function(Pointer<Utf8>),
        Pointer<Void> Function(Pointer<Utf8>)>('gelide_create_engine');

    _destroyEngine = _lib.lookupFunction<Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('gelide_destroy_engine');

    _openDocument = _lib.lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>),
        Pointer<Void> Function(
            Pointer<Void>, Pointer<Utf8>)>('gelide_open_document');

    try {
      _openDocumentWithPassword = _lib.lookupFunction<
          Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>),
          Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>)>(
        'gelide_open_document_with_password',
      );
    } on ArgumentError {
      _openDocumentWithPassword = _openDocumentWithPasswordUnavailable;
    }

    _closeDocument = _lib.lookupFunction<Void Function(Pointer<Void>),
        void Function(Pointer<Void>)>('gelide_close_document');

    _pageCount = _lib.lookupFunction<Int32 Function(Pointer<Void>),
        int Function(Pointer<Void>)>('gelide_document_page_count');

    _renderPage = _lib.lookupFunction<
        _GelideBitmapDataNative Function(Pointer<Void>, Int32, Float),
        _GelideBitmapDataNative Function(
            Pointer<Void>, int, double)>('gelide_render_page');

    _renderPageSized = _lib.lookupFunction<
        _GelideBitmapDataNative Function(Pointer<Void>, Int32, Uint32, Uint32),
        _GelideBitmapDataNative Function(
            Pointer<Void>, int, int, int)>('gelide_render_page_sized');

    _renderTile = _lib.lookupFunction<
        _GelideBitmapDataNative Function(Pointer<Void>, Int32, Uint32, Uint32,
            Uint32, Uint32, Uint32, Uint32),
        _GelideBitmapDataNative Function(Pointer<Void>, int, int, int, int, int,
            int, int)>('gelide_render_tile');

    _freeBitmap = _lib.lookupFunction<Void Function(_GelideBitmapDataNative),
        void Function(_GelideBitmapDataNative)>('gelide_free_bitmap');

    _getPageInfo = _lib.lookupFunction<
        _GelidePageInfoNative Function(Pointer<Void>, Int32),
        _GelidePageInfoNative Function(
            Pointer<Void>, int)>('gelide_get_page_info');

    try {
      _getPageInfos = _lib.lookupFunction<
          _GelidePageInfosNative Function(Pointer<Void>),
          _GelidePageInfosNative Function(Pointer<Void>)>(
        'gelide_get_page_infos',
      );
    } on ArgumentError {
      _getPageInfos = _getPageInfosUnavailable;
    }

    try {
      _freePageInfos = _lib.lookupFunction<
          Void Function(_GelidePageInfosNative),
          void Function(_GelidePageInfosNative)>('gelide_free_page_infos');
    } on ArgumentError {
      _freePageInfos = _freePageInfosNoop;
    }

    _freeString = _lib.lookupFunction<Void Function(Pointer<Utf8>),
        void Function(Pointer<Utf8>)>('gelide_free_string');

    _getTitle = _lib.lookupFunction<Pointer<Utf8> Function(Pointer<Void>),
        Pointer<Utf8> Function(Pointer<Void>)>('gelide_get_title');

    _getAuthor = _lib.lookupFunction<Pointer<Utf8> Function(Pointer<Void>),
        Pointer<Utf8> Function(Pointer<Void>)>('gelide_get_author');

    try {
      _getLastErrorMessage = _lib.lookupFunction<Pointer<Utf8> Function(),
          Pointer<Utf8> Function()>('gelide_get_last_error_message');
    } on ArgumentError {
      _getLastErrorMessage = _getLastErrorMessageUnavailable;
    }

    try {
      _getLastErrorCode = _lib.lookupFunction<Int32 Function(), int Function()>(
        'gelide_get_last_error_code',
      );
    } on ArgumentError {
      _getLastErrorCode = _getLastErrorCodeUnavailable;
    }
  }

  String? _consumeNativeErrorMessage() {
    final ptr = _getLastErrorMessage();
    if (ptr == nullptr) return null;
    final message = ptr.toDartString().trim();
    _freeString(ptr);
    return message.isEmpty ? null : message;
  }

  Pointer<Utf8> _getLastErrorMessageUnavailable() => nullptr;

  int _getLastErrorCodeUnavailable() => 0;

  GelideNativeOpenIssue _nativeOpenIssue(int code) => switch (code) {
        1 => GelideNativeOpenIssue.passwordRequired,
        2 => GelideNativeOpenIssue.invalidPassword,
        3 => GelideNativeOpenIssue.damaged,
        4 => GelideNativeOpenIssue.unreadable,
        5 => GelideNativeOpenIssue.unsupportedSecurity,
        _ => GelideNativeOpenIssue.unknown,
      };

  static String get _nativeLibraryName {
    if (Platform.isWindows) return 'gelide_core.dll';
    if (Platform.isLinux || Platform.isAndroid) return 'libgelide_core.so';
    if (Platform.isMacOS || Platform.isIOS) return 'libgelide_core.dylib';
    return 'libgelide_core.so';
  }

  static String get _pdfiumLibraryName {
    if (Platform.isWindows) return 'pdfium.dll';
    if (Platform.isLinux || Platform.isAndroid) return 'libpdfium.so';
    if (Platform.isMacOS || Platform.isIOS) return 'libpdfium.dylib';
    return 'libpdfium.so';
  }

  _GelidePageInfosNative _getPageInfosUnavailable(Pointer<Void> handle) {
    throw UnsupportedError(
      'Native page info symbol gelide_get_page_infos is not available in the loaded $_nativeLibraryName.',
    );
  }

  void _freePageInfosNoop(_GelidePageInfosNative infos) {}

  Pointer<Void> _openDocumentWithPasswordUnavailable(
    Pointer<Void> engine,
    Pointer<Utf8> path,
    Pointer<Utf8> password,
  ) {
    throw UnsupportedError(
      'Native password-open symbol gelide_open_document_with_password is not available in the loaded $_nativeLibraryName. '
      'Rebuild and replace the native library to open protected PDF files.',
    );
  }

  _GelideDocument openDocument(String path, {String? password}) {
    final pathPtr = path.toNativeUtf8();
    Pointer<Utf8>? passwordPtr;
    final passwordAllocationSize =
        password == null ? 0 : _nativeUtf8AllocationSize(password);
    try {
      final docHandle = password == null
          ? _openDocument(_handle!, pathPtr.cast())
          : _openDocumentWithPassword(
              _handle!,
              pathPtr.cast(),
              (passwordPtr = password.toNativeUtf8()).cast(),
            );
      if (docHandle == nullptr) {
        final issue = _nativeOpenIssue(_getLastErrorCode());
        final details = _consumeNativeErrorMessage();
        throw GelideNativeOpenException(
          path: path,
          details: details == null
              ? 'Failed to open PDF: $path'
              : 'Failed to open PDF: $path\n$details',
          issue: issue,
        );
      }
      return _GelideDocument(this, docHandle);
    } finally {
      if (passwordPtr != null) {
        _wipeNativeUtf8(passwordPtr, passwordAllocationSize);
        calloc.free(passwordPtr);
      }
      calloc.free(pathPtr);
    }
  }

  void dispose() {
    if (_handle != null) {
      _destroyEngine(_handle!);
      _handle = null;
    }
  }
}
