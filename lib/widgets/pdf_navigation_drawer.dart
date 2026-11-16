import 'dart:ui' as ui;
import 'package:asko_pdf/theme/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:asko_pdf/models/page_group.dart';
import 'package:asko_pdf/widgets/groups_panel.dart';
import 'package:asko_pdf/widgets/lazy_thumbnail_widget.dart';
import 'package:asko_pdf/l10n/app_localizations.dart';

class PdfNavigationDrawer extends StatefulWidget {
  final int totalPages;
  final int currentPage;
  final List<ui.Image?> thumbnails;
  final List<Size> pageSizes;
  final Function(int) onPageSelected;
  final Future<void> Function(int pageIndex, int width, int height)
      onRequestThumbnail;
  final String visibilityKeyPrefix;

  final List<PageGroup> groups;
  final String? activeGroupId;
  final VoidCallback onCreateGroup;
  final ValueChanged<PageGroup> onEditGroup;
  final ValueChanged<String> onDeleteGroup;
  final ValueChanged<String?> onSelectGroup;
  final ScrollController? pageListController;
  final double? initialScrollOffset;

  const PdfNavigationDrawer({
    super.key,
    required this.totalPages,
    required this.currentPage,
    required this.thumbnails,
    required this.pageSizes,
    required this.onPageSelected,
    required this.onRequestThumbnail,
    required this.visibilityKeyPrefix,
    this.groups = const [],
    this.activeGroupId,
    required this.onCreateGroup,
    required this.onEditGroup,
    required this.onDeleteGroup,
    required this.onSelectGroup,
    this.pageListController,
    this.initialScrollOffset,
  });

  @override
  State<PdfNavigationDrawer> createState() => _PdfNavigationDrawerState();
}

class _PdfNavigationDrawerState extends State<PdfNavigationDrawer> {
  bool _didRestoreScroll = false;

  @override
  void initState() {
    super.initState();
    _scheduleScrollRestore();
  }

