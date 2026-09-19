import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local cache of the danger-zone rows `MapTab` draws, so the map still
/// shows the last-known zones (with a staleness banner) instead of a
/// blank screen when there's no connection — unlike Safe Ride's plate
/// lookup, browsing a zone map isn't a live safety check, so a slightly
/// stale copy is still more useful than nothing.
class ZonesCache {
  ZonesCache._();

  static const _key = 'cached_zones';

  static Future<void> save(List<Map<String, dynamic>> zones) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'data': zones,
        'cached_at': DateTime.now().toIso8601String(),
      }),
    );
  }

  static Future<(List<Map<String, dynamic>>, DateTime?)> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return (<Map<String, dynamic>>[], null);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final data = (decoded['data'] as List).cast<Map<String, dynamic>>();
    final cachedAt = DateTime.tryParse(decoded['cached_at'] as String? ?? '');
    return (data, cachedAt);
  }
}
