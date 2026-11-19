import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class PdfSearchMatch {
  final int pageIndex;
  final String text;
  final List<Rect> rects;

  const PdfSearchMatch({
    required this.pageIndex,
    required this.text,
    required this.rects,
  });
}

abstract class PdfEngine {
  Future<void> init();
  Future<PdfDocumentHandle> openDocument(String path);
  void dispose();
}

abstract class PdfDocumentHandle {
  int get pageCount;
  Size getPageSize(int pageIndex);
  Future<ui.Image> renderPage(int pageIndex, {required double renderScale});
  Future<ui.Image> renderPageSized(int pageIndex, int width, int height);
  Future<ui.Image> renderTile({
    required int pageIndex,
    required int x,
    required int y,
    required int width,
    required int height,
    required int fullWidth,
    required int fullHeight,
  });
  Future<List<PdfSearchMatch>> searchText(
    int pageIndex,
    String query, {
    bool caseSensitive = false,
  });
  bool get supportsTileRendering;
  String? get title;
  String? get author;
  void dispose();
}
