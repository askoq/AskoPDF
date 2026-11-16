import 'dart:collection';
import 'dart:ui' as ui;

import 'package:asko_pdf/services/pdf_engine.dart';

class PdfTileManager {
  final PdfDocumentHandle document;
  final int pageIndex;
  final int tileSize;
  final int maxTiles;

  final LinkedHashMap<String, ui.Image> _tileCache = LinkedHashMap();
  final Set<String> _pendingTiles = {};

  int _fullWidth = 0;
  int _fullHeight = 0;

  PdfTileManager({
    required this.document,
    required this.pageIndex,
    this.tileSize = 512,
    this.maxTiles = 200,
  });

  void setFullSize(int width, int height) {
    if (_fullWidth != width || _fullHeight != height) {
      _fullWidth = width;
      _fullHeight = height;
      clearCache();
    }
  }

  Future<ui.Image?> getTile(int tileX, int tileY) async {
    final key = '$tileX,$tileY';

    final cached = _tileCache[key];
    if (cached != null) {
      _tileCache.remove(key);
      _tileCache[key] = cached;
      return cached;
    }
    if (_pendingTiles.contains(key)) return null;

    _pendingTiles.add(key);
    try {
      final pixelX = tileX * tileSize;
      final pixelY = tileY * tileSize;
      final w =
          (pixelX + tileSize > _fullWidth) ? _fullWidth - pixelX : tileSize;
      final h =
          (pixelY + tileSize > _fullHeight) ? _fullHeight - pixelY : tileSize;

      if (w <= 0 || h <= 0) return null;

      final image = await document.renderTile(
        pageIndex: pageIndex,
        x: pixelX,
        y: pixelY,
        width: w,
        height: h,
        fullWidth: _fullWidth,
        fullHeight: _fullHeight,
      );

      _tileCache[key] = image;
      if (_tileCache.length > maxTiles) {
        final oldestKey = _tileCache.keys.first;
        final oldest = _tileCache.remove(oldestKey);
        oldest?.dispose();
      }
      return image;
    } finally {
      _pendingTiles.remove(key);
    }
  }

  List<TileInfo> getVisibleTiles(
    double viewportX,
    double viewportY,
    double viewportWidth,
    double viewportHeight,
  ) {
    final tiles = <TileInfo>[];

    final startTileX = (viewportX / tileSize).floor();
    final startTileY = (viewportY / tileSize).floor();
    final endTileX = ((viewportX + viewportWidth) / tileSize).ceil();
    final endTileY = ((viewportY + viewportHeight) / tileSize).ceil();

    for (int ty = startTileY; ty < endTileY; ty++) {
      for (int tx = startTileX; tx < endTileX; tx++) {
        if (tx >= 0 && ty >= 0) {
          final key = '$tx,$ty';
          final pixelX = tx * tileSize;
          final pixelY = ty * tileSize;
          final width =
              (pixelX + tileSize > _fullWidth) ? _fullWidth - pixelX : tileSize;
          final height =
              (pixelY + tileSize > _fullHeight) ? _fullHeight - pixelY : tileSize;

          tiles.add(TileInfo(
            tileX: tx,
            tileY: ty,
            pixelX: pixelX,
            pixelY: pixelY,
            width: width,
            height: height,
            image: _tileCache[key],
            isLoading: _pendingTiles.contains(key),
          ));
        }
      }
    }

    return tiles;
  }

  void prefetchTiles(
    double viewportX,
    double viewportY,
    double viewportWidth,
    double viewportHeight, {
    int paddingTiles = 1,
    int maxRequests = 6,
  }) {
    if (_fullWidth <= 0 || _fullHeight <= 0) return;
    final startTileX = (viewportX / tileSize).floor() - paddingTiles;
    final startTileY = (viewportY / tileSize).floor() - paddingTiles;
    final endTileX =
        ((viewportX + viewportWidth) / tileSize).ceil() + paddingTiles;
    final endTileY =
        ((viewportY + viewportHeight) / tileSize).ceil() + paddingTiles;

    int requested = 0;
    for (int ty = startTileY; ty < endTileY; ty++) {
      for (int tx = startTileX; tx < endTileX; tx++) {
        if (tx < 0 || ty < 0) continue;
        if (requested >= maxRequests) return;
        final key = '$tx,$ty';
        if (_tileCache.containsKey(key) || _pendingTiles.contains(key)) {
          continue;
        }
        requested++;
        getTile(tx, ty);
      }
    }
  }

  void clearCache() {
    for (final image in _tileCache.values) {
      image.dispose();
    }
    _tileCache.clear();
    _pendingTiles.clear();
  }
}

class TileInfo {
  final int tileX;
  final int tileY;
  final int pixelX;
  final int pixelY;
  final int width;
  final int height;
  final ui.Image? image;
  final bool isLoading;

  TileInfo({
    required this.tileX,
    required this.tileY,
    required this.pixelX,
    required this.pixelY,
    required this.width,
    required this.height,
    this.image,
    this.isLoading = false,
  });
}
