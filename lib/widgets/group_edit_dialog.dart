import 'package:flutter/material.dart';
import 'package:asko_pdf/models/page_group.dart';
import 'package:asko_pdf/l10n/app_localizations.dart';
import 'package:asko_pdf/theme/app_colors.dart';

const List<Color> presetColors = [
  AppColors.primaryBlue,
  Colors.blue,
  Colors.indigo,
  Colors.purple,
  Colors.teal,
  Colors.green,
  Colors.amber,
  Colors.lime,
  Colors.orange,
  Colors.deepOrange,
  Colors.red,
  Colors.pink,
  AppColors.primaryBlueSoft,
  AppColors.primaryBlueHover,
  Colors.brown,
  Colors.blueGrey,
  Colors.grey,
];

const List<String> _baseEmojis = [
  '\u{1F4C2}',
  '\u{1F5C2}',
  '\u{1F9FE}',
  '\u{1F4CC}',
  '\u{2709}',
  '\u{1F9F7}',
  '\u{1F5C3}',
  '\u{1F4D6}',
  '\u{1F4C1}',
  '\u{1F4C4}',
  '\u{1F4D1}',
  '\u{1F4CE}',
  '\u{1F5D2}',
  '\u{1F4E6}',
  '\u{1F4E4}',
  '\u{1F4E5}',
  '\u{1F4E7}',
  '\u{1F4F7}',
  '\u{1F4DA}',
  '\u{1F4E3}',
  '📁',
  '📂',
  '📚',
  '📖',
  '📄',
  '📑',
  '📋',
  '📝',
  '🏠',
  '💼',
  '🎓',
  '🔬',
  '🎨',
  '🎵',
  '📷',
  '🎮',
  '💡',
  '🔥',
  '🚀',
  '💎',
  '🔒',
  '🔓',
  '📌',
  '🏷️',
  '🌟',
  '💫',
  '🌈',
  '🎯',
  '🎁',
  '🎀',
  '🧩',
  '🔧',
  '📱',
  '💻',
  '🖥️',
  '⌨️',
  '🖨️',
  '📞',
  '📧',
  '🗂️',
  '📊',
  '📈',
  '📉',
  '🗓️',
  '⏰',
  '🔔',
  '💬',
  '💭',
  '🏆',
  '🥇',
  '🎖️',
  '🎪',
  '🎭',
  '🎬',
  '🎤',
  '🎧',
  '🌍',
  '🌎',
  '🌏',
  '🗺️',
  '🧭',
  '🏔️',
  '🌊',
  '🌴',
  '🍎',
  '🍊',
  '🍋',
  '🍇',
  '🍓',
  '🍒',
  '🥑',
  '🥕',
  '🐶',
  '🐱',
  '🐼',
  '🦊',
  '🦁',
  '🐯',
  '🐻',
  '🦋',
];

const List<String> _extraEmojis = [
  '\u{1F4C1}',
  '\u{1F4C2}',
  '\u{1F5C2}',
  '\u{1F5C3}',
  '\u{1F5C4}',
  '\u{1F4C4}',
  '\u{1F4C3}',
  '\u{1F4DD}',
  '\u{1F4CC}',
  '\u{1F4CD}',
  '\u{1F4CE}',
  '\u{1F587}',
  '\u{1F4CF}',
  '\u{1F4D0}',
  '\u{1F4CB}',
  '\u{1F4C5}',
  '\u{1F4C6}',
  '\u{1F5D3}',
  '\u{1F4C8}',
  '\u{1F4C9}',
  '\u{1F4CA}',
  '\u{1F9FE}',
  '\u{1F4D6}',
  '\u{1F4DA}',
];

final List<String> presetEmojis = _buildPresetEmojis();

List<String> _buildPresetEmojis() {
  final unique = <String>[];
  final seen = <String>{};

  void addEmoji(String emoji) {
    final key = emoji.toLowerCase().replaceAll('\uFE0F', '');
    if (seen.add(key)) {
      unique.add(emoji);
    }
  }

  for (final emoji in _baseEmojis) {
    addEmoji(emoji);
  }
  for (final emoji in _extraEmojis) {
    addEmoji(emoji);
  }

  if (unique.length <= 100) {
    return unique;
  }
  return unique.take(100).toList();
}

class GroupEditDialog extends StatefulWidget {
  final PageGroup? existingGroup;
  final int totalPages;

  const GroupEditDialog({
    super.key,
    this.existingGroup,
    required this.totalPages,
  });

