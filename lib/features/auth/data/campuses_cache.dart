import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local cache of the campuses list — static reference data (four NMU
/// Summerstrand campuses, effectively never changing) that was being
/// fetched fresh from the network every single time the signup wizard or
/// profile-edit screen opened, with no reuse at all. Same
/// cache-then-refresh pattern as ZonesCache/AlertsCache/
/// EmergencyContactsCache, minus a staleness banner — there's no visible
/// "last updated" UI for a dropdown, so it isn't needed here.
class CampusesCache {
  CampusesCache._();

  static const _key = 'cached_campuses';

  static Future<void> save(List<Map<String, dynamic>> campuses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(campuses));
  }

  static Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.cast<Map<String, dynamic>>();
  }
}
