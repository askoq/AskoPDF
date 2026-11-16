import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:asko_pdf/models/file_identifier.dart';
import 'package:asko_pdf/models/page_group.dart';
import 'package:asko_pdf/models/pdf_metadata.dart';

enum FileMatchResult { exactMatch, pathChanged, fileReplaced, notFound }

class DocumentLookupResult {
  final FileMatchResult matchResult;
  final DocumentData? documentData;
  final FileIdentifier? currentFileIdentifier;

  const DocumentLookupResult({
    required this.matchResult,
    this.documentData,
    this.currentFileIdentifier,
  });
}

class DocumentData {
  final FileIdentifier fileIdentifier;
  final DocumentGroups? groups;
  final DocumentState? state;
  final DateTime lastOpened;
  final String? customTitle;
  final int? totalPages;
  final double? pageWidth;
  final double? pageHeight;
  final PdfMetadata? metadata;

  const DocumentData({
    required this.fileIdentifier,
    this.groups,
    this.state,
    required this.lastOpened,
    this.customTitle,
    this.totalPages,
    this.pageWidth,
    this.pageHeight,
    this.metadata,
  });

  factory DocumentData.fromJson(Map<String, dynamic> json) {
    return DocumentData(
      fileIdentifier: FileIdentifier.fromJson(
        json['fileIdentifier'] as Map<String, dynamic>,
      ),
      groups: json['groups'] != null
          ? DocumentGroups.fromJson(json['groups'] as Map<String, dynamic>)
          : null,
      state: json['state'] != null
          ? DocumentState.fromJson(json['state'] as Map<String, dynamic>)
          : null,
      lastOpened: DateTime.parse(json['lastOpened'] as String),
      customTitle: json['customTitle'] as String?,
      totalPages: json['totalPages'] as int?,
      pageWidth: (json['pageWidth'] as num?)?.toDouble(),
      pageHeight: (json['pageHeight'] as num?)?.toDouble(),
      metadata: json['metadata'] != null
          ? () {
              final meta = json['metadata'] as Map<String, dynamic>;
              return PdfMetadata(
                fileSize: (meta['fileSize'] as num?)?.toInt() ?? 0,
                lastModified: meta['lastModified'] != null
                    ? DateTime.parse(meta['lastModified'] as String)
                    : null,
                lastAccessed: meta['lastAccessed'] != null
                    ? DateTime.parse(meta['lastAccessed'] as String)
                    : null,
                pdfVersion: meta['pdfVersion'] as String?,
              );
            }()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileIdentifier': fileIdentifier.toJson(),
      'groups': groups?.toJson(),
      'state': state?.toJson(),
      'lastOpened': lastOpened.toIso8601String(),
      'customTitle': customTitle,
      'totalPages': totalPages,
      'pageWidth': pageWidth,
      'pageHeight': pageHeight,
      'metadata': metadata != null
          ? {
              'fileSize': metadata!.fileSize,
              'lastModified': metadata!.lastModified?.toIso8601String(),
              'lastAccessed': metadata!.lastAccessed?.toIso8601String(),
              'pdfVersion': metadata!.pdfVersion,
            }
          : null,
    };
  }

  DocumentData copyWith({
    FileIdentifier? fileIdentifier,
    DocumentGroups? groups,
    DocumentState? state,
    DateTime? lastOpened,
    String? customTitle,
    int? totalPages,
    double? pageWidth,
    double? pageHeight,
    PdfMetadata? metadata,
    bool setGroupsNull = false,
    bool setStateNull = false,
  }) {
    return DocumentData(
      fileIdentifier: fileIdentifier ?? this.fileIdentifier,
      groups: setGroupsNull ? null : (groups ?? this.groups),
      state: setStateNull ? null : (state ?? this.state),
      lastOpened: lastOpened ?? this.lastOpened,
      customTitle: customTitle ?? this.customTitle,
      totalPages: totalPages ?? this.totalPages,
      pageWidth: pageWidth ?? this.pageWidth,
      pageHeight: pageHeight ?? this.pageHeight,
      metadata: metadata ?? this.metadata,
    );
  }
}

class DocumentState {
  final int currentPage;
  final double scale;

  const DocumentState({required this.currentPage, required this.scale});

  factory DocumentState.fromJson(Map<String, dynamic> json) {
    return DocumentState(
      currentPage: json['currentPage'] as int? ?? 1,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'currentPage': currentPage, 'scale': scale};
  }
}

class DocumentStorageService {
  static final DocumentStorageService _instance = DocumentStorageService._();
  factory DocumentStorageService() => _instance;
  DocumentStorageService._();

  static const String _fileName = 'documents_data.json';
  static const int _storageVersion = 1;
  static const int _maxRecentFiles = 10;
  static const int _maxStoredDocuments = 100;

