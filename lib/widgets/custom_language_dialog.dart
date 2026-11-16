import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:asko_pdf/l10n/app_localizations.dart';
import 'package:asko_pdf/services/custom_language.dart';
import 'package:asko_pdf/theme/app_colors.dart';
import 'package:asko_pdf/widgets/hover_builder.dart';

class CustomLanguageDialog extends StatefulWidget {
  const CustomLanguageDialog({super.key});

  @override
  State<CustomLanguageDialog> createState() => _CustomLanguageDialogState();
}

class _CustomLanguageDialogState extends State<CustomLanguageDialog> {
  late final Map<String, String> _english;
  late final List<String> _keys;
  late final TextEditingController _nameController;
  final Map<String, TextEditingController> _controllers = {};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final language = CustomLanguage.instance;
    _english = AppLocalizations.englishStrings;
    _keys = _english.keys.where((key) => key != 'appName').toList();
    _nameController = TextEditingController(text: language.name);
    for (final key in _keys) {
      _controllers[key] = TextEditingController(
        text: language.strings[key] ?? '',
      )..addListener(_onTranslationChanged);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTranslationChanged() {
    if (mounted) setState(() {});
  }

  int get _translatedCount => _controllers.values
      .where((controller) => controller.text.trim().isNotEmpty)
      .length;

  List<String> get _visibleKeys {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _keys;
    return _keys.where((key) {
      return key.toLowerCase().contains(query) ||
          _english[key]!.toLowerCase().contains(query) ||
          _controllers[key]!.text.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await CustomLanguage.instance.save(
        name: _nameController.text,
        strings: {
          for (final key in _keys) key: _controllers[key]!.text,
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _openFolder() async {
    final dir = await CustomLanguage.instance.folder();
    await launchUrl(Uri.directory(dir.path));
  }

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screen = MediaQuery.sizeOf(context);
    final keys = _visibleKeys;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: SizedBox(
        width: 640,
        height: (screen.height * 0.85).clamp(360.0, 760.0).toDouble(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.customLanguageTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.customLanguageHint,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _nameController,
                      maxLength: 40,
                      style: const TextStyle(fontSize: 14),
                      decoration: _fieldDecoration(
                        hint: l10n.languageNameHint,
                      ).copyWith(labelText: l10n.languageName, counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      style: const TextStyle(fontSize: 14),
                      decoration: _fieldDecoration(hint: l10n.searchStrings)
                          .copyWith(
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: Colors.grey.shade500,
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: ColoredBox(
                color: Colors.grey.shade50,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  itemCount: keys.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final key = keys[index];
                    final english = _english[key]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          english,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _controllers[key],
                          minLines: 1,
                          maxLines: english.length > 60 ? 3 : 1,
                          style: const TextStyle(fontSize: 14),
                          decoration: _fieldDecoration(hint: english),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                children: [
                  Text(
                    '$_translatedCount / ${_keys.length} ${l10n.translatedCount}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _LanguageDialogButton(
                    label: l10n.openTranslationFolder,
                    icon: Icons.folder_open_rounded,
                    backgroundColor: Colors.white,
                    hoverColor: Colors.grey.shade100,
                    textColor: Colors.grey.shade700,
                    onTap: _openFolder,
                  ),
                  const Spacer(),
                  _LanguageDialogButton(
                    label: l10n.cancel,
                    backgroundColor: Colors.grey.shade100,
                    hoverColor: Colors.grey.shade200,
                    textColor: Colors.black54,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 8),
                  _LanguageDialogButton(
                    label: l10n.save,
                    backgroundColor: AppColors.primaryBlue,
                    hoverColor: Color.alphaBlend(
                      Colors.black.withValues(alpha: 0.08),
                      AppColors.primaryBlue,
                    ),
                    textColor: Colors.white,
                    onTap: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageDialogButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color hoverColor;
  final Color textColor;
  final VoidCallback? onTap;

  const _LanguageDialogButton({
    required this.label,
    this.icon,
    required this.backgroundColor,
    required this.hoverColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return HoverBuilder(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      builder: (context, isHovered) {
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isHovered && enabled ? hoverColor : backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: backgroundColor == Colors.white
                  ? Border.all(color: Colors.grey.shade300)
                  : null,
            ),
            child: Opacity(
              opacity: enabled ? 1 : 0.6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: textColor),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
