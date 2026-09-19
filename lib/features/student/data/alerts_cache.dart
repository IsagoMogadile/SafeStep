import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local cache of the combined alerts feed `AlertsScreen` shows
/// (broadcasts, personal alert updates, Safe Ride report resolutions) —
/// same reasoning as `ZonesCache`: reading past alerts isn't a live
/// safety check, so a stale copy (clearly labelled as such) beats a
/// blank/error screen when offline.
class AlertsCache {
  AlertsCache._();

  static const _key = 'cached_alerts';

  static Future<void> save(List<Map<String, dynamic>> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'data': alerts,
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
