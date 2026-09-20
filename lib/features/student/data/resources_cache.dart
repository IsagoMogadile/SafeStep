import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local cache of published safety resources — same cache-then-refresh,
/// staleness-banner-on-failure pattern as ZonesCache/AlertsCache, so
/// this screen doesn't go blank (or error out) with no connection.
class ResourcesCache {
  ResourcesCache._();

  static const _key = 'cached_resources';

  static Future<void> save(List<Map<String, dynamic>> resources) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'data': resources,
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
