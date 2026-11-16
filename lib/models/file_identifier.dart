import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

class FileIdentifier {
  final String id;
  final String path;
  final int fileSize;
  final DateTime lastModified;

  String get fileName => path.split(Platform.pathSeparator).last;

  const FileIdentifier({
    required this.id,
    required this.path,
    required this.fileSize,
    required this.lastModified,
  });

  static Future<FileIdentifier?> fromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final stat = await file.stat();
      final fileSize = stat.size;
      final lastModified = stat.modified;

      final id = await _generateFileId(file, fileSize);

      return FileIdentifier(
        id: id,
        path: filePath,
        fileSize: fileSize,
        lastModified: lastModified,
      );
    } catch (e) {
      debugPrint('FileIdentifier.fromFile error: $e');
      return null;
    }
  }

  static Future<String> _generateFileId(File file, int fileSize) async {
    const chunkSize = 8192;
    final List<int> dataToHash = [];
    dataToHash.addAll(utf8.encode('SIZE:$fileSize:'));
    final raf = await file.open(mode: FileMode.read);

    try {
      final startChunk = await raf.read(chunkSize);
      dataToHash.addAll(startChunk);

      if (fileSize > chunkSize * 2) {
        await raf.setPosition(fileSize - chunkSize);
        final endChunk = await raf.read(chunkSize);
        dataToHash.addAll(endChunk);
      }
    } finally {
      await raf.close();
    }

    final hash = sha256.convert(dataToHash);
    return hash.toString().substring(0, 32);
  }

  Future<bool> isValid() async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;

      final stat = await file.stat();
      if (stat.size != fileSize) return false;

      final currentId = await _generateFileId(file, stat.size);
      return currentId == id;
    } catch (e) {
      return false;
    }
  }

  Future<bool> matchesFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final stat = await file.stat();
      if (stat.size != fileSize) return false;

      final currentId = await _generateFileId(file, stat.size);
      return currentId == id;
    } catch (e) {
      return false;
    }
  }

  FileIdentifier copyWithPath(String newPath) {
    return FileIdentifier(
      id: id,
      path: newPath,
      fileSize: fileSize,
      lastModified: lastModified,
    );
  }

  factory FileIdentifier.fromJson(Map<String, dynamic> json) {
    return FileIdentifier(
      id: json['id'] as String,
      path: json['path'] as String,
      fileSize: json['fileSize'] as int,
      lastModified: DateTime.parse(json['lastModified'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'fileSize': fileSize,
      'lastModified': lastModified.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileIdentifier &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FileIdentifier(id: $id, path: $path, size: $fileSize)';
}
