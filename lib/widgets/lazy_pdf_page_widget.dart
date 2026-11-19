import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:asko_pdf/services/pdf_engine.dart';
import 'package:asko_pdf/widgets/pdf_tile_manager.dart';

class LazyPdfPageWidget extends StatefulWidget {
  final PdfDocumentHandle document;
  final int pageIndex;
  final Size pageSize;
  final double displayScale;
  final double targetRenderScale;
  final double fallbackRenderScale;
  final double rotationAngle;
  final ui.Image? image;
  final Future<void> Function(int pageIndex, double renderScale)
  onRequestRender;
  final bool enableTileRendering;
  final double tileScaleThreshold;
  final int tileSize;
  final Key visibilityKey;
  final ScrollController? scrollController;
  final List<PdfSearchMatch> searchMatches;
  final PdfSearchMatch? activeSearchMatch;

  const LazyPdfPageWidget({
    super.key,
    required this.document,
    required this.pageIndex,
    required this.pageSize,
    required this.displayScale,
    required this.targetRenderScale,
    required this.fallbackRenderScale,
    required this.rotationAngle,
    required this.image,
    required this.onRequestRender,
    required this.enableTileRendering,
    required this.tileScaleThreshold,
    required this.tileSize,
    required this.visibilityKey,
    this.scrollController,
    this.searchMatches = const [],
    this.activeSearchMatch,
  });

  @override
  State<LazyPdfPageWidget> createState() => _LazyPdfPageWidgetState();
}

class _LazyPdfPageWidgetState extends State<LazyPdfPageWidget> {
  Rect? _visibleRect;
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    final normalizedAngle = ((widget.rotationAngle % 360) + 360) % 360;
    final quarterTurns = (normalizedAngle ~/ 90) % 4;

    final displayWidth = widget.pageSize.width * widget.displayScale;
    final displayHeight = widget.pageSize.height * widget.displayScale;

    final canUseTiles =
        widget.enableTileRendering &&
        widget.document.supportsTileRendering &&
        widget.displayScale >= widget.tileScaleThreshold &&
        quarterTurns == 0;

    Widget content;
    if (canUseTiles) {
      final tileRenderScale = widget.displayScale;
      content = TilePdfPage(
        document: widget.document,
        pageIndex: widget.pageIndex,
        pageSize: widget.pageSize,
        displayScale: widget.displayScale,
        renderScale: tileRenderScale,
        tileSize: widget.tileSize,
        visibleRect: _visibleRect,
        fallbackImage: widget.image,
      );
    } else {
      content = widget.image == null
          ? const Center(child: CircularProgressIndicator())
          : RawImage(
              image: widget.image,
              width: displayWidth,
              height: displayHeight,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            );
    }

    final pageContent = Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (widget.searchMatches.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: PdfSearchHighlightsPainter(
                  matches: widget.searchMatches,
                  activeMatch: widget.activeSearchMatch,
                ),
              ),
            ),
          ),
      ],
    );

    return VisibilityDetector(
      key: widget.visibilityKey,
      onVisibilityChanged: (info) {
        final isVisible = !info.visibleBounds.isEmpty;
        if (isVisible) {
          if (canUseTiles) {
            widget.onRequestRender(
              widget.pageIndex,
              widget.fallbackRenderScale,
            );
          } else {
            widget.onRequestRender(widget.pageIndex, widget.targetRenderScale);
          }
          final rect = info.visibleBounds;
          if (mounted) {
            setState(() {
              _isVisible = true;
              _visibleRect = rect;
            });
          }
        } else if (_isVisible) {
          if (mounted) {
            setState(() {
              _isVisible = false;
              _visibleRect = null;
            });
          }
        }
      },
      child: RotatedBox(
        quarterTurns: quarterTurns,
        child: Container(
          width: displayWidth,
          height: displayHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: pageContent,
        ),
      ),
    );
  }
}

class TilePdfPage extends StatefulWidget {
  final PdfDocumentHandle document;
  final int pageIndex;
  final Size pageSize;
  final double displayScale;
  final double renderScale;
  final int tileSize;
  final Rect? visibleRect;
  final ui.Image? fallbackImage;

  const TilePdfPage({
    super.key,
    required this.document,
    required this.pageIndex,
    required this.pageSize,
    required this.displayScale,
    required this.renderScale,
    required this.tileSize,
    required this.visibleRect,
    required this.fallbackImage,
  });

  @override
  State<TilePdfPage> createState() => _TilePdfPageState();
}

class _TilePdfPageState extends State<TilePdfPage> {
  late PdfTileManager _tileManager;
  int _paintVersion = 0;

  int get _fullWidth => (widget.pageSize.width * widget.renderScale).round();
  int get _fullHeight => (widget.pageSize.height * widget.renderScale).round();

  @override
  void initState() {
    super.initState();
    _tileManager = PdfTileManager(
      document: widget.document,
      pageIndex: widget.pageIndex,
      tileSize: widget.tileSize,
    );
    _tileManager.setFullSize(_fullWidth, _fullHeight);
  }

