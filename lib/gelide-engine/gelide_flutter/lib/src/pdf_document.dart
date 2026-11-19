part of '../gelide.dart';

class _GelideDocument {
  final _GelideEngine _engine;
  Pointer<Void>? _handle;

  _GelideDocument(this._engine, this._handle);

  void _check() {
    if (_handle == null) throw StateError('Document is closed');
  }

  int get pageCount {
    _check();
    return _engine._pageCount(_handle!);
  }

  String? get title {
    _check();
    final ptr = _engine._getTitle(_handle!);
    if (ptr == nullptr) return null;
    final result = ptr.toDartString();
    _engine._freeString(ptr);
    return result;
  }

  String? get author {
    _check();
    final ptr = _engine._getAuthor(_handle!);
    if (ptr == nullptr) return null;
    final result = ptr.toDartString();
    _engine._freeString(ptr);
    return result;
  }

  PageSize getPageInfo(int index) {
    _check();
    final info = _engine._getPageInfo(_handle!, index);
    return PageSize(
        width: info.width, height: info.height, rotation: info.rotation);
  }

  List<PageSize> getPageInfos() {
    _check();

    try {
      final infos = _engine._getPageInfos(_handle!);
      if (infos.infos == nullptr || infos.count <= 0) {
        return List<PageSize>.generate(pageCount, getPageInfo, growable: false);
      }

      try {
        return List<PageSize>.generate(infos.count, (index) {
          final info = infos.infos.elementAt(index).ref;
          return PageSize(
            width: info.width,
            height: info.height,
            rotation: info.rotation,
          );
        }, growable: false);
      } finally {
        _engine._freePageInfos(infos);
      }
    } on UnsupportedError {
      return List<PageSize>.generate(pageCount, getPageInfo, growable: false);
    }
  }

  List<_SearchResult> search(
    int index,
    String query, {
    bool caseSensitive = false,
  }) {
    _check();
    if (query.isEmpty) return const <_SearchResult>[];
    final queryPtr = query.toNativeUtf8();
    try {
      final results =
          _engine._search(_handle!, index, queryPtr, caseSensitive ? 1 : 0);
      if (results.results == nullptr || results.count == 0) {
        return const <_SearchResult>[];
      }
      try {
        final list = <_SearchResult>[];
        for (var i = 0; i < results.count; i++) {
          final native = results.results[i];
          final rects = <double>[];
          if (native.rects != nullptr) {
            for (var j = 0; j < native.rectCount; j++) {
              final rect = native.rects[j];
              rects
                ..add(rect.left)
                ..add(rect.top)
                ..add(rect.right)
                ..add(rect.bottom);
            }
          }
          list.add(
            _SearchResult(
              native.text == nullptr ? '' : native.text.toDartString(),
              native.startIndex,
              native.endIndex,
              rects,
            ),
          );
        }
        return list;
      } finally {
        _engine._freeSearchResults(results);
      }
    } finally {
      calloc.free(queryPtr);
    }
  }

  Future<ui.Image> renderPageAsImage(int index, {double dpi = 150.0}) async {
    final bytes = await _renderPage(index, dpi);
    return _bytesToImage(bytes.data, bytes.width, bytes.height);
  }

  Future<ui.Image> renderPageSizedAsImage(
      int index, int width, int height) async {
    final bytes = await _renderPageSized(index, width, height);
    return _bytesToImage(bytes.data, bytes.width, bytes.height);
  }

  Future<ui.Image> renderTileAsImage(
      int index, int x, int y, int w, int h, int fullW, int fullH) async {
    final bytes = await _renderTile(index, x, y, w, h, fullW, fullH);
    return _bytesToImage(bytes.data, bytes.width, bytes.height);
  }

  Future<_RenderedBytes> _renderPage(int index, double dpi) async {
    return Future.microtask(() {
      _check();
      final bitmap = _engine._renderPage(_handle!, index, dpi);
      return _extractBitmap(bitmap);
    });
  }

  Future<_RenderedBytes> _renderPageSized(
      int index, int width, int height) async {
    return Future.microtask(() {
      _check();
      final bitmap = _engine._renderPageSized(_handle!, index, width, height);
      return _extractBitmap(bitmap);
    });
  }

  Future<_RenderedBytes> _renderTile(
      int index, int x, int y, int w, int h, int fullW, int fullH) async {
    return Future.microtask(() {
      _check();
      final bitmap =
          _engine._renderTile(_handle!, index, x, y, w, h, fullW, fullH);
      return _extractBitmap(bitmap);
    });
  }

  _RenderedBytes _extractBitmap(_GelideBitmapDataNative bitmap) {
    if (bitmap.data == nullptr) {
      throw Exception('Render failed');
    }
    try {
      final bytes = Uint8List.fromList(bitmap.data.asTypedList(bitmap.len));
      return _RenderedBytes(bytes, bitmap.width, bitmap.height);
    } finally {
      _engine._freeBitmap(bitmap);
    }
  }

  Future<ui.Image> _bytesToImage(Uint8List bytes, int width, int height) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      width,
      height,
      _gelidePixelFormat(),
      completer.complete,
    );
    return completer.future;
  }

  void close() {
    if (_handle != null) {
      _engine._closeDocument(_handle!);
      _handle = null;
    }
  }
}

class _RenderedBytes {
  final Uint8List data;
  final int width;
  final int height;
  _RenderedBytes(this.data, this.width, this.height);
}

class _SearchResult {
  final String text;
  final int startIndex;
  final int endIndex;
  final List<double> rects;

  const _SearchResult(this.text, this.startIndex, this.endIndex, this.rects);
}
