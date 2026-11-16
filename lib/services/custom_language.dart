import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class CustomLanguage {
  CustomLanguage._();

  static final CustomLanguage instance = CustomLanguage._();

  static const String settingsCode = 'custom';

  static const Locale locale = Locale('en', 'ZZ');

  static bool isCustomLocale(Locale value) =>
      value.languageCode == locale.languageCode &&
      value.countryCode == locale.countryCode;

  static const String _fileName = 'custom_language.json';

  String name = '';
  Map<String, String> strings = {};

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool get exists => name.trim().isNotEmpty || strings.isNotEmpty;

  String get displayName =>
      name.trim().isEmpty ? 'Custom' : name.trim();

  Future<Directory> folder() => getApplicationSupportDirectory();

  Future<File> _file() async {
    final dir = await folder();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return;
      name = json['name']?.toString() ?? '';
      final raw = json['strings'];
      strings = raw is Map
          ? {
              for (final entry in raw.entries)
                if (entry.value is String)
                  entry.key.toString(): entry.value as String,
            }
          : {};
    } catch (e) {
      debugPrint('CustomLanguage.load error: $e');
    }
  }

  Future<void> save({
    required String name,
    required Map<String, String> strings,
  }) async {
    final cleaned = <String, String>{
      for (final entry in strings.entries)
        if (entry.value.trim().isNotEmpty) entry.key: entry.value,
    };
    final file = await _file();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'name': name.trim(),
        'strings': cleaned,
      }),
      flush: true,
    );
    await temp.rename(file.path);
    this.name = name.trim();
    this.strings = cleaned;
    revision.value++;
  }
}
