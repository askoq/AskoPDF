import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:asko_pdf/widgets/hover_builder.dart';
import 'package:asko_pdf/widgets/custom_language_dialog.dart';
import 'package:asko_pdf/services/custom_language.dart';
import 'package:asko_pdf/services/settings_service.dart';
import 'package:asko_pdf/l10n/app_localizations.dart';
import 'package:asko_pdf/theme/app_colors.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  int _selectedCategoryIndex = 0;
  final SettingsService _settingsService = SettingsService();

  bool _copyPageAsImageEnabled = true;
  bool _zoomAnimationEnabled = true;
  String _currentLanguage = 'en';
  final ScrollController _viewScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _viewScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final copyEnabled = await _settingsService.getCopyPageAsImageEnabled();
    final zoomAnim = await _settingsService.getZoomAnimationEnabled();
    final lang = await _settingsService.getLanguage();
    if (mounted) {
      setState(() {
        _copyPageAsImageEnabled = copyEnabled;
        _zoomAnimationEnabled = zoomAnim;
        _currentLanguage = lang;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final categories = [
      _SettingsCategory(title: l10n.general, icon: Icons.settings_outlined),
      _SettingsCategory(title: l10n.view, icon: Icons.visibility_outlined),
      _SettingsCategory(title: l10n.about, icon: Icons.info_outline),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 450,
        padding: const EdgeInsets.all(0),
        child: Row(
          children: [
            Container(
              width: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      l10n.settings,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isSelected = _selectedCategoryIndex == index;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCategoryIndex = index;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).primaryColor.withValues(alpha: 0.1)
                                    : null,
                                border: Border(
                                  left: BorderSide(
                                    color: isSelected
                                        ? AppColors.primaryBlue
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    category.icon,
                                    size: 20,
                                    color: isSelected
                                        ? AppColors.primaryBlue
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    category.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? AppColors.primaryBlue
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
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
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildContent()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedCategoryIndex) {
      case 0:
        return _buildGeneralContent();
      case 1:
        return _buildViewContent();
      case 2:
        return _buildAboutContent();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGeneralContent() {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.general,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.language_rounded,
                    color: AppColors.primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.language,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.languageSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == _editLanguageValue) {
                      await _openLanguageEditor();
                      return;
                    }
                    setState(() {
                      _currentLanguage = value;
                    });
                    await _settingsService.setLanguage(value);
                  },
                  offset: const Offset(0, 48),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.white,
                  itemBuilder: (context) => [
                    _buildLanguageMenuItem('English', 'en'),
                    if (CustomLanguage.instance.exists)
                      _buildLanguageMenuItem(
                        CustomLanguage.instance.displayName,
                        CustomLanguage.settingsCode,
                        badge: _customLanguageBadge,
                      ),
                    const PopupMenuDivider(),
                    _buildEditLanguageMenuItem(l10n),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              _currentLanguage == 'en'
                                  ? 'EN'
                                  : _customLanguageBadge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _currentLanguage == 'en'
                              ? 'English'
                              : CustomLanguage.instance.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 18,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const String _editLanguageValue = '__edit_language';

  String get _customLanguageBadge {
    final name = CustomLanguage.instance.name.trim();
    if (name.isEmpty) return '+';
    return name.characters.take(2).toString().toUpperCase();
  }

  Future<void> _openLanguageEditor() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => const CustomLanguageDialog(),
    );
    if (saved != true || !mounted) return;
    setState(() => _currentLanguage = CustomLanguage.settingsCode);
    await _settingsService.setLanguage(CustomLanguage.settingsCode);
  }

  PopupMenuItem<String> _buildEditLanguageMenuItem(AppLocalizations l10n) {
    return PopupMenuItem<String>(
      value: _editLanguageValue,
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                CustomLanguage.instance.exists
                    ? Icons.edit_outlined
                    : Icons.add_rounded,
                size: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              CustomLanguage.instance.exists
                  ? l10n.editTranslation
                  : l10n.addLanguage,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildLanguageMenuItem(
    String label,
    String value, {
    String? badge,
  }) {
    final isSelected = _currentLanguage == value;
    return PopupMenuItem<String>(
      value: value,
      height: 48,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryBlue.withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  badge ?? value.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.primaryBlue
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primaryBlue
                      : Colors.grey.shade700,
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: AppColors.primaryBlue,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewContent() {
    final l10n = AppLocalizations.of(context)!;

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final offset = event.scrollDelta.dy;
          final target = (_viewScrollController.offset + offset).clamp(
            _viewScrollController.position.minScrollExtent,
            _viewScrollController.position.maxScrollExtent,
          );
          _viewScrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: SingleChildScrollView(
        controller: _viewScrollController,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.viewSettings,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.viewSettingsSubtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),

            _buildSettingTile(
              icon: Icons.content_copy_rounded,
              title: l10n.copyPageAsImage,
              subtitle: l10n.copyPageAsImageSubtitle,
              value: _copyPageAsImageEnabled,
              onChanged: (value) async {
                setState(() {
                  _copyPageAsImageEnabled = value;
                });
                await _settingsService.setCopyPageAsImageEnabled(value);
              },
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              icon: Icons.animation_rounded,
              title: l10n.zoomAnimation,
              subtitle: l10n.zoomAnimationSubtitle,
              value: _zoomAnimationEnabled,
              onChanged: (value) async {
                setState(() {
                  _zoomAnimationEnabled = value;
                });
                await _settingsService.setZoomAnimationEnabled(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return HoverBuilder(
      builder: (context, isHovered) {
        return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isHovered ? Colors.grey.shade100 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHovered ? Colors.grey.shade300 : Colors.grey.shade200,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primaryBlue, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildCustomSwitch(value, onChanged),
              ],
            ),
          );
      },
    );
  }

  Widget _buildCustomSwitch(bool value, ValueChanged<bool> onChanged) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, isHovered) {
        return GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: value
                    ? Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: isHovered ? 0.9 : 1.0)
                    : (isHovered ? Colors.grey.shade400 : Colors.grey.shade300),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
      },
    );
  }

  Widget _buildAboutContent() {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 28),
      child: Column(
        children: [
          const Spacer(),
          Image.asset(
            'assets/images/logo.png',
            height: 36,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Text(
                'AskoPDF',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '1.5.0',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'gelide-pdf-0.7.2 · pdfium-159.0.8152.0',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${l10n.madeBy} ',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse('https://github.com/askoq');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Text(
                    'askoq',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primaryBlue,
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

class _SettingsCategory {
  final String title;
  final IconData icon;

  _SettingsCategory({required this.title, required this.icon});
}
