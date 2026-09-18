import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The six languages SafeStep supports (docs/scope.md — multi-language
/// was previously parked, now in progress). `null` means "follow the
/// device's system language" when it's one of these, English otherwise.
const supportedLocales = [
  Locale('en'),
  Locale('af'),
  Locale('tn'), // Setswana
  Locale('ve'), // Tshivenda
  Locale('ts'), // Xitsonga
  Locale('zu'), // isiZulu
];

const localeNames = {
  'en': 'English',
  'af': 'Afrikaans',
  'tn': 'Setswana',
  've': 'Tshivenda',
  'ts': 'Xitsonga',
  'zu': 'isiZulu',
};

/// Persisted app-wide language choice, same `ValueNotifier` + SharedPreferences
/// pattern as ThemeController/FontScaleController.
class AppLocaleController extends ValueNotifier<Locale?> {
  AppLocaleController._() : super(null);

  static final instance = AppLocaleController._();

  static const _key = 'app_locale';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null) return;
    value = supportedLocales.firstWhere(
      (l) => l.languageCode == saved,
      orElse: () => const Locale('en'),
    );
  }

  Future<void> setLocale(Locale? locale) async {
    value = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
  }
}
