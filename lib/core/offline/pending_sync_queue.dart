import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Generic "Pending Sync" local queue: a JSON array of maps kept in
/// SharedPreferences, one instance per record type (alerts, incident
/// reports, trusted contacts). Deliberately not a real local database —
/// the offline surface in this app is a handful of simple record types,
/// not relational data that needs querying, so a new DB dependency
/// (sqflite/Hive) wouldn't earn its cost. Every queued item must carry
/// its own `local_id` (caller-assigned, e.g. a timestamp string) so it
/// can be removed again once [SyncManager] successfully replays it.
class PendingSyncQueue {
  PendingSyncQueue(this._key);

  final String _key;

  Future<List<Map<String, dynamic>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> add(Map<String, dynamic> item) async {
    final items = await loadAll();
    items.add(item);
    await _save(items);
  }

  Future<void> removeById(String localId) async {
    final items = await loadAll();
    items.removeWhere((item) => item['local_id'] == localId);
    await _save(items);
  }

  Future<void> _save(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items));
  }
}
