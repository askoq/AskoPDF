import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:asko_pdf/l10n/app_localizations.dart';
import 'package:asko_pdf/theme/app_colors.dart';

class CustomZoomDialog extends StatelessWidget {
  final double currentScale;

  const CustomZoomDialog({super.key, required this.currentScale});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: (currentScale * 100).round().toString(),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.zoom,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 120,
              child: TextField(
                controller: controller,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  suffixText: '%',
                  suffixStyle: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColors.primaryBlue,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => Navigator.of(context).pop(controller.text),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${l10n.minZoom} · ${l10n.maxZoom}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ZoomDialogButton(
                  label: l10n.cancel,
                  backgroundColor: Colors.grey.shade100,
                  hoverColor: Colors.grey.shade200,
                  textColor: Colors.black54,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                _ZoomDialogButton(
                  label: l10n.apply,
                  backgroundColor: AppColors.primaryBlue,
                  hoverColor: AppColors.primaryBlue.withValues(
                    alpha: 0.85,
                  ),
                  textColor: Colors.white,
                  onTap: () => Navigator.of(context).pop(controller.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomDialogButton extends StatefulWidget {
  final String label;
  final Color backgroundColor;
  final Color hoverColor;
  final Color textColor;
  final VoidCallback onTap;

  const _ZoomDialogButton({
    required this.label,
    required this.backgroundColor,
    required this.hoverColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  State<_ZoomDialogButton> createState() => _ZoomDialogButtonState();
}

class _ZoomDialogButtonState extends State<_ZoomDialogButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
