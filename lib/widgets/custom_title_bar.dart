import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

class CustomTitleBar extends StatelessWidget {
  final String? title;
  final String? projectName;
  final String? centerTitle;
  final Color? backgroundColor;
  final List<Widget>? actions;

  final void Function(Offset globalPosition)? onCenterTitleTap;

  const CustomTitleBar({
    super.key,
    this.title,
    this.projectName,
    this.centerTitle,
    this.backgroundColor,
    this.actions,
    this.onCenterTitleTap,
  });

  String get displayTitle {
    if (projectName != null && projectName!.isNotEmpty) {
      return 'AskoPDF - $projectName';
    }
    return title ?? 'AskoPDF';
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: MoveWindow(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Text(
                          displayTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        if (actions != null) ...[const Spacer(), ...actions!],
                      ],
                    ),
                  ),
                ),
              ),
              const WindowButtons(),
            ],
          ),
          if (centerTitle != null && centerTitle!.isNotEmpty)
            _CenterTitleWidget(
              label: centerTitle!,
              isDark: isDark,
              onTap: onCenterTitleTap,
            ),
        ],
      ),
    );
  }
}

class _CenterTitleWidget extends StatefulWidget {
  final String label;
  final bool isDark;
  final void Function(Offset globalPosition)? onTap;

  const _CenterTitleWidget({
    required this.label,
    required this.isDark,
    this.onTap,
  });

  @override
  State<_CenterTitleWidget> createState() => _CenterTitleWidgetState();
}

class _CenterTitleWidgetState extends State<_CenterTitleWidget> {
  bool _isHovering = false;
  final GlobalKey _buttonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final isClickable = widget.onTap != null;

    final child = MouseRegion(
      onEnter: isClickable ? (_) => setState(() => _isHovering = true) : null,
      onExit: isClickable ? (_) => setState(() => _isHovering = false) : null,
      child: GestureDetector(
        onTap: isClickable
            ? () {
                final renderBox =
                    _buttonKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  final pos = renderBox.localToGlobal(
                    Offset(0, renderBox.size.height),
                  );
                  widget.onTap!(pos);
                }
              }
            : null,
        child: Container(
          key: _buttonKey,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _isHovering
                ? (widget.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  decoration: TextDecoration.none,
                ),
              ),
              if (isClickable) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return child;
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _WindowButton(
          icon: Icons.remove,
          onPressed: () => appWindow.minimize(),
          hoverColor: Colors.grey.shade200,
        ),
        _WindowButton(
          icon: Icons.crop_square,
          onPressed: () => appWindow.maximizeOrRestore(),
          hoverColor: Colors.grey.shade200,
        ),
        _WindowButton(
          icon: Icons.close,
          onPressed: () => appWindow.close(),
          hoverColor: Colors.red,
          hoverIconColor: Colors.white,
        ),
      ],
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color hoverColor;
  final Color? hoverIconColor;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    required this.hoverColor,
    this.hoverIconColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 32,
          color: _isHovering ? widget.hoverColor : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovering && widget.hoverIconColor != null
                ? widget.hoverIconColor
                : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
