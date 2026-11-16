import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

class LazyThumbnailWidget extends StatefulWidget {
  final ui.Image? image;
  final int pageIndex;
  final int targetWidth;
  final int targetHeight;
  final Future<void> Function(int pageIndex, int width, int height)
      onRequestThumbnail;
  final Key visibilityKey;

  const LazyThumbnailWidget({
    super.key,
    required this.image,
    required this.pageIndex,
    required this.targetWidth,
    required this.targetHeight,
    required this.onRequestThumbnail,
    required this.visibilityKey,
  });

  @override
  State<LazyThumbnailWidget> createState() => _LazyThumbnailWidgetState();
}

class _LazyThumbnailWidgetState extends State<LazyThumbnailWidget> {
  bool _requested = false;
  bool _isVisible = false;

  @override
  void didUpdateWidget(LazyThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != null && widget.image == null) {
      _requested = false;
    }
    if (oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.targetWidth != widget.targetWidth ||
        oldWidget.targetHeight != widget.targetHeight) {
      _requested = false;
    }
    if (!_requested && widget.image == null && _isVisible) {
      _requested = true;
      widget.onRequestThumbnail(
        widget.pageIndex,
        widget.targetWidth,
        widget.targetHeight,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: widget.visibilityKey,
      onVisibilityChanged: (info) {
        _isVisible = info.visibleFraction > 0.01;
        if (!_requested && _isVisible) {
          _requested = true;
          widget.onRequestThumbnail(
            widget.pageIndex,
            widget.targetWidth,
            widget.targetHeight,
          );
        }
      },
      child: widget.image == null
          ? Center(
              child: Icon(
                Icons.insert_drive_file_outlined,
                size: 20,
                color: Colors.grey.shade400,
              ),
            )
          : RawImage(
              image: widget.image,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
    );
  }
}
