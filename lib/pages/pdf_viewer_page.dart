import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:asko_pdf/widgets/hover_builder.dart';
import 'package:asko_pdf/theme/app_colors.dart';

import 'package:file_selector/file_selector.dart';
import 'package:asko_pdf/services/recent_files_service.dart';
import 'package:asko_pdf/services/document_state_service.dart';
import 'package:asko_pdf/services/document_storage_service.dart';
import 'package:asko_pdf/services/project_service.dart';
import 'package:asko_pdf/services/pdf_engine.dart';
import 'package:asko_pdf/services/gelide_pdf_engine.dart';
import 'package:asko_pdf/widgets/pdf_navigation_drawer.dart';
import 'package:asko_pdf/widgets/document_info_dialog.dart';
import 'package:asko_pdf/widgets/custom_zoom_dialog.dart';
import 'package:asko_pdf/widgets/pdf_view_components.dart';
import 'package:asko_pdf/widgets/settings_dialog.dart';
import 'package:asko_pdf/widgets/group_edit_dialog.dart';
import 'package:asko_pdf/widgets/project_create_dialog.dart';
import 'package:asko_pdf/models/pdf_tab.dart';
import 'package:asko_pdf/models/pdf_metadata.dart';
import 'package:asko_pdf/models/page_group.dart';
import 'package:asko_pdf/models/file_identifier.dart';
import 'package:asko_pdf/models/project.dart';
import 'package:asko_pdf/widgets/pdf_tab_bar.dart';
import 'package:asko_pdf/services/page_group_service.dart';
import 'package:asko_pdf/services/settings_service.dart';
import 'package:asko_pdf/widgets/custom_title_bar.dart';
import 'package:asko_pdf/l10n/app_localizations.dart';
import 'package:pasteboard/pasteboard.dart';

class PdfViewerPage extends StatefulWidget {
  const PdfViewerPage({super.key});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _NoScrollbarBehavior extends MaterialScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
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

class _CardIconActionButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color hoverIconColor;
  final Color hoverBackgroundColor;
  final VoidCallback onTap;

  const _CardIconActionButton({
    required this.icon,
    required this.iconColor,
    required this.hoverIconColor,
    required this.hoverBackgroundColor,
    required this.onTap,
  });

  @override
  State<_CardIconActionButton> createState() => _CardIconActionButtonState();
}

class _CardIconActionButtonState extends State<_CardIconActionButton> {
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
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.hoverBackgroundColor
                : widget.hoverBackgroundColor.withValues(alpha: 0),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            size: 14,
            color: _isHovered ? widget.hoverIconColor : widget.iconColor,
          ),
        ),
      ),
    );
  }
}

