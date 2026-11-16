
library gelide;

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';

part 'src/ffi_structs.dart';
part 'src/ffi_bindings.dart';
part 'src/pdf_document.dart';
part 'src/worker.dart';

enum GelideNativeOpenIssue {
  passwordRequired,
  invalidPassword,
  damaged,
  unreadable,
  unsupportedSecurity,
  unknown,
}

class GelideNativeOpenException implements Exception {
  final String path;
  final String details;
  final GelideNativeOpenIssue issue;

  const GelideNativeOpenException({
    required this.path,
    required this.details,
    this.issue = GelideNativeOpenIssue.unknown,
  });

  @override
  String toString() => details;
}

ui.PixelFormat _gelidePixelFormat() {
  return ui.PixelFormat.rgba8888;
}

class Gelide {
  static const bool _allowSystemNativeLibraries = bool.fromEnvironment(
    'ASKO_ALLOW_SYSTEM_NATIVE_LIBS',
    defaultValue: false,
  );

  static _GelideWorkerClient? _worker;
  static Future<void>? _initializing;

  Gelide._();

  static Future<void> init([String? pdfiumPath]) async {
    if (_worker != null) return;
    final pending = _initializing;
    if (pending != null) return pending;

    final initializing = _GelideWorkerClient.start(
      pdfiumPath ?? _findPdfium(),
    ).then<void>((worker) {
      _worker = worker;
    });
    _initializing = initializing;
    try {
      await initializing;
    } finally {
      if (identical(_initializing, initializing)) {
        _initializing = null;
      }
    }
  }

  static Future<GelidePdf> open(String path, {String? password}) async {
    final worker = _requireWorker();
    final descriptor = await worker.openDocument(path, password: password);
    return GelidePdf._(worker, descriptor);
  }

  static Future<GelidePdf> openBytes(Uint8List bytes, {String? name}) async {
    final worker = _requireWorker();
    if (bytes.isEmpty || bytes.length > 512 * 1024 * 1024) {
      throw ArgumentError.value(
        bytes.length,
        'bytes',
        'PDF data must be between 1 byte and 512 MB',
      );
    }

    final tempDirectory = await Directory.systemTemp.createTemp(
      'gelide-bytes-',
    );
    final rawName = (name ?? 'document.pdf').split(RegExp(r'[/\\]')).last;
    final safeName =
        rawName.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
    final tempFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}${safeName.isEmpty ? 'document.pdf' : safeName}',
    );
    try {
      await tempFile.writeAsBytes(bytes, flush: true);
      final descriptor = await worker.openDocument(tempFile.path);
      final pdf = GelidePdf._(worker, descriptor);
      pdf._tempDirectory = tempDirectory;
      return pdf;
    } catch (_) {
      try {
        await tempDirectory.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }

  static Future<GelidePdf> openAsset(
      String assetPath, AssetBundle bundle) async {
    final data = await bundle.load(assetPath);
    return openBytes(data.buffer.asUint8List(),
        name: assetPath.split('/').last);
  }

  static void dispose() {
    final worker = _worker;
    _worker = null;
    if (worker != null) {
      unawaited(() async {
        try {
          await worker.shutdown();
        } catch (_) {}
      }());
    }
  }

  static _GelideWorkerClient _requireWorker() {
    final worker = _worker;
    if (worker == null) {
      throw StateError('Gelide not initialized. Call Gelide.init() first.\n'
          'Example:\n'
          '  void main() async {\n'
          '    WidgetsFlutterBinding.ensureInitialized();\n'
          '    await Gelide.init();\n'
          '    runApp(MyApp());\n'
          '  }');
    }
    return worker;
  }

  static String _findPdfium() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;

    if (Platform.isWindows) {
      final candidates = [
        '$exeDir${Platform.pathSeparator}pdfium.dll',
        '$exeDir${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}pdfium.dll',
      ];
      for (final path in candidates) {
        if (File(path).existsSync()) return path;
      }
      if (_allowSystemNativeLibraries) return 'pdfium.dll';
      throw UnsupportedError(
          'Bundled pdfium.dll was not found next to the application.');
    }

    if (Platform.isAndroid) return 'libpdfium.so';

    if (Platform.isLinux) {
      final candidates = [
        '$exeDir${Platform.pathSeparator}lib${Platform.pathSeparator}libpdfium.so',
        '$exeDir${Platform.pathSeparator}libpdfium.so',
      ];
      for (final path in candidates) {
        if (File(path).existsSync()) return path;
      }
      if (_allowSystemNativeLibraries) return 'libpdfium.so';
      throw UnsupportedError(
        'Bundled libpdfium.so was not found next to the application.',
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
          '$frameworksDir${Platform.pathSeparator}libpdfium.dylib',
        '$exeDir${Platform.pathSeparator}libpdfium.dylib',
      ];
      for (final path in candidates) {
        if (File(path).existsSync()) return path;
      }
      if (_allowSystemNativeLibraries) return 'libpdfium.dylib';
      throw UnsupportedError(
        'Bundled libpdfium.dylib was not found in the application bundle.',
      );
    }

    return 'pdfium';
  }
}

class GelidePdf {
  final _GelideWorkerClient _worker;
  final int _documentId;
  final int _pageCount;
  final String? _title;
  final String? _author;
  final List<PageSize> _pageSizes;
  Directory? _tempDirectory;
  bool _closed = false;

  GelidePdf._(this._worker, _WorkerDocumentDescriptor descriptor)
      : _documentId = descriptor.documentId,
        _pageCount = descriptor.pageCount,
        _title = descriptor.title,
        _author = descriptor.author,
        _pageSizes = List<PageSize>.unmodifiable(descriptor.pageSizes);

