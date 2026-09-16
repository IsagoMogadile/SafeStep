import 'package:shared_preferences/shared_preferences.dart';

/// Whether the student has opted in to requiring Face/Touch ID (or
/// device PIN as a fallback) to open SafeStep — off by default, a
/// per-device preference, same pattern as [ThemeController].
class BiometricLockPrefs {
  BiometricLockPrefs._();

  static const _key = 'biometric_lock_enabled';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}
