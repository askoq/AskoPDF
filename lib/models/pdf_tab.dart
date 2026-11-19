import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:asko_pdf/models/pdf_metadata.dart';
import 'package:asko_pdf/models/file_identifier.dart';
import 'package:asko_pdf/services/pdf_engine.dart';

class PdfTab {
  final String id;
  final String filePath;
  String documentTitle;
  String customTitle = '';

  FileIdentifier? fileIdentifier;

  double scale = 1.0;
  double globalRotationAngle = 0.0;
  List<double> pageRotations = [];
  bool rotateAllPagesMode = false;

  final ScrollController scrollController = ScrollController();
  final ScrollController horizontalScrollController = ScrollController();
  final ScrollController navigationScrollController = ScrollController();
  double navigationScrollOffset = 0.0;

  int totalPages = 0;
  int currentPage = 1;

  PdfDocumentHandle? document;
  int renderGeneration = 0;
  int searchGeneration = 0;

  bool isLoading = true;
  double loadingProgress = 0.0;
  String loadingMessage = 'Initializing...';
  bool isSearchVisible = false;
  bool isSearching = false;
  String searchQuery = '';
  List<PdfSearchMatch> searchResults = [];
  Map<int, List<PdfSearchMatch>> searchResultsByPage = {};
  int currentSearchResultIndex = -1;

  List<ui.Image?> renderedPages = [];
  List<ui.Image?> thumbnails = [];
  List<Size> pageSizes = [];
  List<double> pageOffsets = [];
  final LinkedHashSet<int> renderedPageOrder = LinkedHashSet<int>();

  List<double> pageRenderScales = [];
  bool isRerendering = false;
  final Set<int> pendingPageRenders = {};
  final Set<int> pendingThumbnailRenders = {};

  PdfMetadata? metadata;

  PdfTab({required this.id, required this.filePath, this.documentTitle = ''}) {
    navigationScrollController.addListener(() {
      navigationScrollOffset = navigationScrollController.offset;
    });
  }

  void dispose() {
    for (final image in renderedPages) {
      image?.dispose();
    }
    for (final image in thumbnails) {
      image?.dispose();
    }
    document?.dispose();
    document = null;
    renderedPages = [];
    thumbnails = [];
    pageSizes = [];
    pageOffsets = [];
    pageRotations = [];
    pageRenderScales = [];
    renderedPageOrder.clear();
    searchGeneration = 0;
    isSearchVisible = false;
    isSearching = false;
    searchQuery = '';
    searchResults = [];
    searchResultsByPage = {};
    currentSearchResultIndex = -1;
    totalPages = 0;
    currentPage = 1;
    pendingPageRenders.clear();
    pendingThumbnailRenders.clear();
    scrollController.dispose();
    horizontalScrollController.dispose();
    navigationScrollController.dispose();
  }
}
