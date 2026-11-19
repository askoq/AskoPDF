import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:asko_pdf/gelide/gelide.dart';
import 'package:asko_pdf/services/pdf_engine.dart';

enum GelideMissingDependency { gelideCore, pdfium, unknown }

class GelideEngineUnavailableException implements Exception {
  final String details;
  final GelideMissingDependency dependency;

  const GelideEngineUnavailableException(
    this.details, {
    this.dependency = GelideMissingDependency.unknown,
  });

  @override
  String toString() => details;
}

List<PdfSearchMatch> nonOverlappingSearchMatches(
  int pageIndex,
  List<SearchMatch> matches,
) {
  final sorted = [...matches]
    ..sort((a, b) => a.startIndex.compareTo(b.startIndex));
  final results = <PdfSearchMatch>[];
  var previousEnd = -1;
  for (final match in sorted) {
    if (match.startIndex < previousEnd) continue;
    previousEnd = match.endIndex;
    results.add(
      PdfSearchMatch(
        pageIndex: pageIndex,
        text: match.text,
        rects: match.rects,
      ),
    );
  }
  return results;
}

class GelidePdfEngine implements PdfEngine {
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    try {
      await Gelide.init();
      _initialized = true;
    } catch (e, stackTrace) {
      final dependency = _detectMissingDependency(e);
      if (dependency != null) {
        Error.throwWithStackTrace(
          GelideEngineUnavailableException(
            e.toString(),
            dependency: dependency,
          ),
          stackTrace,
        );
      }
      rethrow;
    }
  }

  @override
  Future<PdfDocumentHandle> openDocument(String path) async {
    await init();
    try {
      final pdf = await Gelide.open(path);
      return GelidePdfDocument(pdf);
    } catch (e, stackTrace) {
      final dependency = _detectMissingDependency(e);
      if (dependency != null) {
        Error.throwWithStackTrace(
          GelideEngineUnavailableException(
            e.toString(),
            dependency: dependency,
          ),
          stackTrace,
        );
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    Gelide.dispose();
    _initialized = false;
  }

  GelideMissingDependency? _detectMissingDependency(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('pdfium.dll') ||
        message.contains('libpdfium.so') ||
        message.contains('libpdfium.dylib') ||
        message.contains('check pdfium.dll path') ||
        message.contains('check pdfium path')) {
      return GelideMissingDependency.pdfium;
    }

    if (message.contains('gelide_core.dll') ||
        message.contains('libgelide_core.so') ||
        message.contains('libgelide_core.dylib') ||
        message.contains('failed to load dynamic library') ||
        message.contains('failed to initialize gelide engine') ||
        message.contains('symbol not found') ||
        message.contains('procedure not found') ||
        message.contains('the specified module could not be found') ||
        message.contains('is not a valid win32 application')) {
      return GelideMissingDependency.gelideCore;
    }

    return null;
  }
}

class GelidePdfDocument implements PdfDocumentHandle {
  final GelidePdf _pdf;

  GelidePdfDocument(this._pdf);

  @override
  int get pageCount => _pdf.pageCount;

  @override
  Size getPageSize(int pageIndex) {
    final size = _pdf.getPageSize(pageIndex);
    return Size(size.width, size.height);
  }

  @override
  Future<ui.Image> renderPage(int pageIndex, {required double renderScale}) {
    final dpi = (72.0 * renderScale).clamp(72.0, 600.0).toDouble();
    return _pdf.renderPage(pageIndex, dpi: dpi);
  }

  @override
  Future<ui.Image> renderPageSized(int pageIndex, int width, int height) {
    return _pdf.renderPageSized(pageIndex, width, height);
  }

  @override
  Future<ui.Image> renderTile({
    required int pageIndex,
    required int x,
    required int y,
    required int width,
    required int height,
    required int fullWidth,
    required int fullHeight,
  }) {
    return _pdf.renderTile(
      pageIndex: pageIndex,
      x: x,
      y: y,
      width: width,
      height: height,
      fullWidth: fullWidth,
      fullHeight: fullHeight,
    );
  }

  @override
  Future<List<PdfSearchMatch>> searchText(
    int pageIndex,
    String query, {
    bool caseSensitive = false,
  }) async {
    if (query.isEmpty) return const [];

    final matches = await _pdf.search(
      pageIndex,
      query,
      caseSensitive: caseSensitive,
    );
    return nonOverlappingSearchMatches(pageIndex, matches);
  }

  @override
  bool get supportsTileRendering => true;

  @override
  String? get title => _pdf.title;

  @override
  String? get author => _pdf.author;

  @override
  void dispose() => _pdf.dispose();
}
