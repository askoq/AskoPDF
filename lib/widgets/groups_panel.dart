import 'package:flutter/material.dart';
import 'package:asko_pdf/models/page_group.dart';
import 'package:asko_pdf/l10n/app_localizations.dart';
import 'package:asko_pdf/theme/app_colors.dart';

class GroupsPanel extends StatefulWidget {
  final List<PageGroup> groups;
  final String? activeGroupId;
  final VoidCallback onCreateGroup;
  final ValueChanged<PageGroup> onEditGroup;
  final ValueChanged<String> onDeleteGroup;
  final ValueChanged<String?> onSelectGroup;
  final int totalPages;

  const GroupsPanel({
    super.key,
    required this.groups,
    this.activeGroupId,
    required this.onCreateGroup,
    required this.onEditGroup,
    required this.onDeleteGroup,
    required this.onSelectGroup,
    required this.totalPages,
  });

  @override
  State<GroupsPanel> createState() => _GroupsPanelState();
}

class _GroupsPanelState extends State<GroupsPanel> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.groups,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: widget.onCreateGroup,
                  tooltip: l10n.createGroup,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  hoverColor: Colors.grey.shade200,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 22,
                  ),
                  onPressed: () =>
                      setState(() => _isExpanded = !_isExpanded),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  hoverColor: Colors.grey.shade200,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
            crossFadeState: _isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AllPagesItem(
                  isActive: widget.activeGroupId == null,
                  totalPages: widget.totalPages,
                  onTap: () => widget.onSelectGroup(null),
                ),
                if (widget.groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.create_new_folder_outlined,
                            size: 32,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.noGroupsYet,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: widget.onCreateGroup,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryBlue,
                            ).copyWith(
                              overlayColor: MaterialStateProperty.resolveWith(
                                (states) => states.contains(
                                  MaterialState.hovered,
                                )
                                    ? Colors.grey.shade200
                                    : null,
                              ),
                            ),
                            child: Text(l10n.createFirstGroup),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...widget.groups.map(
                    (group) => _GroupItem(
                      group: group,
                      isActive: widget.activeGroupId == group.id,
                      onTap: () => widget.onSelectGroup(group.id),
                      onEdit: () => widget.onEditGroup(group),
                      onDelete: () => widget.onDeleteGroup(group.id),
                    ),
                  ),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _AllPagesItem extends StatelessWidget {
  final bool isActive;
  final int totalPages;
  final VoidCallback onTap;

  const _AllPagesItem({
    required this.isActive,
    required this.totalPages,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: AppColors.primaryBlue.withValues(alpha: isActive ? 0.1 : 0),
      child: InkWell(
        onTap: onTap,
        hoverColor: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryBlue : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.file_copy_outlined,
                  size: 16,
                  color: isActive ? Colors.white : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.allPages,
                      style: TextStyle(
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isActive ? AppColors.primaryBlue : Colors.black87,
                      ),
                    ),
                    Text(
                      '$totalPages ${l10n.pages.toLowerCase()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: AppColors.primaryBlueSoft,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupItem extends StatefulWidget {
  final PageGroup group;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GroupItem({
    required this.group,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_GroupItem> createState() => _GroupItemState();
}

class _GroupItemState extends State<_GroupItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: widget.group.navigationColor.withValues(
          alpha: widget.isActive ? 0.1 : 0,
        ),
        child: InkWell(
          onTap: widget.onTap,
          hoverColor: Colors.grey.shade100,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: widget.group.colorSettings.decoration.copyWith(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      widget.group.icon,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.group.name,
                        style: TextStyle(
                          fontWeight: widget.isActive
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: widget.isActive
                              ? widget.group.navigationColor
                              : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${widget.group.pages.length} ${l10n.pages.toLowerCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_isHovered || widget.isActive) ...[
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: widget.onEdit,
                    tooltip: l10n.editGroup,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    hoverColor: Colors.grey.shade200,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.red.shade400,
                    ),
                    onPressed: () => _confirmDelete(context),
                    tooltip: l10n.deleteGroup,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    hoverColor: Colors.red.shade50,
                  ),
                ] else if (widget.isActive) ...[
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: widget.group.navigationColor.withValues(alpha: 0.8),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          title: Text(l10n.deleteGroupTitle),
          content: Text(l10n.deleteGroupMessage),
          actions: [
            _DialogActionButton(
              label: l10n.cancel,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade100,
              hoverColor: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.grey.shade200,
              textColor: isDark ? Colors.white70 : Colors.black54,
              onTap: () => Navigator.of(ctx).pop(),
            ),
            _DialogActionButton(
              label: l10n.delete,
              backgroundColor: Colors.red.shade400,
              hoverColor: Colors.red.shade500,
              textColor: Colors.white,
              onTap: () {
                Navigator.of(ctx).pop();
                widget.onDelete();
              },
            ),
          ],
        );
      },
    );
  }
}

class _DialogActionButton extends StatefulWidget {
  final String label;
  final Color backgroundColor;
  final Color hoverColor;
  final Color textColor;
  final VoidCallback onTap;

  const _DialogActionButton({
    required this.label,
    required this.backgroundColor,
    required this.hoverColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  State<_DialogActionButton> createState() => _DialogActionButtonState();
}

class _DialogActionButtonState extends State<_DialogActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final background = _isHovered ? widget.hoverColor : widget.backgroundColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: widget.textColor,
            ),
          ),
        ),
      ),
    );
  }
}
