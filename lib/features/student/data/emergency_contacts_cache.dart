import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local cache of `emergency_contacts` so Call Security still shows real
/// numbers with zero data connection (scope.md §5 "Offline fallback").
/// Refreshed opportunistically every time the list loads online.
class EmergencyContactsCache {
  EmergencyContactsCache._();

  static const _key = 'cached_emergency_contacts';

  static Future<void> save(List<Map<String, dynamic>> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(contacts));
  }

  static Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.cast<Map<String, dynamic>>();
  }
}