  void _checkOpen() {
    if (_closed) throw StateError('Document is closed');
  }

  void _checkPageIndex(int index) {
    if (index < 0 || index >= _pageCount) {
      throw RangeError.index(index, _pageSizes, 'index');
    }
  }

  int get pageCount => _pageCount;

  String? get title => _title;

  String? get author => _author;

  PageSize getPageSize(int index) {
    _checkOpen();
    _checkPageIndex(index);
    return _pageSizes[index];
  }

  List<PageSize> getPageSizes() {
    _checkOpen();
    return _pageSizes;
  }

  Future<ui.Image> renderPage(int index, {double dpi = 150.0}) async {
    _checkOpen();
    _checkPageIndex(index);
    final rendered = await _worker.renderPage(_documentId, index, dpi);
    return _bytesToImage(rendered.data, rendered.width, rendered.height);
  }

  Future<ui.Image> renderPageSized(
    int index,
    int width,
    int height,
  ) async {
    _checkOpen();
    _checkPageIndex(index);
    final rendered = await _worker.renderPageSized(
      _documentId,
      index,
      width,
      height,
    );
    return _bytesToImage(rendered.data, rendered.width, rendered.height);
  }

  Future<ui.Image> renderTile({
    required int pageIndex,
    required int x,
    required int y,
    required int width,
    required int height,
    required int fullWidth,
    required int fullHeight,
  }) async {
    _checkOpen();
    _checkPageIndex(pageIndex);
    final rendered = await _worker.renderTile(
      _documentId,
      pageIndex: pageIndex,
      x: x,
      y: y,
      width: width,
      height: height,
      fullWidth: fullWidth,
      fullHeight: fullHeight,
    );
    return _bytesToImage(rendered.data, rendered.width, rendered.height);
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    final tempDirectory = _tempDirectory;
    _tempDirectory = null;
    unawaited(_closeRemote(tempDirectory));
  }

  Future<void> _closeRemote(Directory? tempDirectory) async {
    try {
      await _worker.closeDocument(_documentId);
    } catch (_) {
    } finally {
      if (tempDirectory != null) {
        try {
          await tempDirectory.delete(recursive: true);
        } catch (_) {}
      }
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
}

class PageSize {
  final double width;
  final double height;
  final int rotation;

  const PageSize(
      {required this.width, required this.height, this.rotation = 0});

  double get widthInches => width / 72.0;
  double get heightInches => height / 72.0;
  double get aspect => width / height;
}

class GelideViewer extends StatefulWidget {
  final GelidePdf pdf;
  final double dpi;
  final bool showControls;
  final Color backgroundColor;

  const GelideViewer({
    super.key,
    required this.pdf,
    this.dpi = 150.0,
    this.showControls = true,
    this.backgroundColor = Colors.grey,
  });

  @override
  State<GelideViewer> createState() => _GelideViewerState();
}

class _GelideViewerState extends State<GelideViewer> {
  late PageController _pageController;
  int _currentPage = 0;
  final Map<int, Future<ui.Image>> _cache = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  Future<ui.Image> _getPage(int index) {
    if (_cache.containsKey(index)) return _cache[index]!;

    final future = _loadAndCachePage(index);
    _cache[index] = future;
    return future;
  }

  Future<ui.Image> _loadAndCachePage(int index) async {
    final image = await widget.pdf.renderPage(index, dpi: widget.dpi);

    if (_cache.length > 5) {
      final toRemove = _cache.keys.where((k) => (k - index).abs() > 2).toList();
      for (final k in toRemove) {
        _cache.remove(k);
      }
    }

    return image;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.pdf.pageCount,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) {
              return FutureBuilder<ui.Image>(
                future: _getPage(index),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child:
                          RawImage(image: snapshot.data, fit: BoxFit.contain),
                    ),
                  );
                },
              );
            },
          ),
          if (widget.showControls)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentPage + 1} / ${widget.pdf.pageCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cache.clear();
    super.dispose();
  }
}

class GelidePage extends StatefulWidget {
  final GelidePdf pdf;
  final int index;
  final double dpi;
  final BoxFit fit;
  final Widget? placeholder;

  const GelidePage({
    super.key,
    required this.pdf,
    required this.index,
    this.dpi = 150.0,
    this.fit = BoxFit.contain,
    this.placeholder,
  });

  @override
  State<GelidePage> createState() => _GelidePageState();
}

class _GelidePageState extends State<GelidePage> {
  ui.Image? _image;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GelidePage old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index || old.dpi != widget.dpi) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final img = await widget.pdf.renderPage(widget.index, dpi: widget.dpi);
    if (mounted) {
      setState(() {
        _image = img;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.placeholder ??
          const Center(child: CircularProgressIndicator());
    }
    return RawImage(image: _image, fit: widget.fit);
  }
}

class GelideThumbnail extends StatefulWidget {
  final GelidePdf pdf;
  final int index;
  final double width;
  final VoidCallback? onTap;

  const GelideThumbnail({
    super.key,
    required this.pdf,
    required this.index,
    this.width = 100,
    this.onTap,
  });

  @override
  State<GelideThumbnail> createState() => _GelideThumbnailState();
}

class _GelideThumbnailState extends State<GelideThumbnail> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final size = widget.pdf.getPageSize(widget.index);
    final height = (widget.width / size.aspect).round();
    final img = await widget.pdf
        .renderPageSized(widget.index, widget.width.round(), height);
    if (mounted) setState(() => _image = img);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: _image == null
            ? const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
            : RawImage(image: _image, fit: BoxFit.contain),
      ),
    );
  }
}
