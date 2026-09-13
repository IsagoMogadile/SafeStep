import 'package:shared_preferences/shared_preferences.dart';

/// Misuse-prevention gate for the loud SOS button: no more than 3
/// triggers in any rolling 10-minute window; the attempt that would be
/// the 4th is blocked outright and starts a 1-hour SOS ban on this
/// device. Local-only (SharedPreferences), same pattern as the silent
/// alert's cooldown — this is a device-level throttle, not a
/// server-enforced one, which is the right tradeoff for a hackathon
/// prototype's misuse-handling story (scope.md / hackathon brief §7).
class SosRateLimitPrefs {
  SosRateLimitPrefs._();

  static const _triggersKey = 'sos_trigger_timestamps';
  static const _bannedUntilKey = 'sos_banned_until';
  static const _window = Duration(minutes: 10);
  static const _maxInWindow = 3;
  static const banDuration = Duration(hours: 1);

  /// Non-null (and in the future) if a ban is currently active.
  static Future<DateTime?> bannedUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_bannedUntilKey);
    if (millis == null) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(millis);
    return until.isAfter(DateTime.now()) ? until : null;
  }

  /// Call exactly once, right when a completed hold is about to fire a
  /// real alert. Returns null if this trigger is allowed (and records
  /// it). Returns the new ban-until time if this attempt was the 4th
  /// within the window and got blocked instead.
  static Future<DateTime?> checkAndRecord() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final existingBanMillis = prefs.getInt(_bannedUntilKey);
    if (existingBanMillis != null) {
      final until = DateTime.fromMillisecondsSinceEpoch(existingBanMillis);
      if (until.isAfter(now)) return until;
    }

    final raw = prefs.getStringList(_triggersKey) ?? const [];
    final recent = raw
        .map(DateTime.parse)
        .where((t) => now.difference(t) < _window)
        .toList();

    if (recent.length >= _maxInWindow) {
      final until = now.add(banDuration);
      await prefs.setInt(_bannedUntilKey, until.millisecondsSinceEpoch);
      await prefs.setStringList(_triggersKey, const []);
      return until;
    }

    recent.add(now);
    await prefs.setStringList(
      _triggersKey,
      recent.map((t) => t.toIso8601String()).toList(),
    );
    return null;
  }
}