  @override
  void didUpdateWidget(TilePdfPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.renderScale != widget.renderScale ||
        oldWidget.pageSize != widget.pageSize) {
      _tileManager.setFullSize(_fullWidth, _fullHeight);
      _paintVersion++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleRect = widget.visibleRect;
    if (visibleRect == null) {
      return const SizedBox.shrink();
    }

    final scaleFactor = widget.renderScale / widget.displayScale;
    final viewportX = visibleRect.left * scaleFactor;
    final viewportY = visibleRect.top * scaleFactor;
    final viewportWidth = visibleRect.width * scaleFactor;
    final viewportHeight = visibleRect.height * scaleFactor;

    final tiles = _tileManager.getVisibleTiles(
      viewportX,
      viewportY,
      viewportWidth,
      viewportHeight,
    );

    int requested = 0;
    for (final tile in tiles) {
      if (tile.image == null && !tile.isLoading) {
        if (requested >= 8) break;
        requested++;
        _tileManager.getTile(tile.tileX, tile.tileY).then((_) {
          if (mounted) {
            setState(() {
              _paintVersion++;
            });
          }
        });
      }
    }
    _tileManager.prefetchTiles(
      viewportX,
      viewportY,
      viewportWidth,
      viewportHeight,
      paddingTiles: 1,
      maxRequests: 6,
    );

    final size = Size(
      widget.pageSize.width * widget.displayScale,
      widget.pageSize.height * widget.displayScale,
    );

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.fallbackImage != null)
            RawImage(
              image: widget.fallbackImage,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          CustomPaint(
            painter: TilePainter(
              tiles: tiles,
              renderScale: widget.renderScale,
              displayScale: widget.displayScale,
              paintVersion: _paintVersion,
              drawPlaceholders: widget.fallbackImage == null,
            ),
            size: size,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tileManager.clearCache();
    super.dispose();
  }
}

class TilePainter extends CustomPainter {
  final List<TileInfo> tiles;
  final double renderScale;
  final double displayScale;
  final int paintVersion;
  final bool drawPlaceholders;

  TilePainter({
    required this.tiles,
    required this.renderScale,
    required this.displayScale,
    required this.paintVersion,
    required this.drawPlaceholders,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final placeholder = Paint()..color = Colors.grey.shade200;
    final border = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final scaleFactor = displayScale / renderScale;

    for (final tile in tiles) {
      final displayX = tile.pixelX * scaleFactor;
      final displayY = tile.pixelY * scaleFactor;
      final displayW = tile.width * scaleFactor;
      final displayH = tile.height * scaleFactor;

      final rect = Rect.fromLTWH(displayX, displayY, displayW, displayH);

      if (tile.image != null) {
        final src = Rect.fromLTWH(
          0,
          0,
          tile.image!.width.toDouble(),
          tile.image!.height.toDouble(),
        );
        canvas.drawImageRect(tile.image!, src, rect, Paint());
      } else if (drawPlaceholders) {
        canvas.drawRect(rect, placeholder);
        canvas.drawRect(rect, border);
      }
    }
  }

  @override
  bool shouldRepaint(TilePainter oldDelegate) =>
      paintVersion != oldDelegate.paintVersion ||
      renderScale != oldDelegate.renderScale ||
      displayScale != oldDelegate.displayScale ||
      tiles.length != oldDelegate.tiles.length ||
      drawPlaceholders != oldDelegate.drawPlaceholders;
}

class PdfSearchHighlightsPainter extends CustomPainter {
  final List<PdfSearchMatch> matches;
  final PdfSearchMatch? activeMatch;

  PdfSearchHighlightsPainter({
    required this.matches,
    required this.activeMatch,
  });

  static const Color _matchColor = Color(0xFFFFD54F);
  static const Color _activeColor = Color(0xFFFF9800);

  @override
  void paint(Canvas canvas, Size size) {
    if (matches.isEmpty || size.isEmpty) return;

    final inactiveRects = <Rect>[];
    final activeRects = <Rect>[];
    for (final match in matches) {
      final target =
          identical(match, activeMatch) ? activeRects : inactiveRects;
      for (final rect in match.rects) {
        final screenRect = _toScreen(rect, size);
        if (!screenRect.isEmpty) target.add(screenRect);
      }
    }

    _fillLayer(canvas, size, inactiveRects, _matchColor, 0.28);
    _fillLayer(canvas, size, activeRects, _activeColor, 0.34);

    if (activeRects.isNotEmpty) {
      final stroke = Paint()
        ..color = _activeColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      for (final rect in activeRects) {
        canvas.drawRect(rect, stroke);
      }
    }
  }

  void _fillLayer(
    Canvas canvas,
    Size size,
    List<Rect> rects,
    Color color,
    double opacity,
  ) {
    if (rects.isEmpty) return;
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
    );
    final fill = Paint()..color = color;
    for (final rect in rects) {
      canvas.drawRect(rect, fill);
    }
    canvas.restore();
  }

  Rect _toScreen(Rect rect, Size size) {
    final left = math.min(rect.left, rect.right).clamp(0.0, 1.0);
    final right = math.max(rect.left, rect.right).clamp(0.0, 1.0);
    final top = math.min(rect.top, rect.bottom).clamp(0.0, 1.0);
    final bottom = math.max(rect.top, rect.bottom).clamp(0.0, 1.0);
    return Rect.fromLTRB(
      left * size.width,
      top * size.height,
      right * size.width,
      bottom * size.height,
    );
  }

  @override
  bool shouldRepaint(PdfSearchHighlightsPainter oldDelegate) {
    return oldDelegate.matches != matches ||
        oldDelegate.activeMatch != activeMatch;
  }
}
