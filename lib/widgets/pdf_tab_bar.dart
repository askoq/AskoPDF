import 'package:flutter/material.dart';
import 'package:asko_pdf/models/pdf_tab.dart';
import 'package:asko_pdf/l10n/app_localizations.dart';
import 'dart:io';
import 'package:asko_pdf/theme/app_colors.dart';

class PdfTabBar extends StatefulWidget {
  final List<PdfTab> tabs;
  final int selectedIndex;
  final Function(int) onTabSelected;
  final Function(int) onTabClosed;
  final Function(int, int) onReorder;
  final VoidCallback onNewTab;
  final bool isExpanded;
  final bool searchBarVisible;
  final VoidCallback onToggleExpand;
  final Function(int, String)? onRenameTab;
  final Function(int)? onShowInfo;
  final bool isProjectMode;
  final String? projectName;
  final VoidCallback? onCloseProject;

  const PdfTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onTabClosed,
    required this.onReorder,
    required this.onNewTab,
    required this.isExpanded,
    required this.searchBarVisible,
    required this.onToggleExpand,
    this.onRenameTab,
    this.onShowInfo,
    this.isProjectMode = false,
    this.projectName,
    this.onCloseProject,
  });

  @override
  State<PdfTabBar> createState() => _PdfTabBarState();
}

class _PdfTabBarState extends State<PdfTabBar> {
  int? _editingIndex;
  late TextEditingController _editController;
  bool _isExpandHovered = false;
  bool _isOpenHovered = false;
  bool _isCloseProjectHovered = false;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _startEditing(int index, String currentName) {
    setState(() {
      _editingIndex = index;
      _editController.text = currentName;
    });
  }

  void _finishEditing(int index) {
    if (_editController.text.trim().isNotEmpty) {
      widget.onRenameTab?.call(index, _editController.text.trim());
    }
    setState(() {
      _editingIndex = null;
    });
  }

  String _getDisplayName(PdfTab tab) {
    if (tab.customTitle.isNotEmpty) {
      return tab.customTitle;
    }
    if (tab.documentTitle.isNotEmpty) {
      return tab.documentTitle;
    }
    return tab.filePath.split(Platform.pathSeparator).last;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.of(context).size.height;
    final panelTop = (screenHeight - 420) / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          right: widget.isExpanded ? 16 : -320,
          top: panelTop > 60 ? panelTop : 60,
          child: _buildPanel(context, l10n),
        ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          right: widget.searchBarVisible ? -84 : 16,
          bottom: 16,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isExpandHovered = true),
            onExit: (_) => setState(() => _isExpandHovered = false),
            child: GestureDetector(
              onTap: widget.onToggleExpand,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: widget.isExpanded
                      ? AppColors.primaryBlue
                      : (_isExpandHovered ? Colors.grey.shade100 : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: _isExpandHovered ? 10 : 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  widget.isExpanded
                      ? Icons.keyboard_arrow_right
                      : Icons.keyboard_arrow_left,
                  color:
                      widget.isExpanded ? Colors.white : Colors.grey.shade700,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanel(BuildContext context, AppLocalizations l10n) {
    return Container(
      width: 300,
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 32,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: widget.isProjectMode
                    ? AppColors.primaryBlue.withValues(alpha: 0.08)
                    : Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      widget.isProjectMode
                          ? Icons.folder
                          : Icons.layers_outlined,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.isProjectMode
                              ? (widget.projectName ?? '')
                              : l10n.openFiles,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.isProjectMode)
                          Text(
                            '${widget.tabs.length} ${l10n.filesCount}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.isProjectMode && widget.onCloseProject != null)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _isCloseProjectHovered = true),
                      onExit: (_) => setState(() => _isCloseProjectHovered = false),
                      child: GestureDetector(
                        onTap: widget.onCloseProject,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _isCloseProjectHovered
                                ? Colors.red.shade100
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isCloseProjectHovered
                                  ? Colors.red.shade300
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.logout,
                                size: 14,
                                color: Colors.red.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l10n.close,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.tabs.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Flexible(
              child: widget.tabs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            size: 36,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.noFilesOpen,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      itemCount: widget.tabs.length,
                      itemBuilder: (context, index) {
                        return _buildTabItem(context, index, l10n);
                      },
                    ),
            ),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isOpenHovered = true),
                onExit: (_) => setState(() => _isOpenHovered = false),
                child: GestureDetector(
                  onTap: widget.onNewTab,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isOpenHovered
                          ? AppColors.primaryBlue.withValues(alpha: 0.9)
                          : AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _isOpenHovered
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          l10n.openFile,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, int index, AppLocalizations l10n) {
    final tab = widget.tabs[index];
    final isSelected = index == widget.selectedIndex;
    final isEditing = _editingIndex == index;
    final displayName = _getDisplayName(tab);

    return Draggable<int>(
      data: index,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.primaryBlue.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildTabItemContent(
          context,
          tab,
          isSelected,
          isEditing,
          displayName,
          index,
          l10n,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            widget.onTabSelected(index);
            widget.onToggleExpand();
          },
          onDoubleTap: widget.onRenameTab != null
              ? () => _startEditing(index, displayName)
              : null,
          hoverColor: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          child: _buildTabItemContent(
            context,
            tab,
            isSelected,
            isEditing,
            displayName,
            index,
            l10n,
          ),
        ),
      ),
    );
  }

  Widget _buildTabItemContent(
    BuildContext context,
    PdfTab tab,
    bool isSelected,
    bool isEditing,
    String displayName,
    int index,
    AppLocalizations l10n,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryBlue.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryBlue.withValues(alpha: 0.12)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.description_outlined,
              size: 16,
              color: isSelected
                  ? AppColors.primaryBlue
                  : Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEditing)
                  TextField(
                    controller: _editController,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _finishEditing(index),
                    onTapOutside: (_) => _finishEditing(index),
                  )
                else
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primaryBlue
                          : Colors.grey.shade800,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.page} ${tab.currentPage}/${tab.totalPages}'
                  '${tab.metadata?.fileSize != null ? ' • ${_formatFileSize(tab.metadata!.fileSize)}' : ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onShowInfo != null)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => widget.onShowInfo?.call(index),
                      borderRadius: BorderRadius.circular(6),
                      hoverColor: Colors.grey.shade200,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 2),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onTabClosed(index),
                    borderRadius: BorderRadius.circular(6),
                    hoverColor: Colors.red.shade50,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
