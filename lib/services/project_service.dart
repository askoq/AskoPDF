import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:asko_pdf/models/project.dart';

class ProjectService {
  static final ProjectService _instance = ProjectService._();
  factory ProjectService() => _instance;
  ProjectService._();

  static const String _fileName = 'projects.json';
  static const int _storageVersion = 1;

  Map<String, Project>? _cache;
  bool _isDirty = false;

  Future<File> _getStorageFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  Future<void> _saveChain = Future<void>.value();
  Future<Map<String, Project>>? _loading;

  Future<Map<String, Project>> _loadData() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);
    return _loading ??= _readData().whenComplete(() => _loading = null);
  }

  Future<Map<String, Project>> _readData() async {
    if (_cache != null) return _cache!;

    try {
      final file = await _getStorageFile();
      if (!await file.exists()) {
        _cache = {};
        return _cache!;
      }

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final version = json['version'] as int? ?? 1;
      if (version != _storageVersion) {
        debugPrint(
          'Projects storage version mismatch: $version vs $_storageVersion',
        );
      }

      final projectsJson = json['projects'] as Map<String, dynamic>? ?? {};
      _cache = projectsJson.map(
        (key, value) =>
            MapEntry(key, Project.fromJson(value as Map<String, dynamic>)),
      );

      return _cache!;
    } catch (e) {
      debugPrint('ProjectService._loadData error: $e');
      await _backUpUnreadableFile();
      _cache = {};
      return _cache!;
    }
  }

  Future<void> _saveData() {
    _saveChain = _saveChain.catchError((Object _) {}).then((_) => _writeData());
    return _saveChain;
  }

  Future<void> _writeData() async {
    if (!_isDirty || _cache == null) return;

    try {
      final file = await _getStorageFile();
      final json = {
        'version': _storageVersion,
        'lastUpdated': DateTime.now().toIso8601String(),
        'projects': _cache!.map((key, value) => MapEntry(key, value.toJson())),
      };

      await _writeAtomically(file, jsonEncode(json));
      _isDirty = false;
    } catch (e) {
      debugPrint('ProjectService._saveData error: $e');
    }
  }

  Future<List<Project>> getProjects() async {
    final data = await _loadData();
    final projects = data.values.toList();
    projects.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
    return projects;
  }

  Future<Project?> getProject(String id) async {
    final data = await _loadData();
    return data[id];
  }

  Future<Project> createProject(
    String name, {
    List<String>? initialFiles,
  }) async {
    final project = Project(name: name);

    if (initialFiles != null) {
      for (final filePath in initialFiles) {
        project.addDocument(filePath);
      }
    }

    final data = await _loadData();
    data[project.id] = project;
    _isDirty = true;
    await _saveData();

    return project;
  }

  Future<void> updateProject(Project project) async {
    final data = await _loadData();

    project.lastOpenedAt = DateTime.now();
    data[project.id] = project;
    _isDirty = true;
    await _saveData();
  }

  Future<void> deleteProject(String id) async {
    final data = await _loadData();
    data.remove(id);
    _isDirty = true;
    await _saveData();
  }

  Future<void> addDocumentToProject(
    String projectId,
    String filePath, {
    String customTabName = '',
  }) async {
    final data = await _loadData();
    final project = data[projectId];

    if (project != null) {
      project.addDocument(filePath, customTabName: customTabName);
      _isDirty = true;
      await _saveData();
    }
  }

  Future<void> removeDocumentFromProject(
    String projectId,
    String filePath,
  ) async {
    final data = await _loadData();
    final project = data[projectId];

    if (project != null) {
      project.removeDocument(filePath);
      _isDirty = true;
      await _saveData();
    }
  }

  Future<void> updateDocumentName(
    String projectId,
    String filePath,
    String newName,
  ) async {
    final data = await _loadData();
    final project = data[projectId];

    if (project != null) {
      project.updateDocumentName(filePath, newName);
      _isDirty = true;
      await _saveData();
    }
  }

  Future<void> reorderDocuments(
    String projectId,
    int oldIndex,
    int newIndex,
  ) async {
    final data = await _loadData();
    final project = data[projectId];

    if (project != null) {
      project.reorderDocuments(oldIndex, newIndex);
      _isDirty = true;
      await _saveData();
    }
  }

  Future<void> markProjectOpened(String projectId) async {
    final data = await _loadData();
    final project = data[projectId];

    if (project != null) {
      project.lastOpenedAt = DateTime.now();
      _isDirty = true;
      await _saveData();
    }
  }

  void clearCache() {
    _cache = null;
    _isDirty = false;
  }

  Future<void> _writeAtomically(File file, String content) async {
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(content, flush: true);
    await temp.rename(file.path);
  }

  Future<void> _backUpUnreadableFile() async {
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        await file.copy('${file.path}.unreadable');
      }
    } catch (_) {}
  }
}
