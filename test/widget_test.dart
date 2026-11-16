import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asko_pdf/l10n/app_localizations.dart';
import 'package:asko_pdf/services/custom_language.dart';

void main() {
  tearDown(() {
    CustomLanguage.instance.name = '';
    CustomLanguage.instance.strings = {};
  });

  test('English texts come from the built-in table', () {
    final l10n = AppLocalizations(const Locale('en'));
    expect(l10n.settings, 'Settings');
  });

  test('your language uses its own lines and falls back to English', () {
    CustomLanguage.instance.strings = {
      'settings': 'Einstellungen',
      'about': '  ',
    };
    final l10n = AppLocalizations(CustomLanguage.locale);
    expect(l10n.settings, 'Einstellungen');
    expect(l10n.about, 'About');
  });

  test('English stays English while your language exists', () {
    CustomLanguage.instance.strings = {'settings': 'Einstellungen'};
    expect(AppLocalizations(const Locale('en')).settings, 'Settings');
  });
}
