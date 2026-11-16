import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asko_pdf/services/custom_language.dart';

class SettingsService {
  static const String _keyCopyPageAsImage = 'copy_page_as_image_enabled';
  static const String _keyLanguage = 'app_language';
  static const String _keyZoomAnimation = 'zoom_animation_enabled';

  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(
    const Locale('en'),
  );

  Future<bool> getCopyPageAsImageEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCopyPageAsImage) ?? true;
  }

  Future<void> setCopyPageAsImageEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCopyPageAsImage, enabled);
  }

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyLanguage);
    if (saved == CustomLanguage.settingsCode &&
        CustomLanguage.instance.exists) {
      return saved!;
    }
    return 'en';
  }

  Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, languageCode);
    localeNotifier.value = _localeFor(languageCode);
  }

  Future<void> loadSavedLocale() async {
    await CustomLanguage.instance.load();
    localeNotifier.value = _localeFor(await getLanguage());
  }

  static Locale _localeFor(String languageCode) =>
      languageCode == CustomLanguage.settingsCode
          ? CustomLanguage.locale
          : const Locale('en');

  Future<bool> getZoomAnimationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyZoomAnimation) ?? true;
  }

  Future<void> setZoomAnimationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyZoomAnimation, enabled);
  }
}