  @override
  void didUpdateWidget(covariant PdfNavigationDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageListController != widget.pageListController ||
        oldWidget.initialScrollOffset != widget.initialScrollOffset) {
      _didRestoreScroll = false;
      _scheduleScrollRestore();
    }
  }

  void _scheduleScrollRestore([int retries = 3]) {
    if (_didRestoreScroll) return;
    final controller = widget.pageListController;
    if (controller == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didRestoreScroll) return;
      if (controller.hasClients) {
        final max = controller.position.maxScrollExtent;
        final target =
            (widget.initialScrollOffset ?? 0.0).clamp(0.0, max);
        controller.jumpTo(target);
        _didRestoreScroll = true;
      } else if (retries > 0) {
        _scheduleScrollRestore(retries - 1);
      }
    });
  }

  List<int> get _visiblePages {
    if (widget.activeGroupId == null) {
      return List.generate(widget.totalPages, (i) => i + 1);
    }

    final activeGroup = widget.groups.cast<PageGroup?>().firstWhere(
      (g) => g?.id == widget.activeGroupId,
      orElse: () => null,
    );

    if (activeGroup != null) {
      return activeGroup.pageNumbers;
    }

    return List.generate(widget.totalPages, (i) => i + 1);
  }

  String? _getCustomPageName(int pageNumber) {
    if (widget.activeGroupId == null) return null;

    final activeGroup = widget.groups.cast<PageGroup?>().firstWhere(
      (g) => g?.id == widget.activeGroupId,
      orElse: () => null,
    );

    if (activeGroup != null) {
      final page = activeGroup.pages.cast<GroupedPage?>().firstWhere(
        (p) => p?.pageNumber == pageNumber,
        orElse: () => null,
      );
      if (page != null && page.customName.isNotEmpty) {
        return page.customName;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pageController = TextEditingController();
    final visiblePages = _visiblePages;

    final activeGroup = widget.activeGroupId != null
        ? widget.groups.cast<PageGroup?>().firstWhere(
            (g) => g?.id == widget.activeGroupId,
            orElse: () => null,
          )
        : null;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              activeGroup?.navigationColor ?? AppColors.primaryBlue,
              (activeGroup?.navigationColor ?? AppColors.primaryBlue)
                  .withValues(alpha: 0.95),
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                left: 20,
                right: 20,
                bottom: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: activeGroup != null
                            ? Text(
                                activeGroup.icon,
                                style: const TextStyle(fontSize: 22),
                              )
                            : const Icon(
                                Icons.layers_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeGroup?.name ?? l10n.pages,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            if (activeGroup != null)
                              GestureDetector(
                                onTap: () => widget.onSelectGroup(null),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    l10n.showAll,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Text(
                                l10n.documentNavigation,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          activeGroup != null
                              ? '${visiblePages.length}/${widget.totalPages}'
                              : '${widget.totalPages}',
                          style: TextStyle(
                            color:
                                activeGroup?.navigationColor ??
                                AppColors.primaryBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    GroupsPanel(
                      groups: widget.groups,
                      activeGroupId: widget.activeGroupId,
                      onCreateGroup: widget.onCreateGroup,
                      onEditGroup: widget.onEditGroup,
                      onDeleteGroup: widget.onDeleteGroup,
                      onSelectGroup: widget.onSelectGroup,
                      totalPages: widget.totalPages,
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 10.0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: TextField(
                                controller: pageController,
                                decoration: InputDecoration(
                                  hintText: l10n.goToPage,
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    size: 18,
                                    color: Colors.grey.shade400,
                                  ),
                                  prefixIconConstraints: const BoxConstraints(
                                    minWidth: 40,
                                  ),
                                ),
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onSubmitted: (value) {
                                  final pageNum = int.tryParse(value);
                                  if (pageNum != null) {
                                    widget.onPageSelected(pageNum);
                                    pageController.clear();
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _GoToPageButton(
                            color: activeGroup?.navigationColor ??
                                AppColors.primaryBlue,
                            onTap: () {
                              final pageNum =
                                  int.tryParse(pageController.text);
                              if (pageNum != null) {
                                widget.onPageSelected(pageNum);
                                pageController.clear();
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView.builder(
                        controller: widget.pageListController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: visiblePages.length,
                        itemBuilder: (context, index) {
                          final pageNumber = visiblePages[index];
                          final isCurrentPage =
                              pageNumber == widget.currentPage;
                          final customName = _getCustomPageName(pageNumber);

                          final safeIndex = pageNumber - 1;
                          if (safeIndex < 0 ||
                              safeIndex >= widget.thumbnails.length) {
                            return const SizedBox.shrink();
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    widget.onPageSelected(pageNumber),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isCurrentPage
                                        ? (activeGroup?.navigationColor ??
                                                  Theme.of(
                                                    context,
                                                  ).primaryColor)
                                              .withValues(alpha: 0.1)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isCurrentPage
                                          ? (activeGroup?.navigationColor ??
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor)
                                                .withValues(alpha: 0.4)
                                          : Colors.grey.shade200,
                                      width: isCurrentPage ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            width: 52,
                                            height: 72,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              color: Colors.white,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: isCurrentPage
                                                      ? (activeGroup?.navigationColor ??
                                                                Theme.of(
                                                                  context,
                                                                ).primaryColor)
                                                            .withValues(
                                                              alpha: 0.25,
                                                            )
                                                      : Colors.black.withValues(
                                                          alpha: 0.08,
                                                        ),
                                                  blurRadius: isCurrentPage
                                                      ? 8
                                                      : 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child:
                                                widget.thumbnails[safeIndex] !=
                                                        null
                                                ? RawImage(
                                                    image: widget
                                                        .thumbnails[safeIndex],
                                                    fit: BoxFit.cover,
                                                    filterQuality:
                                                        FilterQuality.medium,
                                                  )
                                                : LazyThumbnailWidget(
                                                    image: widget
                                                        .thumbnails[safeIndex],
                                                    pageIndex: safeIndex,
                                                    targetWidth: 52,
                                                    targetHeight: 72,
                                                    onRequestThumbnail:
                                                        widget
                                                            .onRequestThumbnail,
                                                    visibilityKey: Key(
                                                      'thumb_${widget.visibilityKeyPrefix}_$safeIndex',
                                                    ),
                                                  ),
                                          ),
                                          Positioned(
                                            bottom: 4,
                                            right: 4,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isCurrentPage
                                                    ? (activeGroup
                                                              ?.navigationColor ??
                                                          Theme.of(
                                                            context,
                                                          ).primaryColor)
                                                    : Colors.black.withValues(
                                                        alpha: 0.6,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '$pageNumber',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(width: 14),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              customName ??
                                                  '${l10n.page} $pageNumber',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isCurrentPage
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: isCurrentPage
                                                    ? (activeGroup
                                                              ?.navigationColor ??
                                                          Theme.of(
                                                            context,
                                                          ).primaryColor)
                                                    : Colors.grey.shade800,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${(widget.pageSizes[safeIndex].width).toInt()} × ${(widget.pageSizes[safeIndex].height).toInt()}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Icon(
                                        isCurrentPage
                                            ? Icons.remove_red_eye_rounded
                                            : Icons.chevron_right_rounded,
                                        color: isCurrentPage
                                            ? (activeGroup?.navigationColor ??
                                                  Theme.of(
                                                    context,
                                                  ).primaryColor)
                                            : Colors.grey.shade400,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoToPageButton extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;

  const _GoToPageButton({
    required this.color,
    required this.onTap,
  });

  @override
  State<_GoToPageButton> createState() => _GoToPageButtonState();
}

class _GoToPageButtonState extends State<_GoToPageButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _isHovered ? 0.9 : 1.0),
            borderRadius: BorderRadius.circular(10),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: const Icon(
            Icons.arrow_forward,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}
