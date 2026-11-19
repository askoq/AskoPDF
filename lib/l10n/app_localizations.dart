import 'package:flutter/material.dart';
import 'package:asko_pdf/services/custom_language.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static LocalizationsDelegate<AppLocalizations> delegateFor(int revision) =>
      _AppLocalizationsDelegate(revision);

  static Map<String, String> get englishStrings =>
      Map.unmodifiable(_localizedValues['en']!);

  bool get isCustomLanguage => CustomLanguage.isCustomLocale(locale);

  String _t(String key) {
    if (isCustomLanguage) {
      final value = CustomLanguage.instance.strings[key];
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return _localizedValues['en']![key] ?? key;
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appName': 'AskoPDF',
      'settings': 'Settings',
      'view': 'View',
      'splitView': 'Split View',
      'swapDocuments': 'Swap Documents',
      'openDocuments': 'Open Documents',
      'about': 'About',
      'general': 'General',
      'language': 'Language',
      'languageSubtitle': 'Select interface language',
      'english': 'English',
      'viewSettings': 'View Settings',
      'viewSettingsSubtitle':
          'Configure how pages are displayed and interacted with',
      'copyPageAsImage': 'Copy page as image',
      'copyPageAsImageSubtitle':
          'Right-click on a page to copy it as an image to clipboard',
      'lightweightPdfViewer': 'Choose a PDF file or drag it here',
      'madeBy': 'Made by',
      'aboutTagline':
          'Focused PDF reading for tabs, split view, and page groups.',
      'aboutEngine': 'Engine',
      'aboutBuild': 'Build',
      'aboutEngineSubtitle': 'Native PDF rendering core',
      'aboutBuildSubtitle': 'Tabs, projects, and page groups',
      'pdfEngineMissingTitle': 'PDF engine unavailable',
      'pdfEngineMissingMessage':
          'AskoPDF could not load the Gelide engine library. The app needs this library to open PDF files.',
      'pdfEngineMissingHint':
          'Check that gelide_core.dll exists next to the application and is not damaged or blocked by the system.',
      'pdfiumMissingMessage':
          'AskoPDF could not initialize PDFium. The app needs this library to open PDF files.',
      'pdfiumMissingHint':
          'Check that pdfium.dll exists next to the application and is not damaged or blocked by the system.',
      'technicalDetails': 'Technical details',
      'pageNavigation': 'Page navigation',
      'searchInDocument': 'Search in document',
      'searchPlaceholder': 'Find in document...',
      'previousResult': 'Previous result',
      'nextResult': 'Next result',
      'noMatchesFound': 'No matches',
      'match': 'match',
      'matches': 'matches',
      'tipLabel': 'Tip',
      'splitViewDragTip': 'Drag a tab over the document to open Split View.',
      'splitViewMenuTip':
          'Click "Split View" in the title bar to open the mode menu.',
      'rotate': 'Rotate',
      'rotateCurrentPage': 'Rotate current page',
      'rotateAllPages': 'Rotate all pages',
      'zoomIn': 'Zoom in',
      'zoomOut': 'Zoom out',
      'customZoom': 'Custom zoom',
      'documentInfo': 'Document info',
      'openFile': 'Open File',
      'openPdfFile': 'Open PDF File',
      'dropFileHere': 'Release PDF files to open them',
      'recentFiles': 'Recent files',
      'page': 'Page',
      'pages': 'Pages',
      'goToPage': 'Go to page...',
      'copiedToClipboard': 'copied to clipboard',
      'failedToCopy': 'Failed to copy page',
      'failedToOpenDocument': 'Failed to open document',
      'documentNavigation': 'Document navigation',
      'showAll': 'Show all',
      'createGroup': 'Create Group',
      'editGroup': 'Edit Group',
      'deleteGroup': 'Delete',
      'groupName': 'Group Name',
      'groupIcon': 'Group Icon',
      'appearance': 'Appearance',
      'colorStyle': 'Color Style',
      'solid': 'Solid',
      'gradient': 'Gradient',
      'primaryColor': 'Primary Color',
      'secondaryColor': 'Secondary Color',
      'preview': 'Preview',
      'navigationPanelColor': 'Navigation Panel Color',
      'addPages': 'Add Pages',
      'groupPages': 'Group Pages',
      'noPagesInGroup': 'No pages in this group',
      'totalPagesInDocument': 'Total pages in document',
      'rename': 'Rename',
      'remove': 'Remove',
      'cancel': 'Cancel',
      'save': 'Save',
      'saveChanges': 'Save Changes',
      'add': 'Add',
      'enterGroupName': 'Enter group name...',
      'invalidFormat': 'Invalid format. Use: 1-10 or 1,3,5',
      'fileName': 'File name',
      'filePath': 'File path',
      'fileSize': 'File size',
      'lastModified': 'Last modified',
      'pagesCount': 'Pages',
      'close': 'Close',
      'zoom': 'Zoom',
      'enterZoom': 'Enter zoom percentage',
      'minZoom': 'Minimum: 40%',
      'maxZoom': 'Maximum: 400%',
      'apply': 'Apply',
      'groups': 'Groups',
      'allPages': 'All Pages',
      'noGroupsYet': 'No groups yet',
      'createFirstGroup': 'Create first group',
      'deleteGroupTitle': 'Delete Group?',
      'deleteGroupMessage':
          'Are you sure you want to delete this group? This will not delete the pages from the document.',
      'delete': 'Delete',
      'properties': 'Properties',
      'file': 'File',
      'name': 'Name',
      'path': 'Path',
      'size': 'Size',
      'modified': 'Modified',
      'accessed': 'Accessed',
      'document': 'Document',
      'pageSize': 'Page Size',
      'pdfVersion': 'PDF Version',
      'unknown': 'Unknown',
      'fitToPage': 'Fit to page',
      'custom': 'Custom...',
      'rotationOptions': 'Rotation options',
      'clear': 'Clear',
      'noRecentFiles': 'No recent files',
      'closeTab': 'Close tab',
      'confirmClose': 'Confirm close',
      'confirmCloseMessage': 'Close this document?',
      'yes': 'Yes',
      'no': 'No',
      'rotateRight': 'Right (+90°)',
      'rotateLeft': 'Left (-90°)',
      'rotate180': '180°',
      'mode': 'Mode',
      'currentPage': 'Current page',
      'allPagesMode': 'All pages',
      'pageInputHint': 'e.g., 1-10 or 1,3,5',
      'pageOfTotal': 'Page',
      'zoomAnimation': 'Zoom Animation',
      'zoomAnimationSubtitle': 'Enable smooth scaling animation',
      'dropFilesHere': 'Drag PDF files here',
      'orClickToSelect': 'or click to choose files',
      'openFiles': 'Open Files',
      'noFilesOpen': 'No files open',
      'projects': 'Projects',
      'createProject': 'Create Project',
      'editProject': 'Edit Project',
      'deleteProject': 'Delete Project',
      'projectName': 'Project Name',
      'enterProjectName': 'Enter project name',
      'addDocuments': 'Add Documents',
      'openProject': 'Open Project',
      'newProject': 'New Project',
      'noProjects': 'No projects yet',
      'preloadingFiles': 'Loading project files...',
      'deleteProjectConfirm': 'Delete this project?',
      'projectEmpty': 'Project is empty',
      'projectRequiresFiles': 'Add at least one PDF file',
      'filesCount': 'files',
      'optional': 'optional',
      'customLanguage': 'Your language',
      'addLanguage': 'Add language',
      'editTranslation': 'Edit translation',
      'customLanguageTitle': 'Your language',
      'customLanguageHint':
          'Type a translation for each line. Empty lines stay in English.',
      'languageName': 'Language name',
      'languageNameHint': 'For example, Deutsch',
      'searchStrings': 'Search lines',
      'translatedCount': 'translated',
      'openTranslationFolder': 'Open folder',
      'outOf': 'of',
    },
  };

  String get appName => _t('appName');
  String get settings => _t('settings');
  String get view => _t('view');
  String get splitView => _t('splitView');
  String get swapDocuments =>
      _t('swapDocuments');
  String get openDocuments =>
      _t('openDocuments');
  String get about => _t('about');
  String get general => _t('general');
  String get language => _t('language');
  String get languageSubtitle =>
      _t('languageSubtitle');
  String get english => _t('english');
  String get viewSettings =>
      _t('viewSettings');
  String get viewSettingsSubtitle =>
      _t('viewSettingsSubtitle');
  String get copyPageAsImage =>
      _t('copyPageAsImage');
  String get copyPageAsImageSubtitle =>
      _t('copyPageAsImageSubtitle');
  String get lightweightPdfViewer =>
      _t('lightweightPdfViewer');
  String get madeBy => _t('madeBy');
  String get aboutTagline =>
      _t('aboutTagline');
  String get aboutEngine =>
      _t('aboutEngine');
  String get aboutBuild =>
      _t('aboutBuild');
  String get aboutEngineSubtitle =>
      _t('aboutEngineSubtitle');
  String get aboutBuildSubtitle =>
      _t('aboutBuildSubtitle');
  String get pdfEngineMissingTitle =>
      _t('pdfEngineMissingTitle');
  String get pdfEngineMissingMessage =>
      _t('pdfEngineMissingMessage');
  String get pdfEngineMissingHint =>
      _t('pdfEngineMissingHint');
  String get pdfiumMissingMessage =>
      _t('pdfiumMissingMessage');
  String get pdfiumMissingHint =>
      _t('pdfiumMissingHint');
  String get technicalDetails =>
      _t('technicalDetails');
  String get pageNavigation =>
      _t('pageNavigation');
  String get searchInDocument => _t('searchInDocument');
  String get searchPlaceholder => _t('searchPlaceholder');
  String get previousResult => _t('previousResult');
  String get nextResult => _t('nextResult');
  String get noMatchesFound => _t('noMatchesFound');
  String get match => _t('match');
  String get matches => _t('matches');
  String get tipLabel => _t('tipLabel');
  String get splitViewDragTip => _t('splitViewDragTip');
  String get splitViewMenuTip => _t('splitViewMenuTip');
  String get rotate => _t('rotate');
  String get rotateCurrentPage =>
      _t('rotateCurrentPage');
  String get rotateAllPages =>
      _t('rotateAllPages');
  String get zoomIn => _t('zoomIn');
  String get zoomOut => _t('zoomOut');
  String get customZoom =>
      _t('customZoom');
  String get documentInfo =>
      _t('documentInfo');
  String get openFile => _t('openFile');
  String get openPdfFile =>
      _t('openPdfFile');
  String get dropFileHere =>
      _t('dropFileHere');
  String get recentFiles =>
      _t('recentFiles');
  String get page => _t('page');
  String get pages => _t('pages');
  String get goToPage => _t('goToPage');
  String get copiedToClipboard =>
      _t('copiedToClipboard');
  String get failedToCopy =>
      _t('failedToCopy');
  String get failedToOpenDocument =>
      _t('failedToOpenDocument');
  String get documentNavigation =>
      _t('documentNavigation');
  String get showAll => _t('showAll');
  String get createGroup =>
      _t('createGroup');
  String get editGroup => _t('editGroup');
  String get deleteGroup =>
      _t('deleteGroup');
  String get groupName => _t('groupName');
  String get groupIcon => _t('groupIcon');
  String get appearance =>
      _t('appearance');
  String get colorStyle =>
      _t('colorStyle');
  String get solid => _t('solid');
  String get gradient => _t('gradient');
  String get primaryColor =>
      _t('primaryColor');
  String get secondaryColor =>
      _t('secondaryColor');
  String get preview => _t('preview');
  String get navigationPanelColor =>
      _t('navigationPanelColor');
  String get addPages => _t('addPages');
  String get groupPages =>
      _t('groupPages');
  String get noPagesInGroup =>
      _t('noPagesInGroup');
  String get totalPagesInDocument =>
      _t('totalPagesInDocument');
  String get rename => _t('rename');
  String get remove => _t('remove');
  String get cancel => _t('cancel');
  String get save => _t('save');
  String get saveChanges =>
      _t('saveChanges');
  String get add => _t('add');
  String get enterGroupName =>
      _t('enterGroupName');
  String get invalidFormat =>
      _t('invalidFormat');
  String get fileName => _t('fileName');
  String get filePath => _t('filePath');
  String get fileSize => _t('fileSize');
  String get lastModified =>
      _t('lastModified');
  String get pagesCount =>
      _t('pagesCount');
  String get close => _t('close');
  String get zoom => _t('zoom');
  String get enterZoom => _t('enterZoom');
  String get minZoom => _t('minZoom');
  String get maxZoom => _t('maxZoom');
  String get apply => _t('apply');
  String get groups => _t('groups');
  String get allPages => _t('allPages');
  String get noGroupsYet =>
      _t('noGroupsYet');
  String get createFirstGroup =>
      _t('createFirstGroup');
  String get deleteGroupTitle =>
      _t('deleteGroupTitle');
  String get deleteGroupMessage =>
      _t('deleteGroupMessage');
  String get delete => _t('delete');
  String get properties =>
      _t('properties');
  String get file => _t('file');
  String get name => _t('name');
  String get path => _t('path');
  String get size => _t('size');
  String get modified => _t('modified');
  String get accessed => _t('accessed');
  String get document => _t('document');
  String get pageSize => _t('pageSize');
  String get pdfVersion =>
      _t('pdfVersion');
  String get unknown => _t('unknown');
  String get fitToPage => _t('fitToPage');
  String get custom => _t('custom');
  String get rotationOptions =>
      _t('rotationOptions');
  String get clear => _t('clear');
  String get noRecentFiles =>
      _t('noRecentFiles');
  String get closeTab => _t('closeTab');
  String get confirmClose =>
      _t('confirmClose');
  String get confirmCloseMessage =>
      _t('confirmCloseMessage');
  String get yes => _t('yes');
  String get no => _t('no');
  String get rotateRight =>
      _t('rotateRight');
  String get rotateLeft =>
      _t('rotateLeft');
  String get rotate180 => _t('rotate180');
  String get mode => _t('mode');
  String get currentPage =>
      _t('currentPage');
  String get allPagesMode =>
      _t('allPagesMode');
  String get pageInputHint =>
      _t('pageInputHint');
  String get pageOfTotal =>
      _t('pageOfTotal');
  String get zoomAnimation =>
      _t('zoomAnimation');
  String get zoomAnimationSubtitle =>
      _t('zoomAnimationSubtitle');
  String get dropFilesHere =>
      _t('dropFilesHere');
  String get orClickToSelect =>
      _t('orClickToSelect');
  String get openFiles => _t('openFiles');
  String get noFilesOpen =>
      _t('noFilesOpen');

  String get projects => _t('projects');
  String get createProject =>
      _t('createProject');
  String get editProject =>
      _t('editProject');
  String get deleteProject =>
      _t('deleteProject');
  String get projectName =>
      _t('projectName');
  String get enterProjectName =>
      _t('enterProjectName');
  String get addDocuments =>
      _t('addDocuments');
  String get openProject =>
      _t('openProject');
  String get newProject =>
      _t('newProject');
  String get noProjects =>
      _t('noProjects');
  String get preloadingFiles =>
      _t('preloadingFiles');
  String get deleteProjectConfirm =>
      _t('deleteProjectConfirm');
  String get projectEmpty =>
      _t('projectEmpty');
  String get projectRequiresFiles =>
      _t('projectRequiresFiles');
  String get filesCount =>
      _t('filesCount');
  String get optional => _t('optional');

  String get customLanguage => _t('customLanguage');
  String get addLanguage => _t('addLanguage');
  String get editTranslation => _t('editTranslation');
  String get customLanguageTitle => _t('customLanguageTitle');
  String get customLanguageHint => _t('customLanguageHint');
  String get languageName => _t('languageName');
  String get languageNameHint => _t('languageNameHint');
  String get searchStrings => _t('searchStrings');
  String get translatedCount => _t('translatedCount');
  String get openTranslationFolder => _t('openTranslationFolder');
  String get outOf => _t('outOf');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate([this.revision = 0]);

  final int revision;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) =>
      old.revision != revision;
}