class _PdfViewerPageState extends State<PdfViewerPage>
    with TickerProviderStateMixin {
  static const double _minScale = 0.1;
  static const double _maxScale = 4.0;
  static const double _pageSpacing = 16.0;
  static const double _tileScaleThreshold = 2.5;
  static const int _tileSize = 512;
  static const int _thumbnailCacheLimit = 200;
  static const double _tileFallbackRenderScale = 1.5;
  static const int _visibleCacheBuffer = 3;
  static const int _maxRenderedPages = 10;
  static const int _prefetchScreensAfterScale = 2;
  static const double _previewRenderScaleCap = 1.0;
  static const double _previewMinScale = 1.25;
  static const Duration _rerenderDebounce = Duration(milliseconds: 120);

  final List<PdfTab> _tabs = [];
  int _currentTabIndex = -1;
  bool _isTabBarExpanded = false;

  AnimationController? _zoomAnimationController;
  Animation<double>? _zoomAnimation;
  double _animatedScale = 1.0;

  final RecentFilesService _recentFilesService = RecentFilesService();
  final DocumentStateService _documentStateService = DocumentStateService();
  final PageGroupService _pageGroupService = PageGroupService();
  final SettingsService _settingsService = SettingsService();
  final ProjectService _projectService = ProjectService();
  final PdfEngine _pdfEngine = GelidePdfEngine();

  List<String> _recentFiles = [];
  Map<String, DocumentState?> _recentFilesState = {};
  Map<String, DocumentData?> _recentFilesData = {};
  String? _editingRecentPath;
  final TextEditingController _recentRenameController = TextEditingController();
  bool _isDragging = false;
  bool _isDropZoneHovered = false;
  bool _isRecentFilesExpanded = true;
  bool _copyPageAsImageEnabled = true;
  bool _zoomAnimationEnabled = true;
  bool _isEngineUnavailableDialogOpen = false;

  Map<String, DocumentGroups> _documentGroups = {};

  List<Project> _projects = [];
  Project? _currentProject;
  bool _isProjectMode = false;
  bool _isProjectsExpanded = true;
  bool _isLoadingProject = false;
  int _projectLoadingCurrentFile = 0;
  int _projectLoadingTotalFiles = 0;
  String _projectLoadingFileName = '';

  final GlobalKey _rotateButtonKey = GlobalKey();
  final GlobalKey _leftRotateButtonKey = GlobalKey();
  final GlobalKey _rightRotateButtonKey = GlobalKey();
  final Map<String, OverlayEntry> _rotationMenuOverlays = {};
  String? _editingSplitTabId;
  final TextEditingController _splitRenameController = TextEditingController();

  int? _splitTabIndex;
  bool _splitDropZoneActive = false;

  final Map<String, Timer> _rerenderTimers = {};
  final Map<String, double> _pendingRerenderScales = {};
  final Map<String, Timer> _scalePrefetchTimers = {};

  PdfTab? get _activeTab =>
      (_currentTabIndex >= 0 && _currentTabIndex < _tabs.length)
      ? _tabs[_currentTabIndex]
      : null;

  PdfTab? get _splitTab =>
      (_splitTabIndex != null &&
          _splitTabIndex! >= 0 &&
          _splitTabIndex! < _tabs.length)
      ? _tabs[_splitTabIndex!]
      : null;

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
    _loadSettings();
    _loadProjects();
  }

  Future<void> _loadRecentFiles() async {
    final files = await _recentFilesService.getRecentFiles();
    final Map<String, DocumentState?> states = {};
    final Map<String, DocumentData?> data = {};
    for (final path in files) {
      final docData = await _documentStateService.getDocumentData(path);
      data[path] = docData;
      states[path] =
          docData?.state ?? await _documentStateService.getDocumentState(path);
    }
    if (mounted) {
      setState(() {
        _recentFiles = files;
        _recentFilesState = states;
        _recentFilesData = data;
      });
    }
  }

  Future<void> _loadSettings() async {
    final copyEnabled = await _settingsService.getCopyPageAsImageEnabled();
    final zoomAnim = await _settingsService.getZoomAnimationEnabled();
    if (mounted) {
      setState(() {
        _copyPageAsImageEnabled = copyEnabled;
        _zoomAnimationEnabled = zoomAnim;
      });
    }
  }

  Future<void> _loadProjects() async {
    final projects = await _projectService.getProjects();
    if (mounted) {
      setState(() {
        _projects = projects;
      });
    }
  }

  String _getTabDisplayName(PdfTab tab) {
    if (tab.customTitle.isNotEmpty) {
      return tab.customTitle;
    }
    if (tab.documentTitle.isNotEmpty) {
      return tab.documentTitle;
    }
    return tab.filePath.split(Platform.pathSeparator).last;
  }

  void _showErrorToast(String title, String message) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Colors.red.shade400;
    final background = isDark
        ? const Color(0xFF2B1E1E)
        : const Color(0xFFFFF5F5);
    final borderColor = isDark
        ? Colors.red.shade300.withValues(alpha: 0.35)
        : Colors.red.shade200;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.warning_rounded, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPdfEngineUnavailableDialog(
    GelideEngineUnavailableException error,
  ) async {
    if (!mounted || _isEngineUnavailableDialogOpen) return;
    _isEngineUnavailableDialogOpen = true;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPdfiumMissing = error.dependency == GelideMissingDependency.pdfium;
    final message = isPdfiumMissing
        ? l10n.pdfiumMissingMessage
        : l10n.pdfEngineMissingMessage;
    final hint = isPdfiumMissing
        ? l10n.pdfiumMissingHint
        : l10n.pdfEngineMissingHint;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Container(
              width: 460,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.memory_rounded,
                          color: Colors.red.shade400,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          l10n.pdfEngineMissingTitle,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      hint,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: isDark ? Colors.white60 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.technicalDetails,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 120),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF151515)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        error.details,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _DialogActionButton(
                      label: l10n.close,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.shade100,
                      hoverColor: isDark
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.grey.shade200,
                      textColor: isDark ? Colors.white70 : Colors.black54,
                      onTap: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      _isEngineUnavailableDialogOpen = false;
    }
  }

  Future<void> _createProject() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const ProjectCreateDialog(),
    );

    if (result != null && result['name'] != null) {
      final l10n = AppLocalizations.of(context)!;
      final name = result['name'] as String;
      final files = result['files'] as List<String>? ?? [];

      if (files.isEmpty) {
        _showErrorToast(l10n.projectEmpty, l10n.projectRequiresFiles);
        return;
      }

      await _projectService.createProject(
        name,
        initialFiles: files,
      );
      await _loadProjects();
    }
  }

  Future<void> _editProject(Project project) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ProjectCreateDialog(
        existingName: project.name,
        existingFiles: project.documents.map((d) => d.filePath).toList(),
        isEditing: true,
      ),
    );

    if (result != null && result['name'] != null) {
      final l10n = AppLocalizations.of(context)!;
      final name = result['name'] as String;
      final files = result['files'] as List<String>? ?? [];

      if (files.isEmpty) {
        _showErrorToast(l10n.projectEmpty, l10n.projectRequiresFiles);
        return;
      }

      final updatedDocs = <ProjectDocument>[];
      for (int i = 0; i < files.length; i++) {
        final path = files[i];
        final existing = project.getDocumentByPath(path);
        updatedDocs.add(
          ProjectDocument(
            id: existing?.id,
            filePath: path,
            customTabName: existing?.customTabName ?? '',
            orderIndex: i,
          ),
        );
      }

      project.name = name;
      project.documents = updatedDocs;
      await _projectService.updateProject(project);

      if (_currentProject?.id == project.id) {
        setState(() {
          _currentProject = project;
        });
      }

      await _loadProjects();
    }
  }

  Future<void> _openProject(Project project) async {
    final updatedProject = await _projectService.getProject(project.id);
    final projectToOpen = updatedProject ?? project;
    final sortedDocs = projectToOpen.sortedDocuments;
    final validDocs = <ProjectDocument>[];

    for (final doc in sortedDocs) {
      if (await File(doc.filePath).exists()) {
        validDocs.add(doc);
      }
    }

    if (validDocs.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      _showErrorToast(l10n.projectEmpty, l10n.projectRequiresFiles);
      setState(() {
        _isLoadingProject = false;
        _projectLoadingCurrentFile = 0;
        _projectLoadingTotalFiles = 0;
        _projectLoadingFileName = '';
      });
      return;
    }

    setState(() {
      _isLoadingProject = true;
      _projectLoadingCurrentFile = 0;
      _projectLoadingTotalFiles = 0;
      _projectLoadingFileName = '';
    });

    for (final tab in _tabs) {
      tab.dispose();
    }
    setState(() {
      _tabs.clear();
      _currentTabIndex = -1;
    });

    await _projectService.markProjectOpened(projectToOpen.id);
    final refreshedProject = await _projectService.getProject(projectToOpen.id);

    setState(() {
      _currentProject = refreshedProject ?? projectToOpen;
      _isProjectMode = true;
    });

    setState(() {
      _projectLoadingTotalFiles = validDocs.length;
    });

    for (int i = 0; i < validDocs.length; i++) {
      final doc = validDocs[i];
      final fileName = doc.filePath.split(Platform.pathSeparator).last;

      setState(() {
        _projectLoadingCurrentFile = i + 1;
        _projectLoadingFileName = fileName;
      });

      await _openFileInProject(doc.filePath, customTabName: doc.customTabName);
    }

    setState(() {
      _isLoadingProject = false;
      _projectLoadingCurrentFile = 0;
      _projectLoadingTotalFiles = 0;
      _projectLoadingFileName = '';
      if (_tabs.isNotEmpty) {
        _currentTabIndex = 0;
      }
    });

    await _loadProjects();
  }

  Future<void> _openFileInProject(
    String filePath, {
    String? customTabName,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return;
    }

    final fileIdentifier = await FileIdentifier.fromFile(filePath);

    final existingIndex = _tabs.indexWhere((tab) => tab.filePath == filePath);
    if (existingIndex != -1) {
      return;
    }

    final newTab = PdfTab(
      id: '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
      filePath: filePath,
    );
    newTab.fileIdentifier = fileIdentifier;
    if (customTabName != null && customTabName.isNotEmpty) {
      newTab.customTitle = customTabName;
    }

    newTab.scrollController.addListener(_onScroll);

    setState(() {
      _tabs.add(newTab);
    });

    await _loadAndRenderPdf(newTab);
    await _loadDocumentGroups(newTab);
  }

  Future<void> _saveProjectState() async {
    if (!_isProjectMode || _currentProject == null) return;

    _currentProject!.documents.clear();
    for (int i = 0; i < _tabs.length; i++) {
      final tab = _tabs[i];
      _currentProject!.documents.add(
        ProjectDocument(
          filePath: tab.filePath,
          customTabName: tab.customTitle,
          orderIndex: i,
        ),
      );
    }

    await _projectService.updateProject(_currentProject!);
  }

  void _closeProject() {
    for (final tab in _tabs) {
      _saveCurrentState(tab);
      tab.dispose();
    }

    setState(() {
      _tabs.clear();
      _currentTabIndex = -1;
      _currentProject = null;
      _isProjectMode = false;
      _isTabBarExpanded = false;
    });

    for (final timer in _rerenderTimers.values) {
      timer.cancel();
    }
    _rerenderTimers.clear();
    _pendingRerenderScales.clear();
    for (final timer in _scalePrefetchTimers.values) {
      timer.cancel();
    }
    _scalePrefetchTimers.clear();
  }

  Future<void> _deleteProject(String projectId) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.deleteProject,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.deleteProjectConfirm,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogActionButton(
                    label: l10n.cancel,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade100,
                    hoverColor: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.grey.shade200,
                    textColor: isDark ? Colors.white70 : Colors.black54,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 12),
                  _DialogActionButton(
                    label: l10n.delete,
                    backgroundColor: Colors.red.shade400,
                    hoverColor: Colors.red.shade300,
                    textColor: Colors.white,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      if (_currentProject?.id == projectId) {
        _closeProject();
      }
      await _projectService.deleteProject(projectId);
      await _loadProjects();
    }
  }

  Future<void> _copyCurrentPageAsImage() async {
    final tab = _activeTab;
    if (tab == null) return;

    final pageIndex = tab.currentPage - 1;
    if (pageIndex < 0 || pageIndex >= tab.renderedPages.length) return;

    final image = tab.renderedPages[pageIndex];
    if (image == null) return;

    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final imageBytes = byteData.buffer.asUint8List();
      await Pasteboard.writeImage(imageBytes);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  '${l10n.page} ${tab.currentPage} ${l10n.copiedToClipboard}',
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showErrorToast(l10n.failedToCopy, e.toString());
      }
    }
  }

  void _showPageContextMenu(BuildContext context, Offset position) {
    final tab = _activeTab;
    if (tab == null) return;
    final l10n = AppLocalizations.of(context)!;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          onTap: _copyCurrentPageAsImage,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.content_copy_rounded,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.copyPageAsImage,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      softWrap: true,
                    ),
                    Text(
                      '${l10n.page} ${tab.currentPage}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onScroll([PdfTab? specificTab]) {
    final tab = specificTab ?? _activeTab;
    if (tab == null ||
        tab.pageOffsets.isEmpty ||
        !tab.scrollController.hasClients) {
      return;
    }

    final viewportCenter =
        tab.scrollController.offset +
        tab.scrollController.position.viewportDimension / 2;
    final scaledPadding = _pageSpacing * tab.scale;

    int newPage = 1;
    for (int i = 0; i < tab.pageOffsets.length; i++) {
      final scaledOffset = tab.pageOffsets[i] * tab.scale + scaledPadding;
      if (scaledOffset <= viewportCenter) {
        newPage = i + 1;
      } else {
        break;
      }
    }

    if (newPage != tab.currentPage) {
      setState(() {
        tab.currentPage = newPage;
      });
      _saveCurrentState(tab);
      _scheduleRerender(tab, tab.scale);
    }
  }

  Future<void> _saveCurrentState(PdfTab tab) async {
    if (tab.filePath.isNotEmpty && tab.totalPages > 0) {
      final state = DocumentState(
        currentPage: tab.currentPage,
        scale: tab.scale,
      );
      await _documentStateService.saveDocumentState(
        tab.filePath,
        currentPage: state.currentPage,
        scale: state.scale,
      );
      if (mounted) {
        setState(() {
          _recentFilesState[tab.filePath] = state;
          final existing = _recentFilesData[tab.filePath];
          if (existing != null) {
            _recentFilesData[tab.filePath] = existing.copyWith(state: state);
          }
        });
      }
    }
  }

  Future<void> _openPdfFile() async {
    const typeGroup = XTypeGroup(
      label: 'PDF files',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
      uniformTypeIdentifiers: ['com.adobe.pdf'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      _openFile(file.path);
    }
  }

  Future<void> _openFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      await _recentFilesService.removeRecentFile(filePath);
      await _loadRecentFiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF file was deleted or moved'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final fileIdentifier = await FileIdentifier.fromFile(filePath);
    final existingData = await _documentStateService.getDocumentData(filePath);

    await _recentFilesService.addRecentFile(filePath);
    await _loadRecentFiles();

    final existingIndex = _tabs.indexWhere((tab) => tab.filePath == filePath);
    if (existingIndex != -1) {
      final customTitle = existingData?.customTitle ?? '';
      if (customTitle.isNotEmpty) {
        setState(() {
          _tabs[existingIndex].customTitle = customTitle;
        });
      }
      if (_currentTabIndex != existingIndex) {
        setState(() {
          _currentTabIndex = existingIndex;
        });
      }
      return;
    }

    final newTab = PdfTab(
      id: '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
      filePath: filePath,
    );
    newTab.fileIdentifier = fileIdentifier;
    if (existingData?.customTitle != null &&
        existingData!.customTitle!.isNotEmpty) {
      newTab.customTitle = existingData.customTitle!;
    }

    newTab.scrollController.addListener(_onScroll);

    setState(() {
      _tabs.add(newTab);
      _currentTabIndex = _tabs.length - 1;
      _isTabBarExpanded = false;
    });

    _loadAndRenderPdf(newTab);
    _loadDocumentGroups(newTab);

    if (_isProjectMode && _currentProject != null) {
      _currentProject!.addDocument(filePath);
      await _projectService.updateProject(_currentProject!);
    }
  }

  Future<void> _loadAndRenderPdf(PdfTab tab) async {
    tab.renderGeneration += 1;
    final generation = tab.renderGeneration;

    setState(() {
      tab.isLoading = true;
      tab.loadingProgress = 0.0;
      tab.loadingMessage = 'Opening document...';
      _disposeTabImages(tab);
      tab.renderedPages = [];
      tab.thumbnails = [];
      tab.pageSizes = [];
      tab.pageOffsets = [];
      tab.globalRotationAngle = 0.0;
      tab.pageRotations = [];
      tab.pageRenderScales = [];
      tab.pendingPageRenders.clear();
      tab.pendingThumbnailRenders.clear();
    });

    try {
      tab.document?.dispose();
      tab.document = null;

      final document = await _pdfEngine.openDocument(tab.filePath);
      if (generation != tab.renderGeneration) {
        document.dispose();
        return;
      }

      tab.document = document;
      final pagesCount = document.pageCount;
      final newPageSizes = List<Size>.filled(pagesCount, Size.zero);

      try {
        tab.documentTitle = tab.filePath.split(Platform.pathSeparator).last;
        final docTitle = document.title;
        if (docTitle != null && docTitle.trim().isNotEmpty) {
          tab.documentTitle = docTitle;
        }

        final file = File(tab.filePath);
        final fileStat = await file.stat();
        String? pdfVersion;
        try {
          final bytes = await file.openRead(0, 20).first;
          final header = String.fromCharCodes(bytes);
          final match = RegExp(r'%PDF-(\d+\.\d+)').firstMatch(header);
          if (match != null) {
            pdfVersion = match.group(1);
          }
        } catch (_) {}

        tab.metadata = PdfMetadata(
          fileSize: fileStat.size,
          lastModified: fileStat.modified,
          lastAccessed: fileStat.accessed,
          pdfVersion: pdfVersion,
        );
      } catch (e) {
        debugPrint('Metadata error: $e');
      }

      for (int i = 0; i < pagesCount; i++) {
        if (mounted) {
          setState(() {
            tab.loadingProgress = (i + 1) / pagesCount;
            tab.loadingMessage = 'Reading page ${i + 1} of $pagesCount';
          });
        }

        newPageSizes[i] = document.getPageSize(i);
      }

      await _documentStateService.saveDocumentDetails(
        tab.filePath,
        customTitle: tab.customTitle.isNotEmpty ? tab.customTitle : null,
        totalPages: pagesCount,
        pageSize: newPageSizes.isNotEmpty ? newPageSizes.first : null,
        metadata: tab.metadata,
      );
      if (mounted) {
        final pageSize = newPageSizes.isNotEmpty ? newPageSizes.first : null;
        setState(() {
          final existing = _recentFilesData[tab.filePath];
          if (existing != null) {
            _recentFilesData[tab.filePath] = existing.copyWith(
              customTitle: tab.customTitle.isNotEmpty ? tab.customTitle : null,
              totalPages: pagesCount,
              pageWidth: pageSize?.width,
              pageHeight: pageSize?.height,
              metadata: tab.metadata,
            );
          } else if (tab.fileIdentifier != null) {
            _recentFilesData[tab.filePath] = DocumentData(
              fileIdentifier: tab.fileIdentifier!,
              customTitle: tab.customTitle.isNotEmpty ? tab.customTitle : null,
              totalPages: pagesCount,
              pageWidth: pageSize?.width,
              pageHeight: pageSize?.height,
              metadata: tab.metadata,
              state: _recentFilesState[tab.filePath],
              lastOpened: DateTime.now(),
            );
          }
        });
      }

      if (!mounted || generation != tab.renderGeneration) {
        if (tab.document == document) {
          tab.document = null;
        }
        document.dispose();
        return;
      }

      if (mounted) {
        final savedState = await _documentStateService.getDocumentState(
          tab.filePath,
        );
        final restoredPage = savedState?.currentPage ?? 1;
        final restoredScale = savedState?.scale ?? 1.0;

        setState(() {
          tab.totalPages = pagesCount;
          tab.renderedPages = List<ui.Image?>.filled(pagesCount, null);
          tab.thumbnails = List<ui.Image?>.filled(pagesCount, null);
          tab.pageSizes = newPageSizes;
          tab.pageRotations = List<double>.filled(pagesCount, 0.0);
          tab.pageRenderScales = List<double>.filled(pagesCount, 0.0);
          _calculatePageOffsets(tab);
          tab.isLoading = false;
          tab.scale = restoredScale.clamp(_minScale, _maxScale);
          _animatedScale = tab.scale;
          tab.currentPage = restoredPage.clamp(1, pagesCount);
        });

        if (restoredPage > 1 && restoredPage <= pagesCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (tab.pageOffsets.isNotEmpty && tab.scrollController.hasClients) {
              final targetOffset =
                  tab.pageOffsets[restoredPage - 1] * tab.scale;
              tab.scrollController.jumpTo(targetOffset);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        if (e is GelideEngineUnavailableException) {
          await _showPdfEngineUnavailableDialog(e);
        } else {
          final l10n = AppLocalizations.of(context);
          _showErrorToast(
            l10n?.failedToOpenDocument ?? 'Failed to open document',
            e.toString(),
          );
        }
      }
      _removeFailedTab(tab);
    }
  }

  void _disposeTabImages(PdfTab tab) {
    for (final image in tab.renderedPages) {
      image?.dispose();
    }
    for (final image in tab.thumbnails) {
      image?.dispose();
    }
  }

  void _calculatePageOffsets(PdfTab tab) {
    if (tab.pageSizes.isEmpty) {
      return;
    }
    final offsets = <double>[];
    double cumulativeHeight = 0;
    for (int i = 0; i < tab.totalPages; i++) {
      offsets.add(cumulativeHeight);

      final pageAngle =
          tab.globalRotationAngle +
          (i < tab.pageRotations.length ? tab.pageRotations[i] : 0.0);
      final normalizedAngle = ((pageAngle % 360) + 360) % 360;
      final quarterTurns = (normalizedAngle ~/ 90) % 4;
      final isSwapped = quarterTurns == 1 || quarterTurns == 3;

      final actualHeight = isSwapped
          ? tab.pageSizes[i].width
          : tab.pageSizes[i].height;

      cumulativeHeight += actualHeight + _pageSpacing;
    }
    tab.pageOffsets = offsets;

    if (tab == _activeTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    }
  }

  double _targetRenderScaleFor(double scale) {
    return (scale * 1.5).clamp(1.0, 6.0).toDouble();
  }

  Future<void> _ensurePageRendered(
    PdfTab tab,
    int pageIndex,
    double renderScale,
  ) async {
    if (pageIndex < 0 || pageIndex >= tab.totalPages) return;
    final document = tab.document;
    if (document == null) return;

    final currentScale = tab.pageRenderScales[pageIndex];
    if (currentScale >= renderScale && tab.renderedPages[pageIndex] != null) {
      _touchRenderedPage(tab, pageIndex);
      return;
    }

    if (tab.pendingPageRenders.contains(pageIndex)) return;
    tab.pendingPageRenders.add(pageIndex);

    final generation = tab.renderGeneration;
    try {
      final image = await document.renderPage(
        pageIndex,
        renderScale: renderScale,
      );

      if (!mounted || generation != tab.renderGeneration) {
        image.dispose();
        return;
      }
      if (tab.pageRenderScales[pageIndex] > renderScale) {
        image.dispose();
        return;
      }

      final oldImage = tab.renderedPages[pageIndex];
      oldImage?.dispose();

      setState(() {
        tab.renderedPages[pageIndex] = image;
        tab.pageRenderScales[pageIndex] = renderScale;
      });
      _touchRenderedPage(tab, pageIndex);
      _enforceRenderedPageLimit(tab);
    } catch (e) {
      debugPrint('Render page error: $e');
    } finally {
      tab.pendingPageRenders.remove(pageIndex);
    }
  }

  void _touchRenderedPage(PdfTab tab, int pageIndex) {
    tab.renderedPageOrder.remove(pageIndex);
    tab.renderedPageOrder.add(pageIndex);
  }

  int _maxRenderedPagesForScale(double scale) {
    if (scale <= 0) return _maxRenderedPages;
    final scaled = (_maxRenderedPages / scale).round();
    return max(_maxRenderedPages, scaled);
  }

  void _enforceRenderedPageLimit(PdfTab tab, {int? minKeep}) {
    final maxAllowed = max(_maxRenderedPagesForScale(tab.scale), minKeep ?? 0);
    while (tab.renderedPageOrder.length > maxAllowed) {
      final oldest = tab.renderedPageOrder.first;
      tab.renderedPageOrder.remove(oldest);
      if (oldest >= 0 && oldest < tab.renderedPages.length) {
        final image = tab.renderedPages[oldest];
        if (image != null) {
          image.dispose();
          tab.renderedPages[oldest] = null;
          tab.pageRenderScales[oldest] = 0.0;
        }
      }
    }
  }

  Future<void> _ensureThumbnailRendered(
    PdfTab tab,
    int pageIndex,
    int width,
    int height,
  ) async {
    if (pageIndex < 0 || pageIndex >= tab.totalPages) return;
    final document = tab.document;
    if (document == null) return;

    if (tab.thumbnails[pageIndex] != null) return;
    if (tab.pendingThumbnailRenders.contains(pageIndex)) return;

    tab.pendingThumbnailRenders.add(pageIndex);
    final generation = tab.renderGeneration;

    try {
      final image = await document.renderPageSized(pageIndex, width, height);
      if (!mounted || generation != tab.renderGeneration) {
        image.dispose();
        return;
      }

      setState(() {
        tab.thumbnails[pageIndex] = image;
      });

      _trimThumbnailCache(tab);
    } catch (e) {
      debugPrint('Thumbnail render error: $e');
    } finally {
      tab.pendingThumbnailRenders.remove(pageIndex);
    }
  }

  ({int start, int end}) _visiblePageRange(PdfTab tab) {
    final total = tab.totalPages;
    if (total <= 0 || tab.pageOffsets.isEmpty) {
      final current = (tab.currentPage - 1).clamp(0, max(0, total - 1)).toInt();
      return (start: current, end: current);
    }
    if (!tab.scrollController.hasClients) {
      final current = (tab.currentPage - 1).clamp(0, total - 1).toInt();
      return (start: current, end: current);
    }

    final viewportTop = tab.scrollController.offset;
    final viewportBottom =
        viewportTop + tab.scrollController.position.viewportDimension;
    final scaledPadding = _pageSpacing * tab.scale;

    int? start;
    int? end;

    for (int i = 0; i < total; i++) {
      final pageTop = tab.pageOffsets[i] * tab.scale + scaledPadding;
      final pageBottom = pageTop + tab.pageSizes[i].height * tab.scale;

      if (start == null && pageBottom >= viewportTop) {
        start = i;
      }
      if (pageTop <= viewportBottom) {
        end = i;
      }
      if (pageTop > viewportBottom && end != null) {
        break;
      }
    }

    final fallback = (tab.currentPage - 1).clamp(0, total - 1).toInt();
    return (
      start: (start ?? fallback).toInt(),
      end: (end ?? (start ?? fallback)).toInt(),
    );
  }

  void _trimThumbnailCache(PdfTab tab) {
    if (tab.thumbnails.length <= _thumbnailCacheLimit) return;

    final imagesToDispose = <ui.Image>[];
    for (int i = 0; i < tab.thumbnails.length; i++) {
      if (tab.thumbnails.length - imagesToDispose.length <=
          _thumbnailCacheLimit) {
        break;
      }
      final image = tab.thumbnails[i];
      if (image != null) {
        imagesToDispose.add(image);
        tab.thumbnails[i] = null;
      }
    }

    for (final image in imagesToDispose) {
      image.dispose();
    }
  }

  Future<void> _rerenderPagesIfNeeded(PdfTab tab, double targetScale) async {
    if (tab.isRerendering) return;

    final document = tab.document;
    if (document == null) return;

    final shouldUseTiles =
        document.supportsTileRendering && targetScale >= _tileScaleThreshold;
    if (shouldUseTiles) {
      setState(() {
        tab.isRerendering = true;
      });

      try {
        final range = _visiblePageRange(tab);
        final keepStart = (range.start - _visibleCacheBuffer)
            .clamp(0, tab.totalPages - 1)
            .toInt();
        final keepEnd = (range.end + _visibleCacheBuffer)
            .clamp(0, tab.totalPages - 1)
            .toInt();

        for (int i = keepStart; i <= keepEnd; i++) {
          _ensurePageRendered(tab, i, _tileFallbackRenderScale);
          _touchRenderedPage(tab, i);
        }

        _enforceRenderedPageLimit(tab, minKeep: keepEnd - keepStart + 1);
      } catch (e) {
        debugPrint('Rerender error: $e');
      } finally {
        if (mounted) {
          setState(() {
            tab.isRerendering = false;
          });
        }
      }
      return;
    }

    final targetRenderScale = _targetRenderScaleFor(targetScale);
    final previewRenderScale = min(targetRenderScale, _previewRenderScaleCap);
    final usePreview =
        targetScale >= _previewMinScale &&
        previewRenderScale < targetRenderScale;

    setState(() {
      tab.isRerendering = true;
    });

    try {
      final range = _visiblePageRange(tab);
      final keepStart = (range.start - _visibleCacheBuffer)
          .clamp(0, tab.totalPages - 1)
          .toInt();
      final keepEnd = (range.end + _visibleCacheBuffer)
          .clamp(0, tab.totalPages - 1)
          .toInt();

      final pages = <int>[];
      for (int i = keepStart; i <= keepEnd; i++) {
        pages.add(i);
      }
      pages.sort((a, b) {
        final distA = a < range.start
            ? range.start - a
            : (a > range.end ? a - range.end : 0);
        final distB = b < range.start
            ? range.start - b
            : (b > range.end ? b - range.end : 0);
        return distA.compareTo(distB);
      });

      for (final pageIndex in pages) {
        final inVisible = pageIndex >= range.start && pageIndex <= range.end;
        if (usePreview && !inVisible) {
          unawaited(_ensurePageRendered(tab, pageIndex, previewRenderScale));
        } else {
          unawaited(_ensurePageRendered(tab, pageIndex, targetRenderScale));
        }
        _touchRenderedPage(tab, pageIndex);
      }

      _enforceRenderedPageLimit(tab, minKeep: keepEnd - keepStart + 1);
    } catch (e) {
      debugPrint('Rerender error: $e');
    } finally {
      if (mounted) {
        setState(() {
          tab.isRerendering = false;
        });
      }
    }
  }

  void _scheduleRerender(PdfTab tab, double targetScale) {
    _pendingRerenderScales[tab.id] = targetScale;
    _rerenderTimers[tab.id]?.cancel();
    _rerenderTimers[tab.id] = Timer(_rerenderDebounce, () {
      final scale = _pendingRerenderScales.remove(tab.id);
      _rerenderTimers.remove(tab.id);
      if (scale == null) return;
      _rerenderPagesIfNeeded(tab, scale);
    });
  }

  void _scheduleScalePrefetch(PdfTab tab, double targetScale) {
    _scalePrefetchTimers[tab.id]?.cancel();
    _scalePrefetchTimers[tab.id] = Timer(const Duration(milliseconds: 80), () {
      _scalePrefetchTimers.remove(tab.id);
      if (!mounted) return;
      final document = tab.document;
      if (document == null || tab.totalPages <= 0) return;

      final range = _visiblePageRange(tab);
      final visibleCount = max(1, range.end - range.start + 1);
      final bufferPages = visibleCount * _prefetchScreensAfterScale;
      final keepStart = (range.start - bufferPages)
          .clamp(0, tab.totalPages - 1)
          .toInt();
      final keepEnd = (range.end + bufferPages)
          .clamp(0, tab.totalPages - 1)
          .toInt();

      final shouldUseTiles =
          document.supportsTileRendering && targetScale >= _tileScaleThreshold;
      final targetRenderScale = shouldUseTiles
          ? _tileFallbackRenderScale
          : _targetRenderScaleFor(targetScale);
      final previewRenderScale = min(targetRenderScale, _previewRenderScaleCap);
      final usePreview =
          !shouldUseTiles &&
          targetScale >= _previewMinScale &&
          previewRenderScale < targetRenderScale;

      for (int i = keepStart; i <= keepEnd; i++) {
        final inVisible = i >= range.start && i <= range.end;
        if (usePreview && !inVisible) {
          unawaited(_ensurePageRendered(tab, i, previewRenderScale));
        } else {
          unawaited(_ensurePageRendered(tab, i, targetRenderScale));
        }
        _touchRenderedPage(tab, i);
      }

      _enforceRenderedPageLimit(tab, minKeep: keepEnd - keepStart + 1);
    });
  }

  void _setScale(double newScale) {
    final tab = _activeTab;
    if (tab == null) return;

    if (!_zoomAnimationEnabled) {
      setState(() {
        tab.scale = newScale.clamp(_minScale, _maxScale);
        _animatedScale = tab.scale;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
      _saveCurrentState(tab);
      _scheduleRerender(tab, tab.scale);
      _scheduleScalePrefetch(tab, tab.scale);
      return;
    }

    final targetScale = newScale.clamp(_minScale, _maxScale);
    final startScale = _animatedScale;

    _zoomAnimationController?.dispose();

    _zoomAnimationController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );

    _zoomAnimation = Tween<double>(begin: startScale, end: targetScale).animate(
      CurvedAnimation(
        parent: _zoomAnimationController!,
        curve: Curves.easeOutCubic,
      ),
    );

    _zoomAnimation!.addListener(() {
      if (mounted) {
        setState(() {
          _animatedScale = _zoomAnimation!.value;
          tab.scale = _animatedScale;
        });
      }
    });

    _zoomAnimationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
        _saveCurrentState(tab);
        _scheduleRerender(tab, tab.scale);
        _scheduleScalePrefetch(tab, tab.scale);
      }
    });

    _zoomAnimationController!.forward();
  }

  void _setScaleForTab(PdfTab tab, double newScale) {
    if (tab == _activeTab) {
      _setScale(newScale);
      return;
    }

    final clamped = newScale.clamp(_minScale, _maxScale);
    setState(() {
      tab.scale = clamped;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll(tab));
    _saveCurrentState(tab);
    _scheduleRerender(tab, tab.scale);
    _scheduleScalePrefetch(tab, tab.scale);
  }

  void _rotatePage(PdfTab tab, double angle) {
    if (tab.rotateAllPagesMode) {
      setState(() {
        tab.globalRotationAngle = (tab.globalRotationAngle + angle) % 360;
        if (tab.globalRotationAngle < 0) tab.globalRotationAngle += 360;
      });
      _calculatePageOffsets(tab);
    } else {
      if (tab.currentPage > 0 && tab.currentPage <= tab.pageRotations.length) {
        setState(() {
          tab.pageRotations[tab.currentPage - 1] =
              (tab.pageRotations[tab.currentPage - 1] + angle) % 360;
          if (tab.pageRotations[tab.currentPage - 1] < 0) {
            tab.pageRotations[tab.currentPage - 1] += 360;
          }
        });
        _calculatePageOffsets(tab);
      }
    }
  }

  bool _isPointerOnRotationButton(Offset position) {
    final keys = <GlobalKey>[
      _rotateButtonKey,
      _leftRotateButtonKey,
      _rightRotateButtonKey,
    ];
    for (final key in keys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(position)) {
        return true;
      }
    }
    return false;
  }

  void _toggleRotationMenu(
    BuildContext context,
    GlobalKey buttonKey,
    PdfTab tab,
  ) {
    final existing = _rotationMenuOverlays[tab.id];
    if (existing != null) {
      _closeRotationMenu(tab.id);
      return;
    }
    _showRotationMenu(context, buttonKey, tab);
  }

  void _closeRotationMenu(String tabId) {
    final overlay = _rotationMenuOverlays.remove(tabId);
    overlay?.remove();
  }

  void _showRotationMenu(
    BuildContext context,
    GlobalKey buttonKey,
    PdfTab tab,
  ) {
    final RenderBox? buttonBox =
        buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (buttonBox == null) return;

    final buttonPosition = buttonBox.localToGlobal(Offset.zero);
    final buttonSize = buttonBox.size;

    final overlayEntry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: Listener(
              onPointerDown: (event) {
                if (_isPointerOnRotationButton(event.position)) {
                  return;
                }
                _closeRotationMenu(tab.id);
              },
              behavior: HitTestBehavior.translucent,
            ),
          ),
          Positioned(
            left: buttonPosition.dx - 120,
            top: buttonPosition.dy + buttonSize.height + 4,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              color: Theme.of(context).cardColor,
              child: StatefulBuilder(
                builder: (ctx, setMenuState) {
                  final l10n = AppLocalizations.of(ctx)!;
                  return SizedBox(
                    width: 220,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            l10n.rotationOptions,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        _buildRotationMenuItem(
                          icon: Icons.rotate_right,
                          label: l10n.rotateRight,
                          onTap: () {
                            _rotatePage(tab, 90);
                            setMenuState(() {});
                          },
                        ),
                        _buildRotationMenuItem(
                          icon: Icons.rotate_left,
                          label: l10n.rotateLeft,
                          onTap: () {
                            _rotatePage(tab, -90);
                            setMenuState(() {});
                          },
                        ),
                        _buildRotationMenuItem(
                          icon: Icons.sync,
                          label: l10n.rotate180,
                          onTap: () {
                            _rotatePage(tab, 180);
                            setMenuState(() {});
                          },
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            l10n.mode,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        _buildRotationModeItem(
                          icon: Icons.note,
                          label: l10n.currentPage,
                          isSelected: !tab.rotateAllPagesMode,
                          onTap: () {
                            setState(() {
                              tab.rotateAllPagesMode = false;
                            });
                            setMenuState(() {});
                          },
                        ),
                        _buildRotationModeItem(
                          icon: Icons.photo_library_outlined,
                          label: l10n.allPagesMode,
                          isSelected: tab.rotateAllPagesMode,
                          onTap: () {
                            setState(() {
                              tab.rotateAllPagesMode = true;
                            });
                            setMenuState(() {});
                          },
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );

    _rotationMenuOverlays[tab.id]?.remove();
    _rotationMenuOverlays[tab.id] = overlayEntry;

    Overlay.of(context).insert(overlayEntry);
  }

  Widget _buildRotationMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Theme.of(context).primaryColor.withValues(alpha: 0.08);
    final splashColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Theme.of(context).primaryColor.withValues(alpha: 0.12);
    return InkWell(
      onTap: onTap,
      hoverColor: hoverColor,
      highlightColor: splashColor,
      splashColor: splashColor,
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildRotationModeItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Theme.of(context).primaryColor.withValues(alpha: 0.08);
    final splashColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Theme.of(context).primaryColor.withValues(alpha: 0.12);
    return InkWell(
      onTap: onTap,
      hoverColor: hoverColor,
      highlightColor: splashColor,
      splashColor: splashColor,
      borderRadius: BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected ? AppColors.primaryBlue : Colors.grey,
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomMenuItem(String label, bool isSelected) {
    return Row(
      children: [
        if (isSelected)
          Icon(Icons.check_rounded, size: 18, color: AppColors.primaryBlue)
        else
          const SizedBox(width: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.primaryBlue : null,
          ),
        ),
      ],
    );
  }

  void _goToPage(int pageNumber, [PdfTab? targetTab]) {
    final tab = targetTab ?? _activeTab;
    if (tab == null ||
        pageNumber < 1 ||
        pageNumber > tab.totalPages ||
        tab.pageOffsets.isEmpty) {
      return;
    }

    final targetOffset = tab.pageOffsets[pageNumber - 1] * tab.scale;
    tab.scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _fitToPage([PdfTab? targetTab]) async {
    final tab = targetTab ?? _activeTab;
    if (tab == null || tab.pageSizes.isEmpty || !mounted) {
      return;
    }

    final splitTab = _splitTab;
    final isSplitActive = splitTab != null && splitTab.renderedPages.isNotEmpty;
    final screenSize = MediaQuery.of(context).size;
    final availableWidth = isSplitActive
        ? (screenSize.width - 1) / 2
        : screenSize.width;
    final viewSize = Size(
      availableWidth - (_pageSpacing * 2),
      screenSize.height -
          kToolbarHeight -
          MediaQuery.of(context).padding.top -
          (_pageSpacing * 2),
    );
    final firstPageSize = tab.pageSizes.first;
    final scaleW = viewSize.width / firstPageSize.width;
    final scaleH = viewSize.height / firstPageSize.height;
    _setScaleForTab(tab, min(scaleW, scaleH));
  }

  Future<void> _showCustomZoomDialog([PdfTab? targetTab]) async {
    final tab = targetTab ?? _activeTab;
    if (tab == null) return;

    final newScalePercent = await showDialog<String>(
      context: context,
      builder: (context) => CustomZoomDialog(currentScale: tab.scale),
    );

    if (newScalePercent != null && newScalePercent.isNotEmpty) {
      final percent = double.tryParse(newScalePercent);
      if (percent != null) {
        final clampedPercent = percent.clamp(40.0, 400.0);
        _setScaleForTab(tab, clampedPercent / 100.0);
      }
    }
  }

  void _showSettingsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
    _loadSettings();
  }

  void _applyTabRename(PdfTab tab, String newName) {
    setState(() {
      tab.customTitle = newName;
    });
    _documentStateService.saveDocumentDetails(
      tab.filePath,
      customTitle: newName,
    );
    _loadRecentFiles();
    if (_isProjectMode && _currentProject != null) {
      _currentProject!.updateDocumentName(tab.filePath, newName);
      _projectService.updateProject(_currentProject!);
    }
  }

  void _beginSplitRename(PdfTab tab) {
    setState(() {
      _editingSplitTabId = tab.id;
      _splitRenameController.text = _getTabDisplayName(tab);
    });
  }

  void _commitSplitRename(PdfTab tab) {
    if (_editingSplitTabId != tab.id) return;
    final newName = _splitRenameController.text.trim();
    setState(() {
      _editingSplitTabId = null;
    });
    if (newName.isEmpty) return;
    _applyTabRename(tab, newName);
  }

  void _openNavigationDrawer(
    BuildContext ctx,
    PdfTab tab, {
    required bool isEndDrawer,
  }) {
    if (isEndDrawer) {
      Scaffold.of(ctx).openEndDrawer();
    } else {
      Scaffold.of(ctx).openDrawer();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = tab.navigationScrollController;
      if (controller.hasClients) {
        final max = controller.position.maxScrollExtent;
        final target = tab.navigationScrollOffset.clamp(0.0, max);
        controller.jumpTo(target);
      }
    });
  }

  void _openNavigationDrawerAsDialog(PdfTab tab) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Navigation',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim, secondAnim) {
        final toolbarHeight =
            Theme.of(ctx).appBarTheme.toolbarHeight ?? kToolbarHeight;
        const titleBarHeight = 32.0;
        final screenHeight = MediaQuery.of(ctx).size.height;
        final topOffset = titleBarHeight + toolbarHeight;
        final drawerHeight = (screenHeight - topOffset).clamp(
          0.0,
          screenHeight,
        );

        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.only(top: topOffset),
            child: SizedBox(
              width: 304,
              height: drawerHeight,
              child: Material(
                elevation: 16,
                child: _buildNavigationDrawer(tab),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondAnim, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }

  Widget _buildNavigationDrawer(PdfTab tab) {
    return PdfNavigationDrawer(
      totalPages: tab.totalPages,
      currentPage: tab.currentPage,
      thumbnails: tab.thumbnails,
      pageSizes: tab.pageSizes,
      onPageSelected: (pageNumber) => _goToPage(pageNumber, tab),
      onRequestThumbnail: (pageIndex, width, height) =>
          _ensureThumbnailRendered(tab, pageIndex, width, height),
      visibilityKeyPrefix: tab.id,
      groups: _documentGroups[tab.filePath]?.groups ?? [],
      activeGroupId: _documentGroups[tab.filePath]?.activeGroupId,
      onCreateGroup: () => _createGroup(tab),
      onEditGroup: (group) => _editGroup(group, tab),
      onDeleteGroup: (groupId) => _deleteGroup(groupId, tab),
      onSelectGroup: (groupId) => _selectGroup(groupId, tab),
      pageListController: tab.navigationScrollController,
      initialScrollOffset: tab.navigationScrollOffset,
    );
  }

  void _closeTab(int index) {
    if (index < 0 || index >= _tabs.length) return;

    final tab = _tabs[index];

    _saveCurrentState(tab);

    if (_isProjectMode && _currentProject != null) {
      _currentProject!.removeDocument(tab.filePath);
      _projectService.updateProject(_currentProject!);
    }

    tab.dispose();

    _rerenderTimers.remove(tab.id)?.cancel();
    _pendingRerenderScales.remove(tab.id);
    _scalePrefetchTimers.remove(tab.id)?.cancel();

    setState(() {
      _tabs.removeAt(index);
      if (_currentTabIndex >= _tabs.length) {
        _currentTabIndex = _tabs.length - 1;
      }
      _isTabBarExpanded = false;
    });
  }

  void _removeFailedTab(PdfTab tab) {
    final index = _tabs.indexOf(tab);
    if (index == -1) return;

    tab.dispose();
    _rerenderTimers.remove(tab.id)?.cancel();
    _pendingRerenderScales.remove(tab.id);
    _scalePrefetchTimers.remove(tab.id)?.cancel();

    setState(() {
      _tabs.removeAt(index);
      if (_currentTabIndex == index) {
        _currentTabIndex = _tabs.isEmpty ? -1 : max(0, index - 1);
      } else if (_currentTabIndex > index) {
        _currentTabIndex--;
      }
      _isTabBarExpanded = false;
    });
  }

  void _onReorderTabs(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final PdfTab item = _tabs.removeAt(oldIndex);
      _tabs.insert(newIndex, item);

      if (_currentTabIndex == oldIndex) {
        _currentTabIndex = newIndex;
      } else if (_currentTabIndex > oldIndex && _currentTabIndex <= newIndex) {
        _currentTabIndex--;
      } else if (_currentTabIndex < oldIndex && _currentTabIndex >= newIndex) {
        _currentTabIndex++;
      }
    });

    if (_isProjectMode && _currentProject != null) {
      _saveProjectState();
    }
  }

  Future<void> _loadDocumentGroups(PdfTab tab) async {
    if (tab.fileIdentifier == null) return;

    final groups = await _pageGroupService.getDocumentGroupsByIdentifier(
      tab.fileIdentifier!,
    );
    if (mounted) {
      setState(() {
        _documentGroups[tab.filePath] =
            groups ?? DocumentGroups(filePath: tab.filePath);
      });
    }
  }

  Future<void> _createGroup([PdfTab? targetTab]) async {
    final tab = targetTab ?? _activeTab;
    if (tab == null || tab.fileIdentifier == null) return;

    final result = await showDialog<PageGroup>(
      context: context,
      builder: (context) => GroupEditDialog(totalPages: tab.totalPages),
    );

    if (result != null) {
      var docGroups = _documentGroups[tab.filePath];
      docGroups ??= DocumentGroups(filePath: tab.filePath);

      docGroups.addGroup(result);
      await _pageGroupService.saveDocumentGroupsByIdentifier(
        tab.fileIdentifier!,
        docGroups,
      );

      if (mounted) {
        setState(() {
          _documentGroups[tab.filePath] = docGroups!;
        });
      }
    }
  }

  Future<void> _editGroup(PageGroup group, [PdfTab? targetTab]) async {
    final tab = targetTab ?? _activeTab;
    if (tab == null || tab.fileIdentifier == null) return;

    final result = await showDialog<PageGroup>(
      context: context,
      builder: (context) =>
          GroupEditDialog(existingGroup: group, totalPages: tab.totalPages),
    );

    if (result != null) {
      await _pageGroupService.updateGroup(tab.fileIdentifier!, result);
      await _loadDocumentGroups(tab);
    }
  }

  Future<void> _deleteGroup(String groupId, [PdfTab? targetTab]) async {
    final tab = targetTab ?? _activeTab;
    if (tab == null || tab.fileIdentifier == null) return;

    await _pageGroupService.deleteGroup(tab.fileIdentifier!, groupId);
    await _loadDocumentGroups(tab);
  }

  Future<void> _selectGroup(String? groupId, [PdfTab? targetTab]) async {
    final tab = targetTab ?? _activeTab;
    if (tab == null || tab.fileIdentifier == null) return;

    var docGroups = _documentGroups[tab.filePath];
    if (docGroups == null) {
      docGroups = DocumentGroups(filePath: tab.filePath);
    }

    docGroups.activeGroupId = groupId;
    await _pageGroupService.saveDocumentGroupsByIdentifier(
      tab.fileIdentifier!,
      docGroups,
    );

    if (mounted) {
      setState(() {
        _documentGroups[tab.filePath] = docGroups!;
      });

      if (groupId != null) {
        final activeGroup = docGroups.activeGroup;
        if (activeGroup != null && activeGroup.pages.isNotEmpty) {
          _goToPage(activeGroup.pageNumbers.first, tab);
        }
      }
    }
  }

  @override
  void dispose() {
    _zoomAnimationController?.dispose();
    _recentRenameController.dispose();
    _splitRenameController.dispose();
    for (final overlay in _rotationMenuOverlays.values) {
      overlay.remove();
    }
    _rotationMenuOverlays.clear();
    for (var tab in _tabs) {
      tab.dispose();
    }
    for (final timer in _rerenderTimers.values) {
      timer.cancel();
    }
    for (final timer in _scalePrefetchTimers.values) {
      timer.cancel();
    }
    _pdfEngine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = _activeTab;
    final splitTab = _splitTab;
    final l10n = AppLocalizations.of(context)!;
    final bool isSplitActive =
        splitTab != null && splitTab.renderedPages.isNotEmpty;
    final bool isPdfLoaded =
        tab != null &&
        !tab.isLoading &&
        tab.document != null &&
        tab.renderedPages.isNotEmpty;

    return Column(
      children: [
        CustomTitleBar(
          projectName: _currentProject?.name,
          centerTitle: isSplitActive ? l10n.splitView : null,
          onCenterTitleTap: isSplitActive
              ? (globalPosition) =>
                    _showSplitViewMenu(globalPosition, tab!, splitTab)
              : null,
        ),

        Expanded(
          child: Builder(
            builder: (context) {
              final appBarActions = <Widget>[];
              if (isPdfLoaded && !isSplitActive) {
                final activeTab = tab;
                appBarActions.addAll([
                  IconButton(
                    key: _rotateButtonKey,
                    icon: Icon(
                      activeTab.rotateAllPagesMode
                          ? Icons.rotate_90_degrees_ccw
                          : Icons.rotate_right,
                    ),
                    tooltip: l10n.rotationOptions,
                    onPressed: () => _toggleRotationMenu(
                      context,
                      _rotateButtonKey,
                      activeTab,
                    ),
                  ),
                  _buildZoomMenuButton(
                    tab: activeTab,
                    onSelected: (value) {
                      if (value is double) {
                        _setScale(value);
                      } else if (value == 'fit_page') {
                        _fitToPage();
                      } else if (value == 'custom') {
                        _showCustomZoomDialog();
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                ]);
              } else if (tab == null) {
                appBarActions.add(
                  IconButton(
                    icon: const Icon(Icons.settings_rounded),
                    tooltip: l10n.settings,
                    onPressed: _showSettingsDialog,
                  ),
                );
              }
              if (appBarActions.isNotEmpty) {
                appBarActions.add(const SizedBox(width: 8));
              }
              final effectiveActions = isSplitActive
                  ? const <Widget>[]
                  : (appBarActions.isEmpty ? null : appBarActions);

              return Scaffold(
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  leading: isPdfLoaded && !isSplitActive
                      ? Builder(
                          builder: (ctx) => IconButton(
                            icon: const Icon(Icons.menu),
                            tooltip: l10n.pageNavigation,
                            onPressed: () => _openNavigationDrawer(
                              ctx,
                              tab,
                              isEndDrawer: false,
                            ),
                          ),
                        )
                      : null,
                  title: isPdfLoaded && isSplitActive
                      ? _buildSplitAppBarContent(
                          leftTab: tab,
                          rightTab: splitTab,
                        )
                      : null,
                  titleSpacing: isPdfLoaded && isSplitActive ? 0 : null,
                  elevation: isPdfLoaded ? null : 0,
                  backgroundColor: isPdfLoaded
                      ? null
                      : Theme.of(context).scaffoldBackgroundColor,
                  actions: effectiveActions,
                ),
                drawer: isPdfLoaded ? _buildNavigationDrawer(tab) : null,
                endDrawer: null,
                body: DropTarget(
                  onDragDone: (details) {
                    setState(() {
                      _isDragging = false;
                    });
                    for (final file in details.files) {
                      final path = file.path;
                      if (path.toLowerCase().endsWith('.pdf')) {
                        _openFile(path);
                      }
                    }
                  },
                  onDragEntered: (details) {
                    setState(() {
                      _isDragging = true;
                    });
                  },
                  onDragExited: (details) {
                    setState(() {
                      _isDragging = false;
                    });
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DragTarget<int>(
                        onWillAcceptWithDetails: (details) {
                          if (details.data != _currentTabIndex &&
                              details.data >= 0 &&
                              details.data < _tabs.length &&
                              _splitTabIndex == null) {
                            setState(() {
                              _splitDropZoneActive = true;
                            });
                            return true;
                          }
                          return false;
                        },
                        onLeave: (_) {
                          setState(() {
                            _splitDropZoneActive = false;
                          });
                        },
                        onAcceptWithDetails: (details) {
                          setState(() {
                            _splitTabIndex = details.data;
                            _splitDropZoneActive = false;
                          });
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              buildBody(),
                              if (_splitDropZoneActive)
                                Positioned.fill(
                                  child: Container(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.1),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.15,
                                              ),
                                              blurRadius: 20,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.vertical_split_rounded,
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                              size: 28,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              l10n.splitView,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(
                                                  context,
                                                ).primaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_tabs.isNotEmpty &&
                                  !_isLoadingProject &&
                                  !isSplitActive &&
                                  (tab == null || !tab.isLoading))
                                Positioned.fill(
                                  child: PdfTabBar(
                                    tabs: _tabs,
                                    selectedIndex: _currentTabIndex,
                                    onTabSelected: (index) {
                                      setState(() {
                                        _currentTabIndex = index;
                                      });
                                    },
                                    onTabClosed: _closeTab,
                                    onReorder: _onReorderTabs,
                                    onNewTab: _openPdfFile,
                                    isExpanded: _isTabBarExpanded,
                                    onToggleExpand: () {
                                      setState(() {
                                        _isTabBarExpanded = !_isTabBarExpanded;
                                      });
                                    },
                                    onRenameTab: (index, newName) {
                                      _applyTabRename(_tabs[index], newName);
                                    },
                                    onShowInfo: (index) {
                                      final targetTab = _tabs[index];
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => DocumentInfoDialog(
                                          documentTitle:
                                              targetTab.documentTitle,
                                          filePath: targetTab.filePath,
                                          totalPages: targetTab.totalPages,
                                          pageSizes: targetTab.pageSizes,
                                          metadata: targetTab.metadata,
                                        ),
                                      );
                                    },
                                    isProjectMode: _isProjectMode,
                                    projectName: _currentProject?.name,
                                    onCloseProject: _closeProject,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),

                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !_isDragging,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            opacity: _isDragging ? 1 : 0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Theme.of(
                                      context,
                                    ).primaryColor.withValues(alpha: 0.16),
                                    Theme.of(context).scaffoldBackgroundColor
                                        .withValues(alpha: 0.92),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: AnimatedSlide(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  offset: _isDragging
                                      ? Offset.zero
                                      : const Offset(0, 0.03),
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    scale: _isDragging ? 1 : 0.97,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 28,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.primaryBlue
                                              .withValues(alpha: 0.55),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.12,
                                            ),
                                            blurRadius: 28,
                                            offset: const Offset(0, 18),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 72,
                                            height: 72,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryBlue
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Icon(
                                              Icons.file_download_outlined,
                                              size: 36,
                                              color: AppColors.primaryBlue,
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          Text(
                                            l10n.dropFileHere,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildBody() {
    final tab = _activeTab;
    final splitTab = _splitTab;

    if (_isLoadingProject) {
      return buildProjectLoadingIndicator();
    }

    if (tab == null) {
      return buildOpenFilePrompt();
    }

    if (tab.isLoading) {
      return buildLoadingIndicator(tab);
    }

    if (tab.renderedPages.isEmpty) {
      return buildOpenFilePrompt();
    }

    if (splitTab != null && splitTab.renderedPages.isNotEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Row(
        children: [
          Expanded(child: _buildSplitPanel(tab: tab)),
          _buildSplitDivider(isDark),
          Expanded(child: _buildSplitPanel(tab: splitTab)),
        ],
      );
    }

    return buildPdfViewer(tab);
  }

  Widget _buildSplitPanel({required PdfTab tab}) {
    return buildPdfViewer(tab);
  }

  Widget _buildSplitDivider(bool isDark) {
    final lineColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
    return Container(width: 1, color: lineColor);
  }

  void _showSplitViewMenu(
    Offset globalPosition,
    PdfTab leftTab,
    PdfTab rightTab,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final leftName = _getTabDisplayName(leftTab);
    final rightName = _getTabDisplayName(rightTab);

    final menuWidth = 260.0;
    final menuLeft = globalPosition.dx - menuWidth / 2;
    final menuTop = globalPosition.dy + 4;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Split View Menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (ctx, anim, secondAnim) {
        return Stack(
          children: [
            Positioned(
              left: menuLeft,
              top: menuTop,
              child: FadeTransition(
                opacity: anim,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(10),
                  color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                  shadowColor: Colors.black26,
                  child: SizedBox(
                    width: menuWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 4),
                        _SplitMenuItem(
                          icon: Icons.swap_horiz_rounded,
                          label: l10n.swapDocuments,
                          isDark: isDark,
                          onTap: () {
                            Navigator.of(ctx).pop();
                            setState(() {
                              final tmpIndex = _currentTabIndex;
                              _currentTabIndex = _splitTabIndex!;
                              _splitTabIndex = tmpIndex;
                            });
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Divider(
                            height: 1,
                            color: isDark
                                ? Colors.white12
                                : Colors.grey.shade200,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 14,
                            top: 2,
                            bottom: 4,
                          ),
                          child: Text(
                            l10n.openDocuments,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ),
                        _SplitDocumentItem(
                          name: leftName,
                          isDark: isDark,
                          onClose: () {
                            Navigator.of(ctx).pop();
                            _closeRotationMenu(leftTab.id);
                            setState(() {
                              _editingSplitTabId = null;
                              if (_splitTabIndex != null) {
                                _currentTabIndex = _splitTabIndex!;
                                _splitTabIndex = null;
                              }
                            });
                          },
                        ),
                        _SplitDocumentItem(
                          name: rightName,
                          isDark: isDark,
                          onClose: () {
                            Navigator.of(ctx).pop();
                            _closeRotationMenu(rightTab.id);
                            setState(() {
                              _editingSplitTabId = null;
                              _splitTabIndex = null;
                            });
                          },
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSplitAppBarContent({
    required PdfTab leftTab,
    required PdfTab rightTab,
  }) {
    return Row(
      children: [
        const SizedBox(width: 4),
        Expanded(child: _buildSplitToolbarGroup(tab: leftTab, isLeft: true)),
        const SizedBox(width: 12),
        Expanded(child: _buildSplitToolbarGroup(tab: rightTab, isLeft: false)),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildSplitToolbarGroup({required PdfTab tab, required bool isLeft}) {
    final l10n = AppLocalizations.of(context)!;
    final rotationKey = isLeft ? _leftRotateButtonKey : _rightRotateButtonKey;
    return Row(
      children: [
        Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, size: 20),
            tooltip: l10n.pageNavigation,
            visualDensity: VisualDensity.compact,
            onPressed: () {
              if (isLeft) {
                _openNavigationDrawer(ctx, tab, isEndDrawer: false);
              } else {
                _openNavigationDrawerAsDialog(tab);
              }
            },
          ),
        ),
        const SizedBox(width: 2),
        Expanded(child: _buildSplitTitle(tab)),
        const SizedBox(width: 4),
        IconButton(
          key: rotationKey,
          icon: Icon(
            tab.rotateAllPagesMode
                ? Icons.rotate_90_degrees_ccw
                : Icons.rotate_right,
            size: 20,
          ),
          visualDensity: VisualDensity.compact,
          tooltip: l10n.rotationOptions,
          onPressed: () => _toggleRotationMenu(context, rotationKey, tab),
        ),
        _buildZoomMenuButton(
          tab: tab,
          onSelected: (value) {
            if (value is double) {
              _setScaleForTab(tab, value);
            } else if (value == 'fit_page') {
              _fitToPage(tab);
            } else if (value == 'custom') {
              _showCustomZoomDialog(tab);
            }
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSplitTitle(PdfTab tab) {
    final isEditing = _editingSplitTabId == tab.id;
    final displayName = _getTabDisplayName(tab);

    if (isEditing) {
      return TextField(
        controller: _splitRenameController,
        autofocus: true,
        maxLines: 1,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onSubmitted: (_) => _commitSplitRename(tab),
        onTapOutside: (_) => _commitSplitRename(tab),
      );
    }

    return InkWell(
      onDoubleTap: () => _beginSplitRename(tab),
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(vertical: 6),
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
    );
  }

  Widget _buildZoomMenuButton({
    required PdfTab tab,
    required ValueChanged<dynamic> onSelected,
  }) {
    return PopupMenuButton<dynamic>(
      onSelected: onSelected,
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (ctx) => _buildZoomMenuItems(ctx, tab),
      child: _buildZoomButtonContent(tab),
    );
  }

  List<PopupMenuEntry<dynamic>> _buildZoomMenuItems(
    BuildContext ctx,
    PdfTab tab,
  ) {
    final l10n = AppLocalizations.of(ctx)!;
    return <PopupMenuEntry<dynamic>>[
      PopupMenuItem<double>(
        value: 1.0,
        child: _buildZoomMenuItem('100%', tab.scale == 1.0),
      ),
      PopupMenuItem<double>(
        value: 1.5,
        child: _buildZoomMenuItem('150%', tab.scale == 1.5),
      ),
      PopupMenuItem<double>(
        value: 2.0,
        child: _buildZoomMenuItem('200%', tab.scale == 2.0),
      ),
      PopupMenuItem<double>(
        value: 2.5,
        child: _buildZoomMenuItem('250%', tab.scale == 2.5),
      ),
      const PopupMenuDivider(height: 8),
      PopupMenuItem<String>(
        value: 'fit_page',
        child: Row(
          children: [
            Icon(
              Icons.fit_screen_rounded,
              size: 18,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 10),
            Text(l10n.fitToPage),
          ],
        ),
      ),
      const PopupMenuDivider(height: 8),
      PopupMenuItem<String>(
        value: 'custom',
        child: Row(
          children: [
            Icon(Icons.tune_rounded, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 10),
            Text(l10n.custom),
          ],
        ),
      ),
    ];
  }

  Widget _buildZoomButtonContent(PdfTab tab) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 18, color: AppColors.primaryBlue),
          const SizedBox(width: 6),
          Text(
            '${(tab.scale * 100).round()}%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }

  Widget buildLoadingIndicator(PdfTab tab) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252525) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tab.loadingMessage,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: tab.loadingProgress,
                minHeight: 6,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProjectLoadingIndicator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final progress = _projectLoadingTotalFiles > 0
        ? _projectLoadingCurrentFile / _projectLoadingTotalFiles
        : null;

    return Center(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252525) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.folder_open,
                size: 32,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _currentProject?.name ?? '',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            if (_projectLoadingTotalFiles > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 16,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _projectLoadingFileName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${l10n?.file ?? 'File'} $_projectLoadingCurrentFile ${l10n?.outOf ?? 'of'} $_projectLoadingTotalFiles',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  l10n?.preloadingFiles ?? 'Loading project files...',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryBlue,
                ),
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildOpenFilePrompt() {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ScrollConfiguration(
          behavior: const _NoScrollbarBehavior(),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    Image.asset(
                      'assets/images/logo.png',
                      height: 48,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Text(
                          'AskoPDF',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    Text(
                      l10n?.lightweightPdfViewer ?? 'Lightweight PDF Viewer',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),

                    const SizedBox(height: 32),

                    _buildDropZone(isDark),

                    const SizedBox(height: 32),

                    _buildRecentFilesSection(isDark),

                    const SizedBox(height: 24),

                    _buildProjectsSection(isDark),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropZone(bool isDark) {
    final l10n = AppLocalizations.of(context);
    final isHovering = _isDropZoneHovered && !_isDragging;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isDropZoneHovered = true),
      onExit: (_) => setState(() => _isDropZoneHovered = false),
      child: GestureDetector(
        onTap: _openPdfFile,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 32),
          decoration: BoxDecoration(
            color: _isDragging
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04))
                : (isHovering
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.035))
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.black.withValues(alpha: 0.02))),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDragging
                  ? (isDark ? Colors.white24 : Colors.black26)
                  : (isHovering
                        ? (isDark ? Colors.white30 : Colors.black26)
                        : (isDark ? Colors.white10 : Colors.black12)),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.file_upload_outlined,
                size: 24,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(width: 16),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.dropFilesHere ?? 'Drag PDF files here',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n?.orClickToSelect ?? 'or click to choose files',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentFilesSection(bool isDark) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isRecentFilesExpanded = !_isRecentFilesExpanded;
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: _isRecentFilesExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n?.recentFiles ?? 'Recent Files',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black38,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (_recentFiles.isNotEmpty && _isRecentFilesExpanded)
                TextButton(
                  onPressed: () async {
                    await _recentFilesService.clearRecentFiles();
                    await _loadRecentFiles();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white38 : Colors.black38,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l10n?.clear ?? 'Clear',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),

        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _isRecentFilesExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _recentFiles.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l10n?.noRecentFiles ?? 'No recent files',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                )
              : SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _recentFiles.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return _buildRecentFileCard(_recentFiles[index], isDark);
                    },
                  ),
                ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildRecentFileCard(String path, bool isDark) {
    final fileName = path.split(Platform.pathSeparator).last;
    final data = _recentFilesData[path];
    final state = data?.state ?? _recentFilesState[path];
    final scale = state?.scale ?? 1.0;
    final currentPage = state?.currentPage ?? 1;
    final displayName =
        (data?.customTitle != null && data!.customTitle!.trim().isNotEmpty)
        ? data.customTitle!.trim()
        : fileName.replaceAll('.pdf', '').replaceAll('.PDF', '');
    final isEditing = _editingRecentPath == path;
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, isHovered) {
        return GestureDetector(
            onTap: isEditing ? null : () => _openFile(path),
            onSecondaryTapUp: (details) => _showRecentFileContextMenu(
              context,
              details.globalPosition,
              path,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 130,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: isHovered ? 0.08 : 0.04)
                    : (isHovered ? Colors.grey.shade50 : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? (isHovered ? Colors.white24 : Colors.white10)
                      : Colors.black.withValues(alpha: isHovered ? 0.1 : 0.06),
                ),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            'PDF',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      _buildRecentCardIcon(
                        icon: Icons.close,
                        tooltip:
                            AppLocalizations.of(context)?.remove ?? 'Remove',
                        isDark: isDark,
                        hoverColor: Colors.red.shade50,
                        onTap: () async {
                          await _recentFilesService.removeRecentFile(path);
                          await _loadRecentFiles();
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (isEditing)
                    TextField(
                      controller: _recentRenameController,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.2,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _commitRecentRename(),
                      onTapOutside: (_) => _commitRecentRename(),
                    )
                  else
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const Spacer(),

                  Row(
                    children: [
                      Text(
                        '${(scale * 100).round()}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'p.$currentPage',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
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

  void _showRecentFileContextMenu(
    BuildContext context,
    Offset position,
    String path,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final screenSize = overlay.size;
    const menuWidth = 180.0;
    const menuHeight = 46.0;
    final left = (position.dx + menuWidth + 8 > screenSize.width)
        ? screenSize.width - menuWidth - 8
        : position.dx;
    final top = (position.dy + menuHeight + 8 > screenSize.height)
        ? screenSize.height - menuHeight - 8
        : position.dy;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: menuWidth,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262626) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _buildContextMenuItem(
                    icon: Icons.edit_rounded,
                    label: l10n.rename,
                    onTap: () {
                      Navigator.of(context).pop();
                      _beginRecentRename(path);
                    },
                    isDark: isDark,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _beginRecentRename(String path) {
    final data = _recentFilesData[path];
    final fileName = path.split(Platform.pathSeparator).last;
    final baseName = fileName.replaceAll('.pdf', '').replaceAll('.PDF', '');
    final currentName =
        (data?.customTitle != null && data!.customTitle!.trim().isNotEmpty)
        ? data.customTitle!.trim()
        : baseName;

    setState(() {
      _editingRecentPath = path;
      _recentRenameController.text = currentName;
    });
  }

  Future<void> _commitRecentRename() async {
    final path = _editingRecentPath;
    if (path == null) return;
    final newName = _recentRenameController.text.trim();

    setState(() {
      _editingRecentPath = null;
    });

    await _documentStateService.saveDocumentDetails(path, customTitle: newName);

    final existing = _recentFilesData[path];
    if (mounted) {
      if (existing != null) {
        setState(() {
          _recentFilesData[path] = existing.copyWith(customTitle: newName);
        });
      } else {
        await _loadRecentFiles();
      }
    }

    final tabIndex = _tabs.indexWhere((tab) => tab.filePath == path);
    if (tabIndex != -1) {
      setState(() {
        _tabs[tabIndex].customTitle = newName;
      });
    }
  }

  Widget _buildRecentCardIcon({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required Color hoverColor,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: hoverColor,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              icon,
              size: 14,
              color: isDark ? Colors.white30 : Colors.black38,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContextMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.grey.shade100,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isDark ? Colors.white70 : Colors.grey.shade800,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectsSection(bool isDark) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isProjectsExpanded = !_isProjectsExpanded;
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: _isProjectsExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n?.projects ?? 'Projects',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black38,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (_isProjectsExpanded)
                TextButton.icon(
                  onPressed: _createProject,
                  icon: Icon(Icons.add, size: 16, color: AppColors.primaryBlue),
                  label: Text(
                    l10n?.newProject ?? 'New',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),

        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _isProjectsExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _projects.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 32,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.16)
                              : Colors.black12,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n?.noProjects ?? 'No projects yet',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _projects.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return _buildProjectCard(_projects[index], isDark);
                    },
                  ),
                ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildProjectCard(Project project, bool isDark) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, isHovered) {
        return GestureDetector(
            onTap: () => _openProject(project),
            onSecondaryTapUp: (details) {
              _showProjectContextMenu(context, details.globalPosition, project);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: isHovered ? 0.08 : 0.04)
                    : (isHovered ? Colors.grey.shade50 : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? (isHovered ? Colors.white24 : Colors.white10)
                      : Colors.black.withValues(alpha: isHovered ? 0.1 : 0.06),
                ),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                          Icons.folder,
                          size: 16,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const Spacer(),
                      _CardIconActionButton(
                        icon: Icons.edit_rounded,
                        iconColor: isDark ? Colors.white38 : Colors.black38,
                        hoverIconColor: AppColors.primaryBlue,
                        hoverBackgroundColor: AppColors.primaryBlue.withValues(
                          alpha: 0.12,
                        ),
                        onTap: () => _editProject(project),
                      ),
                      const SizedBox(width: 8),
                      _CardIconActionButton(
                        icon: Icons.close,
                        iconColor: isDark ? Colors.white24 : Colors.black26,
                        hoverIconColor: Colors.red.shade500,
                        hoverBackgroundColor: Colors.red.shade50.withValues(
                          alpha: 0.9,
                        ),
                        onTap: () => _deleteProject(project.id),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    project.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(),

                  Text(
                    '${project.documentCount} ${AppLocalizations.of(context)?.filesCount ?? 'files'}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          );
      },
    );
  }

  void _showProjectContextMenu(
    BuildContext context,
    Offset position,
    Project project,
  ) {
    final l10n = AppLocalizations.of(context)!;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          onTap: () => _openProject(project),
          child: Row(
            children: [
              Icon(Icons.open_in_new, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 12),
              Text(l10n.openProject),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () => _editProject(project),
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 12),
              Text(l10n.editProject),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () => _deleteProject(project.id),
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
              const SizedBox(width: 12),
              Text(
                l10n.deleteProject,
                style: TextStyle(color: Colors.red.shade400),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildPdfViewer(PdfTab tab) {
    if (tab.document == null) {
      return const Center(child: Text('Document not loaded'));
    }

    final docGroups = _documentGroups[tab.filePath];
    final activeGroup = docGroups?.activeGroup;

    List<int>? visiblePageIndices;
    if (activeGroup != null && activeGroup.pages.isNotEmpty) {
      visiblePageIndices = activeGroup.pageNumbers
          .where((p) => p >= 1 && p <= tab.totalPages)
          .map((p) => p - 1)
          .toList();
    }

    final displayCurrentPage = activeGroup != null && visiblePageIndices != null
        ? (visiblePageIndices.indexOf(tab.currentPage - 1) + 1)
        : tab.currentPage;
    final displayTotalPages = visiblePageIndices?.length ?? tab.totalPages;

    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              _onScroll(tab);
            }
            return false;
          },

          child: PanningArea(
            scrollController: tab.scrollController,
            horizontalScrollController: tab.horizontalScrollController,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Scrollbar(
                controller: tab.scrollController,
                thumbVisibility: true,
                thickness: 8.0,
                trackVisibility: true,
                child: GestureDetector(
                  onSecondaryTapUp: _copyPageAsImageEnabled
                      ? (details) {
                          _showPageContextMenu(context, details.globalPosition);
                        }
                      : null,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxPageWidth = tab.pageSizes.isNotEmpty
                          ? tab.pageSizes.map((s) => s.width).reduce(max)
                          : 0.0;
                      final contentWidth =
                          (maxPageWidth * tab.scale) + _pageSpacing * 2;
                      final viewportWidth = constraints.maxWidth;
                      final scrollWidth = max(viewportWidth, contentWidth);

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        controller: tab.horizontalScrollController,
                        child: SizedBox(
                          width: scrollWidth,
                          child: PdfPagesList(
                            document: tab.document!,
                            renderedPages: tab.renderedPages,
                            pageSizes: tab.pageSizes,
                            scrollController: tab.scrollController,
                            pageSpacing: _pageSpacing * tab.scale,
                            scale: tab.scale,
                            globalRotationAngle: tab.globalRotationAngle,
                            pageRotations: tab.pageRotations,
                            visiblePageIndices: visiblePageIndices,
                            targetRenderScale: _targetRenderScaleFor(tab.scale),
                            fallbackRenderScale: _tileFallbackRenderScale,
                            enableTileRendering: true,
                            tileScaleThreshold: _tileScaleThreshold,
                            tileSize: _tileSize,
                            visibilityKeyPrefix: tab.id,
                            onRequestRender: (pageIndex, renderScale) =>
                                _ensurePageRendered(
                                  tab,
                                  pageIndex,
                                  renderScale,
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubicEmphasized,
          bottom: 20,

          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: activeGroup != null
                  ? activeGroup.navigationColor.withValues(alpha: 0.8)
                  : Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (activeGroup != null) ...[
                  Text(activeGroup.icon, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                ],
                Text(
                  activeGroup != null
                      ? '$displayCurrentPage / $displayTotalPages'
                      : '${tab.currentPage} / ${tab.totalPages}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SplitMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _SplitMenuItem({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SplitMenuItem> createState() => _SplitMenuItemState();
}

class _SplitMenuItemState extends State<_SplitMenuItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: _hovering
              ? (widget.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade100)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplitDocumentItem extends StatefulWidget {
  final String name;
  final bool isDark;
  final VoidCallback onClose;

  const _SplitDocumentItem({
    required this.name,
    required this.isDark,
    required this.onClose,
  });

  @override
  State<_SplitDocumentItem> createState() => _SplitDocumentItemState();
}

class _SplitDocumentItemState extends State<_SplitDocumentItem> {
  bool _hovering = false;
  bool _closeHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: _hovering
            ? (widget.isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade50)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              size: 16,
              color: widget.isDark ? Colors.white54 : Colors.grey.shade500,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            MouseRegion(
              onEnter: (_) => setState(() => _closeHovering = true),
              onExit: (_) => setState(() => _closeHovering = false),
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _closeHovering
                        ? (widget.isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.grey.shade200)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: widget.isDark
                        ? Colors.white54
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
