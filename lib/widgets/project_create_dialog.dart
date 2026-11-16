import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:asko_pdf/l10n/app_localizations.dart';
import 'package:asko_pdf/theme/app_colors.dart';

class ProjectCreateDialog extends StatefulWidget {
  final String? existingName;
  final List<String>? existingFiles;
  final bool isEditing;

  const ProjectCreateDialog({
    super.key,
    this.existingName,
    this.existingFiles,
    this.isEditing = false,
  });

  @override
  State<ProjectCreateDialog> createState() => _ProjectCreateDialogState();
}

class _ProjectCreateDialogState extends State<ProjectCreateDialog> {
  late TextEditingController _nameController;
  List<String> _files = [];
  bool _isDragging = false;
  bool _isDropZoneHovered = false;
  String? _nameError;
  String? _filesError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingName ?? '');
    _files = List.from(widget.existingFiles ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addFiles(List<String> paths) {
    setState(() {
      for (final path in paths) {
        if (path.toLowerCase().endsWith('.pdf') && !_files.contains(path)) {
          _files.add(path);
        }
      }
      if (_files.isNotEmpty && _filesError != null) {
        _filesError = null;
      }
    });
  }

  void _removeFile(String path) {
    setState(() {
      _files.remove(path);
    });
  }

  Future<void> _pickFiles() async {
    const typeGroup = XTypeGroup(
      label: 'PDF files',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
      uniformTypeIdentifiers: ['com.adobe.pdf'],
    );
    final files = await openFiles(acceptedTypeGroups: [typeGroup]);

    if (files.isNotEmpty) {
      _addFiles(files.map((f) => f.path).toList());
    }
  }

  void _submit() {
    final name = _nameController.text.trim();
    final l10n = AppLocalizations.of(context);

    if (name.isEmpty) {
      setState(() {
        _nameError = l10n?.enterProjectName ?? 'Enter project name';
      });
      return;
    }

    if (_files.isEmpty) {
      setState(() {
        _filesError = l10n?.projectRequiresFiles ?? 'Add at least one file';
      });
      return;
    }

    Navigator.of(context).pop({'name': name, 'files': _files});
  }

  String _getFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(l10n, isDark),
            const SizedBox(height: 24),
            _buildNameField(l10n, isDark),
            const SizedBox(height: 20),
            _buildFilesSection(l10n, isDark),
            const SizedBox(height: 24),
            _buildFooterButtons(l10n, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.folder_outlined,
            color: AppColors.primaryBlue,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            widget.isEditing ? l10n.editProject : l10n.createProject,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        _HoverIconButton(
          onTap: () => Navigator.of(context).pop(),
          icon: Icons.close,
          iconColor: isDark ? Colors.white54 : Colors.black45,
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.04),
          hoverColor: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ],
    );
  }

  Widget _buildNameField(AppLocalizations l10n, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.projectName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          autofocus: true,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: l10n.enterProjectName,
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            errorText: _nameError,
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primaryBlue, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onChanged: (_) {
            if (_nameError != null) {
              setState(() => _nameError = null);
            }
          },
          onSubmitted: (_) => _submit(),
        ),
      ],
    );
  }

  Widget _buildFilesSection(AppLocalizations l10n, bool isDark) {
    final showFilesError = _filesError != null && _files.isEmpty;
    final isHovering = _isDropZoneHovered && !_isDragging;

    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                l10n.addDocuments,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _isDropZoneHovered = true),
              onExit: (_) => setState(() => _isDropZoneHovered = false),
              child: DropTarget(
                onDragEntered: (_) => setState(() => _isDragging = true),
                onDragExited: (_) => setState(() => _isDragging = false),
                onDragDone: (details) {
                  setState(() => _isDragging = false);
                  _addFiles(details.files.map((f) => f.path).toList());
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _files.isEmpty ? _pickFiles : null,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    scale: _isDragging ? 1.01 : (isHovering ? 1.004 : 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      constraints: const BoxConstraints(
                        minHeight: 120,
                        maxHeight: 250,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            isDark ? const Color(0xFF252525) : Colors.white,
                            _isDragging
                                ? AppColors.primaryBlue.withValues(alpha: 0.08)
                                : (isHovering
                                      ? AppColors.primaryBlue.withValues(
                                          alpha: 0.04,
                                        )
                                      : (isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.03,
                                              )
                                            : Colors.grey.shade50)),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: showFilesError
                              ? Colors.red.shade400
                              : (_isDragging
                                    ? AppColors.primaryBlue
                                    : (isHovering
                                          ? AppColors.primaryBlue.withValues(
                                              alpha: 0.38,
                                            )
                                          : (isDark
                                                ? Colors.white12
                                                : Colors.grey.shade300))),
                          width: (showFilesError || _isDragging) ? 2 : 1,
                        ),
                        boxShadow: [
                          if (_isDragging || isHovering)
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: _isDragging ? 0.1 : 0.05,
                              ),
                              blurRadius: _isDragging ? 20 : 14,
                              offset: const Offset(0, 8),
                            ),
                        ],
                      ),
                      child: _files.isEmpty
                          ? _buildEmptyDropZone(
                              l10n,
                              isDark,
                              highlight: _isDragging || isHovering,
                            )
                          : _buildFilesList(isDark),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_filesError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _filesError!,
                style: TextStyle(fontSize: 12, color: Colors.red.shade400),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyDropZone(
    AppLocalizations l10n,
    bool isDark, {
    required bool highlight,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _pickFiles,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(
                    alpha: highlight ? 0.14 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(
                      alpha: highlight ? 0.3 : 0.14,
                    ),
                  ),
                ),
                child: const Icon(
                  Icons.add_circle_outline,
                  size: 28,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.dropFilesHere,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.orClickToSelect,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilesList(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.all(8),
            itemCount: _files.length,
            itemBuilder: (context, index) {
              final path = _files[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_rounded,
                      size: 18,
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getFileName(path),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeFile(path),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          child: TextButton.icon(
            onPressed: _pickFiles,
            icon: const Icon(Icons.add, size: 18),
            label: Text(AppLocalizations.of(context)!.addDocuments),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterButtons(AppLocalizations l10n, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _HoverActionButton(
          label: l10n.cancel,
          backgroundColor: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade100,
          hoverColor: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.grey.shade200,
          textColor: isDark ? Colors.white70 : Colors.black54,
          onTap: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 12),
        _HoverActionButton(
          label: widget.isEditing ? l10n.saveChanges : l10n.createProject,
          backgroundColor: AppColors.primaryBlue,
          hoverColor: AppColors.primaryBlue.withValues(alpha: 0.85),
          textColor: Colors.white,
          onTap: _submit,
        ),
      ],
    );
  }
}

class _HoverActionButton extends StatefulWidget {
  final String label;
  final Color backgroundColor;
  final Color hoverColor;
  final Color textColor;
  final VoidCallback onTap;

  const _HoverActionButton({
    required this.label,
    required this.backgroundColor,
    required this.hoverColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  State<_HoverActionButton> createState() => _HoverActionButtonState();
}

class _HoverActionButtonState extends State<_HoverActionButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: widget.textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverIconButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color hoverColor;

  const _HoverIconButton({
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.hoverColor,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isHovered ? widget.hoverColor : widget.backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.icon, size: 18, color: widget.iconColor),
        ),
      ),
    );
  }
}