  @override
  State<GroupEditDialog> createState() => _GroupEditDialogState();
}

class _GroupEditDialogState extends State<GroupEditDialog> {
  int _currentTabIndex = 0;
  int? _hoveredTabIndex;
  late TextEditingController _nameController;
  late String _selectedIcon;
  late GroupColorType _colorType;
  late Color _primaryColor;
  late Color _secondaryColor;
  late Color _navigationColor;
  late List<GroupedPage> _pages;

  final TextEditingController _pageInputController = TextEditingController();
  String? _pageInputError;

  @override
  void initState() {
    super.initState();
    final group = widget.existingGroup;
    _nameController = TextEditingController(text: group?.name ?? '');
    _selectedIcon = group?.icon ?? '📁';
    _colorType = group?.colorSettings.type ?? GroupColorType.solid;
    _primaryColor = group?.colorSettings.primaryColor ?? AppColors.primaryBlue;
    _secondaryColor =
        group?.colorSettings.secondaryColor ?? AppColors.primaryBlueSoft;
    _navigationColor = group?.navigationColor ?? AppColors.primaryBlue;
    _pages =
        group?.pages
            .map(
              (p) => GroupedPage(
                pageNumber: p.pageNumber,
                customName: p.customName,
                orderIndex: p.orderIndex,
              ),
            )
            .toList() ??
        [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageInputController.dispose();
    super.dispose();
  }

  void _addPages(String input) {
    setState(() {
      _pageInputError = null;
    });

    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    try {
      final parts = trimmed.split(',');
      for (final part in parts) {
        final rangePart = part.trim();
        if (rangePart.contains('-')) {
          final range = rangePart.split('-');
          if (range.length == 2) {
            final start = int.parse(range[0].trim());
            final end = int.parse(range[1].trim());
            if (start < 1 || end > widget.totalPages || start > end) {
              throw FormatException('Invalid range: $rangePart');
            }
            for (int i = start; i <= end; i++) {
              _addSinglePage(i);
            }
          }
        } else {
          final pageNum = int.parse(rangePart);
          if (pageNum < 1 || pageNum > widget.totalPages) {
            throw FormatException('Page $pageNum out of range');
          }
          _addSinglePage(pageNum);
        }
      }
      _pageInputController.clear();
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _pageInputError = l10n.invalidFormat;
      });
    }
  }

  void _addSinglePage(int pageNumber) {
    if (!_pages.any((p) => p.pageNumber == pageNumber)) {
      setState(() {
        _pages.add(
          GroupedPage(pageNumber: pageNumber, orderIndex: _pages.length),
        );
      });
    }
  }

  void _removePage(int pageNumber) {
    setState(() {
      _pages.removeWhere((p) => p.pageNumber == pageNumber);
      for (int i = 0; i < _pages.length; i++) {
        _pages[i].orderIndex = i;
      }
    });
  }

  void _renamePage(int pageNumber, String newName) {
    final page = _pages.firstWhere((p) => p.pageNumber == pageNumber);
    setState(() {
      page.customName = newName;
    });
  }

  void _reorderPages(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final page = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, page);
      for (int i = 0; i < _pages.length; i++) {
        _pages[i].orderIndex = i;
      }
    });
  }

  PageGroup _buildGroup() {
    final group =
        widget.existingGroup ??
        PageGroup(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          name: _nameController.text,
        );

    group.name = _nameController.text.isNotEmpty
        ? _nameController.text
        : 'Unnamed Group';
    group.icon = _selectedIcon;
    group.colorSettings = GroupColorSettings(
      type: _colorType,
      primaryColor: _primaryColor,
      secondaryColor: _colorType == GroupColorType.gradient
          ? _secondaryColor
          : null,
    );
    group.navigationColor = _navigationColor;
    group.pages = _pages;

    return group;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.existingGroup != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Container(
        width: 560,
        height: 620,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(l10n, isEditing, isDark),
            const SizedBox(height: 20),
            _buildTabSelector(l10n, isDark),
            const SizedBox(height: 20),
            Expanded(child: _buildTabContent(isDark)),
            const SizedBox(height: 20),
            _buildFooterButtons(l10n, isEditing, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, bool isEditing, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_selectedIcon, style: const TextStyle(fontSize: 24)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? l10n.editGroup : l10n.createGroup,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_pages.length} ${l10n.pages.toLowerCase()}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
        _HoverBuilder(
          onTap: () => Navigator.of(context).pop(),
          builder: (isHovered) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(
                      alpha: isHovered ? 0.14 : 0.08,
                    )
                  : Colors.black.withValues(
                      alpha: isHovered ? 0.08 : 0.04,
                    ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.close,
              size: 18,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabSelector(AppLocalizations l10n, bool isDark) {
    final tabs = [l10n.general, l10n.appearance, l10n.pages];

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _currentTabIndex == index;
          final isHovered = _hoveredTabIndex == index;
          final baseBorder = isDark ? Colors.white10 : Colors.grey.shade300;
          final hoverFill = isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.grey.shade200;
          final selectedFill = isDark
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white;
          return Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hoveredTabIndex = index),
              onExit: (_) {
                if (_hoveredTabIndex == index) {
                  setState(() => _hoveredTabIndex = null);
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _currentTabIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? selectedFill
                        : (isHovered ? hoverFill : hoverFill.withValues(alpha: 0)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected || isHovered
                          ? baseBorder
                          : baseBorder.withValues(alpha: 0),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tabs[index],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white54 : Colors.black45),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent(bool isDark) {
    switch (_currentTabIndex) {
      case 0:
        return _buildGeneralTab(isDark);
      case 1:
        return _buildAppearanceTab(isDark);
      case 2:
        return _buildPagesTab(isDark);
      default:
        return const SizedBox();
    }
  }

  Widget _buildFooterButtons(
    AppLocalizations l10n,
    bool isEditing,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _HoverBuilder(
          onTap: () => Navigator.of(context).pop(),
          builder: (isHovered) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(
                      alpha: isHovered ? 0.12 : 0.06,
                    )
                  : (isHovered ? Colors.grey.shade200 : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              l10n.cancel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _HoverBuilder(
          onTap: () {
            final group = _buildGroup();
            Navigator.of(context).pop(group);
          },
          builder: (isHovered) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color:
                  _primaryColor.withValues(alpha: isHovered ? 0.9 : 1.0),
              borderRadius: BorderRadius.circular(8),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              isEditing ? l10n.saveChanges : l10n.createGroup,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralTab(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(l10n.groupName, isDark),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _nameController,
            hint: l10n.enterGroupName,
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _buildSectionLabel(l10n.groupIcon, isDark),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presetEmojis.map((emoji) {
              final isSelected = emoji == _selectedIcon;
              return _HoverBuilder(
                onTap: () => setState(() => _selectedIcon = emoji),
                builder: (isHovered) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _primaryColor.withValues(
                            alpha: isHovered ? 0.22 : 0.15,
                          )
                        : (isDark
                              ? Colors.white.withValues(
                                  alpha: isHovered ? 0.12 : 0.06,
                                )
                              : (isHovered
                                    ? Colors.grey.shade200
                                    : Colors.grey.shade100)),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: _primaryColor, width: 2)
                        : (isHovered
                              ? Border.all(
                                  color: _primaryColor.withValues(alpha: 0.4),
                                )
                              : null),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceTab(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(l10n.colorStyle, isDark),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildColorTypeButton(l10n.solid, GroupColorType.solid, isDark),
              const SizedBox(width: 12),
              _buildColorTypeButton(
                l10n.gradient,
                GroupColorType.gradient,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildSectionLabel(l10n.primaryColor, isDark),
          const SizedBox(height: 8),
          _buildColorPicker(
            selectedColor: _primaryColor,
            onColorSelected: (color) => setState(() => _primaryColor = color),
            isDark: isDark,
          ),

          if (_colorType == GroupColorType.gradient) ...[
            const SizedBox(height: 20),
            _buildSectionLabel(l10n.secondaryColor, isDark),
            const SizedBox(height: 8),
            _buildColorPicker(
              selectedColor: _secondaryColor,
              onColorSelected: (color) =>
                  setState(() => _secondaryColor = color),
              isDark: isDark,
            ),
          ],

          const SizedBox(height: 20),
          _buildSectionLabel(l10n.navigationPanelColor, isDark),
          const SizedBox(height: 8),
          _buildColorPicker(
            selectedColor: _navigationColor,
            onColorSelected: (color) =>
                setState(() => _navigationColor = color),
            isDark: isDark,
          ),

          const SizedBox(height: 24),
          _buildSectionLabel(l10n.preview, isDark),
          const SizedBox(height: 8),
          Container(
            height: 56,
            decoration: GroupColorSettings(
              type: _colorType,
              primaryColor: _primaryColor,
              secondaryColor: _secondaryColor,
            ).decoration,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedIcon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Text(
                    _nameController.text.isNotEmpty
                        ? _nameController.text
                        : l10n.groupName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagesTab(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.addPages, isDark),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _pageInputController,
                hint: l10n.pageInputHint,
                isDark: isDark,
                error: _pageInputError,
                onSubmitted: _addPages,
              ),
            ),
            const SizedBox(width: 12),
            _HoverBuilder(
              onTap: () => _addPages(_pageInputController.text),
              builder: (isHovered) => AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: isHovered ? 0.9 : 1.0),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isHovered
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  l10n.add,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${l10n.totalPagesInDocument}: ${widget.totalPages}',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('${l10n.groupPages} (${_pages.length})', isDark),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _pages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.content_paste_off_outlined,
                          size: 40,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.noPagesInGroup,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _pages.length,
                    onReorder: _reorderPages,
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        shadowColor: Colors.black26,
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return _buildPageItem(page, index, isDark);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageItem(GroupedPage page, int index, bool isDark) {
    return Container(
      key: ValueKey(page.pageNumber),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Icon(
              Icons.drag_handle,
              size: 20,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${page.pageNumber}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              page.customName.isNotEmpty
                  ? page.customName
                  : 'Page ${page.pageNumber}',
              style: TextStyle(
                fontSize: 13,
                color: page.customName.isNotEmpty
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white38 : Colors.black38),
                fontStyle: page.customName.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),
          _HoverBuilder(
            onTap: () => _showRenameDialog(page, isDark),
            builder: (isHovered) => Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isHovered
                    ? (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.edit_outlined,
                size: 18,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
          _HoverBuilder(
            onTap: () => _removePage(page.pageNumber),
            builder: (isHovered) => Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isHovered ? Colors.red.shade50 : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.close, size: 18, color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(GroupedPage page, bool isDark) {
    final controller = TextEditingController(text: page.customName);
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.rename} ${l10n.page} ${page.pageNumber}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: controller,
                  hint: l10n.enterGroupName,
                  isDark: isDark,
                  autofocus: true,
                  onSubmitted: (value) {
                    _renamePage(page.pageNumber, value);
                    Navigator.of(ctx).pop();
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _HoverBuilder(
                      onTap: () => Navigator.of(ctx).pop(),
                      builder: (isHovered) => AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(
                                  alpha: isHovered ? 0.12 : 0.06,
                                )
                              : (isHovered
                                    ? Colors.grey.shade200
                                    : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l10n.cancel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _HoverBuilder(
                      onTap: () {
                        _renamePage(page.pageNumber, controller.text);
                        Navigator.of(ctx).pop();
                      },
                      builder: (isHovered) => AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(
                            alpha: isHovered ? 0.9 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l10n.save,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white54 : Colors.black54,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    String? error,
    bool autofocus = false,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: error != null
              ? Colors.red.shade400
              : (isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade200),
        ),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.grey.shade400,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }

  Widget _buildColorTypeButton(String label, GroupColorType type, bool isDark) {
    final isSelected = _colorType == type;
    return Expanded(
      child: _HoverBuilder(
        onTap: () => setState(() => _colorType = type),
        builder: (isHovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? _primaryColor.withValues(
                    alpha: isHovered ? 0.18 : 0.12,
                  )
                : (isDark
                      ? Colors.white.withValues(
                          alpha: isHovered ? 0.12 : 0.06,
                        )
                      : (isHovered
                            ? Colors.grey.shade200
                            : Colors.grey.shade100)),
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: _primaryColor, width: 1.5)
                : (isHovered
                      ? Border.all(
                          color: _primaryColor.withValues(alpha: 0.3),
                        )
                      : null),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? _primaryColor
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorPicker({
    required Color selectedColor,
    required ValueChanged<Color> onColorSelected,
    required bool isDark,
  }) {
    final isCustomColor = !presetColors.any(
      (c) => c.value == selectedColor.value,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...presetColors.map((color) {
          final isSelected = selectedColor.value == color.value;
          return _HoverBuilder(
            onTap: () => onColorSelected(color),
            builder: (isHovered) => AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: isSelected
                    ? Border.all(color: Colors.white, width: 2.5)
                    : (isHovered
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                            )
                          : null),
                boxShadow: isSelected || isHovered
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          );
        }),
        _HoverBuilder(
          onTap: () =>
              _showColorPickerDialog(selectedColor, onColorSelected, isDark),
          builder: (isHovered) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Colors.red,
                  Colors.yellow,
                  Colors.green,
                  Colors.blue,
                  AppColors.primaryBlueSoft,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
              border: isCustomColor
                  ? Border.all(color: Colors.white, width: 2.5)
                  : (isHovered
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                          )
                        : null),
              boxShadow: isCustomColor || isHovered
                  ? [
                      BoxShadow(
                        color: selectedColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isCustomColor ? Icons.check : Icons.palette_outlined,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  void _showColorPickerDialog(
    Color currentColor,
    ValueChanged<Color> onColorSelected,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return _ColorPickerDialog(
          initialColor: currentColor,
          isDark: isDark,
          onColorSelected: (color) {
            onColorSelected(color);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }
}

class _HoverBuilder extends StatefulWidget {
  final Widget Function(bool isHovered) builder;
  final VoidCallback? onTap;

  const _HoverBuilder({required this.builder, this.onTap});

  @override
  State<_HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<_HoverBuilder> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.translucent,
        child: widget.builder(_isHovered),
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final bool isDark;
  final ValueChanged<Color> onColorSelected;

  const _ColorPickerDialog({
    required this.initialColor,
    required this.isDark,
    required this.onColorSelected,
  });

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsvColor;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.initialColor);
    _hexController = TextEditingController(
      text: _colorToHex(widget.initialColor),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return '#${color.red.toRadixString(16).padLeft(2, '0')}${color.green.toRadixString(16).padLeft(2, '0')}${color.blue.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  Color? _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    } catch (_) {}
    return null;
  }

  void _updateFromHex(String hex) {
    final color = _hexToColor(hex);
    if (color != null) {
      setState(() {
        _hsvColor = HSVColor.fromColor(color);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentColor = _hsvColor.toColor();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Color Picker',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            HSVColor.fromAHSV(1, _hsvColor.hue, 1, 1).toColor(),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: GestureDetector(
                      onPanDown: (details) => _updateSaturationValue(
                        details.localPosition,
                        context,
                      ),
                      onPanUpdate: (details) => _updateSaturationValue(
                        details.localPosition,
                        context,
                      ),
                      child: CustomPaint(
                        painter: _ThumbPainter(
                          position: Offset(
                            _hsvColor.saturation * 280,
                            (1 - _hsvColor.value) * 160,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Text(
                  'Hue',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 12,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                    ),
                    child: Stack(
                      children: [
                        Container(
                          height: 12,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF0000),
                                Color(0xFFFFFF00),
                                Color(0xFF00FF00),
                                Color(0xFF00FFFF),
                                Color(0xFF0000FF),
                                Color(0xFFFF00FF),
                                Color(0xFFFF0000),
                              ],
                            ),
                          ),
                        ),
                        Slider(
                          value: _hsvColor.hue,
                          min: 0,
                          max: 360,
                          onChanged: (value) {
                            setState(() {
                              _hsvColor = _hsvColor.withHue(value);
                              _hexController.text = _colorToHex(
                                _hsvColor.toColor(),
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: currentColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: TextField(
                      controller: _hexController,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onChanged: _updateFromHex,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _HoverBuilder(
                  onTap: () => Navigator.of(context).pop(),
                  builder: (isHovered) => AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.white.withValues(
                              alpha: isHovered ? 0.12 : 0.06,
                            )
                          : (isHovered
                                ? Colors.grey.shade200
                                : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.cancel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: widget.isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _HoverBuilder(
                  onTap: () => widget.onColorSelected(currentColor),
                  builder: (isHovered) => AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: currentColor.withValues(
                        alpha: isHovered ? 0.9 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.apply,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateSaturationValue(Offset position, BuildContext context) {
    final size = const Size(280, 160);

    final saturation = (position.dx / size.width).clamp(0.0, 1.0);
    final value = (1 - position.dy / size.height).clamp(0.0, 1.0);

    setState(() {
      _hsvColor = HSVColor.fromAHSV(1, _hsvColor.hue, saturation, value);
      _hexController.text = _colorToHex(_hsvColor.toColor());
    });
  }
}

class _ThumbPainter extends CustomPainter {
  final Offset position;

  _ThumbPainter({required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(position, 8, paint);

    final shadowPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(position, 9, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant _ThumbPainter oldDelegate) {
    return oldDelegate.position != position;
  }
}
