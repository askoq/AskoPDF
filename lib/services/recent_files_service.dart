import 'package:shared_preferences/shared_preferences.dart';
import 'package:asko_pdf/models/file_identifier.dart';
import 'package:asko_pdf/services/document_storage_service.dart';

class RecentFilesService {
  static const String _keyRecentFilesExpanded = 'recent_files_expanded';
  final DocumentStorageService _storageService = DocumentStorageService();

  Future<bool> getRecentFilesExpanded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRecentFilesExpanded) ?? true;
  }

  Future<void> setRecentFilesExpanded(bool expanded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRecentFilesExpanded, expanded);
  }

  Future<List<FileIdentifier>> getRecentFileIdentifiers() async {
    return await _storageService.getRecentFiles();
  }

  Future<List<String>> getRecentFiles() async {
    final identifiers = await getRecentFileIdentifiers();
    final List<String> paths = [];

    for (final identifier in identifiers) {
      final lookup = await _storageService.lookupDocument(identifier.path);

      if (lookup.matchResult == FileMatchResult.exactMatch ||
          lookup.matchResult == FileMatchResult.pathChanged) {
        paths.add(lookup.currentFileIdentifier?.path ?? identifier.path);
      }
    }

    return paths;
  }

  Future<void> addRecentFile(String path) async {
    final identifier = await FileIdentifier.fromFile(path);
    if (identifier != null) {
      await _storageService.registerFileOpened(identifier);
    }
  }

  Future<void> addRecentFileIdentifier(FileIdentifier identifier) async {
    await _storageService.registerFileOpened(identifier);
  }

  Future<void> removeRecentFile(String path) async {
    await _storageService.removeDocumentByPath(path);
  }

  Future<void> removeRecentFileIdentifier(FileIdentifier identifier) async {
    await _storageService.removeDocument(identifier.id);
  }

  Future<void> clearRecentFiles() async {
    await _storageService.clearAllDocuments();
  }
}
