import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'package:asko_pdf/services/pdf_engine.dart';
import 'package:asko_pdf/widgets/lazy_pdf_page_widget.dart';

class PanningArea extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;
  final ScrollController? horizontalScrollController;

  const PanningArea({
    super.key,
    required this.child,
    required this.scrollController,
    this.horizontalScrollController,
  });

  @override
  State<PanningArea> createState() => _PanningAreaState();
}

class _PanningAreaState extends State<PanningArea> {
  bool _isPanning = false;
  Offset _lastPosition = Offset.zero;

  void _handlePointerDown(PointerDownEvent event) {
    if (event.buttons == kSecondaryMouseButton ||
        event.buttons == kMiddleMouseButton) {
      setState(() {
        _isPanning = true;
        _lastPosition = event.position;
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_isPanning && widget.scrollController.hasClients) {
      final delta = event.position - _lastPosition;
      _lastPosition = event.position;
      widget.scrollController.jumpTo(
        (widget.scrollController.offset - delta.dy).clamp(
          0.0,
          widget.scrollController.position.maxScrollExtent,
        ),
      );
      final horizontalController = widget.horizontalScrollController;
      if (horizontalController != null && horizontalController.hasClients) {
        horizontalController.jumpTo(
          (horizontalController.offset - delta.dx).clamp(
            0.0,
            horizontalController.position.maxScrollExtent,
          ),
        );
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_isPanning) {
      setState(() {
        _isPanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _isPanning
          ? SystemMouseCursors.grabbing
          : SystemMouseCursors.basic,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: (_) => setState(() => _isPanning = false),
        child: widget.child,
      ),
    );
  }
}

class PdfPagesList extends StatelessWidget {
  final PdfDocumentHandle document;
  final List<ui.Image?> renderedPages;
  final List<Size> pageSizes;
  final ScrollController scrollController;
  final double pageSpacing;
  final double scale;
  final double globalRotationAngle;
  final List<double> pageRotations;
  final List<int>? visiblePageIndices;
  final double targetRenderScale;
  final double fallbackRenderScale;
  final bool enableTileRendering;
  final double tileScaleThreshold;
  final int tileSize;
  final String visibilityKeyPrefix;
  final Future<void> Function(int pageIndex, double renderScale)
  onRequestRender;

  const PdfPagesList({
    super.key,
    required this.document,
    required this.renderedPages,
    required this.pageSizes,
    required this.scrollController,
    required this.pageSpacing,
    required this.scale,
    required this.globalRotationAngle,
    required this.pageRotations,
    this.visiblePageIndices,
    required this.targetRenderScale,
    required this.fallbackRenderScale,
    required this.enableTileRendering,
    required this.tileScaleThreshold,
    required this.tileSize,
    required this.visibilityKeyPrefix,
    required this.onRequestRender,
  });

  @override
  Widget build(BuildContext context) {
    final indicesToShow =
        visiblePageIndices ?? List.generate(renderedPages.length, (i) => i);
    return ListView.separated(
      controller: scrollController,
      padding: EdgeInsets.all(pageSpacing),
      itemCount: indicesToShow.length,
      separatorBuilder: (context, index) => SizedBox(height: pageSpacing),
      itemBuilder: (context, index) {
        final pageIndex = indicesToShow[index];
        if (pageIndex < 0 || pageIndex >= renderedPages.length) {
          return const SizedBox.shrink();
        }

        return Center(
          child: LazyPdfPageWidget(
            key: ValueKey('page_widget_${visibilityKeyPrefix}_$pageIndex'),
            document: document,
            pageIndex: pageIndex,
            pageSize: pageSizes[pageIndex],
            displayScale: scale,
            targetRenderScale: targetRenderScale,
            fallbackRenderScale: fallbackRenderScale,
            rotationAngle:
                globalRotationAngle +
                (pageIndex < pageRotations.length
                    ? pageRotations[pageIndex]
                    : 0.0),
            image: renderedPages[pageIndex],
            onRequestRender: onRequestRender,
            enableTileRendering: enableTileRendering,
            tileScaleThreshold: tileScaleThreshold,
            tileSize: tileSize,
            visibilityKey: Key('page_${visibilityKeyPrefix}_$pageIndex'),
            scrollController: scrollController,
          ),
        );
      },
    );
  }
}