  Map<String, DocumentData>? _cache;
  bool _isDirty = false;

  Future<File> _getStorageFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  Map<String, dynamic>? _tryDecodeJson(String content) {
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _tryRepairAndDecode(String content) {
    var working = content.trim();
    for (int attempt = 0; attempt < 5 && working.isNotEmpty; attempt++) {
      try {
        return jsonDecode(working) as Map<String, dynamic>;
      } catch (e) {
        if (e is FormatException) {
          final offset = e.offset;
          if (offset != null && offset > 0 && offset <= working.length) {
            working = working.substring(0, offset).trimRight();
          } else {
            working = working.substring(0, working.length - 1).trimRight();
          }
          continue;
        }
        break;
      }
    }
    return null;
  }

  Future<void> _saveChain = Future<void>.value();
  Future<Map<String, DocumentData>>? _loading;

  Future<Map<String, DocumentData>> _loadData() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);
    return _loading ??= _readData().whenComplete(() => _loading = null);
  }

  Future<Map<String, DocumentData>> _readData() async {
    if (_cache != null) return _cache!;

    try {
      final file = await _getStorageFile();
      if (!await file.exists()) {
        _cache = {};
        return _cache!;
      }

      final content = await file.readAsString();
      var json = _tryDecodeJson(content);
      if (json == null) {
        json = _tryRepairAndDecode(content);
        if (json != null) {
          await file.writeAsString(jsonEncode(json));
        }
      }
      if (json == null) {
        throw const FormatException('Invalid documents_data.json');
      }

      final version = json['version'] as int? ?? 1;
      if (version != _storageVersion) {
        debugPrint('Storage version mismatch: $version vs $_storageVersion');
      }

      final documentsJson = json['documents'] as Map<String, dynamic>? ?? {};
      _cache = documentsJson.map(
        (key, value) =>
            MapEntry(key, DocumentData.fromJson(value as Map<String, dynamic>)),
      );

      return _cache!;
    } catch (e) {
      debugPrint('DocumentStorageService._loadData error: $e');
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
        'documents': _cache!.map((key, value) => MapEntry(key, value.toJson())),
      };

      await _writeAtomically(file, jsonEncode(json));
      _isDirty = false;
    } catch (e) {
      debugPrint('DocumentStorageService._saveData error: $e');
    }
  }

  Future<DocumentLookupResult> lookupDocument(String filePath) async {
    final currentIdentifier = await FileIdentifier.fromFile(filePath);
    if (currentIdentifier == null) {
      return const DocumentLookupResult(matchResult: FileMatchResult.notFound);
    }

    final data = await _loadData();

    if (data.containsKey(currentIdentifier.id)) {
      final docData = data[currentIdentifier.id]!;

      if (docData.fileIdentifier.path == filePath) {
        return DocumentLookupResult(
          matchResult: FileMatchResult.exactMatch,
          documentData: docData,
          currentFileIdentifier: currentIdentifier,
        );
      } else {
        return DocumentLookupResult(
          matchResult: FileMatchResult.pathChanged,
          documentData: docData,
          currentFileIdentifier: currentIdentifier,
        );
      }
    }

    for (final entry in data.entries) {
      if (entry.value.fileIdentifier.path == filePath) {
        return DocumentLookupResult(
          matchResult: FileMatchResult.fileReplaced,
          documentData: entry.value,
          currentFileIdentifier: currentIdentifier,
        );
      }
    }

    return DocumentLookupResult(
      matchResult: FileMatchResult.notFound,
      currentFileIdentifier: currentIdentifier,
    );
  }

  Future<DocumentData?> getDocument(FileIdentifier identifier) async {
    final data = await _loadData();
    return data[identifier.id];
  }

  Future<DocumentData?> getDocumentByPath(String filePath) async {
    final lookup = await lookupDocument(filePath);
    return lookup.documentData;
  }

  Future<void> saveDocument(DocumentData document) async {
    final data = await _loadData();
    data[document.fileIdentifier.id] = document;
    _isDirty = true;

    await _cleanupOldDocuments();
    await _saveData();
  }

  Future<void> updateDocumentPath(
    String oldFileId,
    FileIdentifier newIdentifier,
  ) async {
    final data = await _loadData();

    if (data.containsKey(oldFileId)) {
      final oldData = data[oldFileId]!;
      data[oldFileId] = oldData.copyWith(fileIdentifier: newIdentifier);
      _isDirty = true;
      await _saveData();
    }
  }

  Future<void> saveDocumentGroups(
    FileIdentifier identifier,
    DocumentGroups groups,
  ) async {
    final data = await _loadData();
    final existing = data[identifier.id];

    if (existing != null) {
      data[identifier.id] = existing.copyWith(groups: groups);
    } else {
      data[identifier.id] = DocumentData(
        fileIdentifier: identifier,
        groups: groups,
        lastOpened: DateTime.now(),
      );
    }

    _isDirty = true;
    await _saveData();
  }

  Future<DocumentGroups?> getDocumentGroups(FileIdentifier identifier) async {
    final doc = await getDocument(identifier);
    return doc?.groups;
  }

  Future<void> saveDocumentState(
    FileIdentifier identifier, {
    required int currentPage,
    required double scale,
  }) async {
    final data = await _loadData();
    final existing = data[identifier.id];

    final state = DocumentState(currentPage: currentPage, scale: scale);

    if (existing != null) {
      data[identifier.id] = existing.copyWith(
        state: state,
        lastOpened: DateTime.now(),
      );
    } else {
      data[identifier.id] = DocumentData(
        fileIdentifier: identifier,
        state: state,
        lastOpened: DateTime.now(),
      );
    }

    _isDirty = true;
    await _saveData();
  }

  Future<void> saveDocumentDetails(
    FileIdentifier identifier, {
    String? customTitle,
    int? totalPages,
    double? pageWidth,
    double? pageHeight,
    PdfMetadata? metadata,
  }) async {
    final data = await _loadData();
    final existing = data[identifier.id];

    if (existing != null) {
      data[identifier.id] = existing.copyWith(
        customTitle: customTitle ?? existing.customTitle,
        totalPages: totalPages ?? existing.totalPages,
        pageWidth: pageWidth ?? existing.pageWidth,
        pageHeight: pageHeight ?? existing.pageHeight,
        metadata: metadata ?? existing.metadata,
        lastOpened: DateTime.now(),
      );
    } else {
      data[identifier.id] = DocumentData(
        fileIdentifier: identifier,
        customTitle: customTitle,
        totalPages: totalPages,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
        metadata: metadata,
        lastOpened: DateTime.now(),
      );
    }

    _isDirty = true;
    await _saveData();
  }

  Future<DocumentState?> getDocumentState(FileIdentifier identifier) async {
    final doc = await getDocument(identifier);
    return doc?.state;
  }

  Future<void> registerFileOpened(FileIdentifier identifier) async {
    final data = await _loadData();
    final existing = data[identifier.id];

    if (existing != null) {
      data[identifier.id] = existing.copyWith(
        fileIdentifier: identifier,
        lastOpened: DateTime.now(),
      );
    } else {
      data[identifier.id] = DocumentData(
        fileIdentifier: identifier,
        lastOpened: DateTime.now(),
      );
    }

    _isDirty = true;
    await _saveData();
  }

  Future<List<FileIdentifier>> getRecentFiles() async {
    final data = await _loadData();

    final entries = data.values.toList()
      ..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));

    return entries.take(_maxRecentFiles).map((e) => e.fileIdentifier).toList();
  }

  Future<void> removeDocument(String fileId) async {
    final data = await _loadData();
    data.remove(fileId);
    _isDirty = true;
    await _saveData();
  }

  Future<void> removeDocumentByPath(String filePath) async {
    final lookup = await lookupDocument(filePath);
    if (lookup.currentFileIdentifier != null) {
      await removeDocument(lookup.currentFileIdentifier!.id);
    }
  }

  Future<void> _cleanupOldDocuments() async {
    final data = await _loadData();

    if (data.length <= _maxStoredDocuments) return;

    final entries = data.entries.toList()
      ..sort((a, b) => b.value.lastOpened.compareTo(a.value.lastOpened));

    final cutoffDate = DateTime.now().subtract(const Duration(days: 90));

    for (int i = _maxStoredDocuments; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.value.lastOpened.isBefore(cutoffDate)) {
        if (entry.value.groups == null || entry.value.groups!.groups.isEmpty) {
          data.remove(entry.key);
        }
      }
    }

    _isDirty = true;
  }

  Future<void> clearAllDocuments() async {
    _cache = {};
    _isDirty = true;
    await _saveData();
  }

  Future<String> exportData() async {
    final data = await _loadData();
    return jsonEncode({
      'version': _storageVersion,
      'exportDate': DateTime.now().toIso8601String(),
      'documents': data.map((key, value) => MapEntry(key, value.toJson())),
    });
  }

  Future<bool> importData(String jsonString) async {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final documentsJson = json['documents'] as Map<String, dynamic>? ?? {};

      final imported = documentsJson.map(
        (key, value) =>
            MapEntry(key, DocumentData.fromJson(value as Map<String, dynamic>)),
      );

      _cache = imported;
      _isDirty = true;
      await _saveData();
      return true;
    } catch (e) {
      debugPrint('DocumentStorageService.importData error: $e');
      return false;
    }
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
