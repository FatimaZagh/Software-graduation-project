import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's language choice across app restarts.
class LocalePreferences {
  LocalePreferences._();

  static const _kLocaleCode = 'app.localeCode';

  static Future<Locale> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocaleCode);
    if (code == 'ar') return const Locale('ar');
    return const Locale('en');
  }

  static Future<void> saveLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleCode, locale.languageCode);
  }
}
