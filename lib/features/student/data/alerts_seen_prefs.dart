import 'package:shared_preferences/shared_preferences.dart';

/// Local-only "last seen safety alerts" timestamp, used to badge the
/// header bell icon (scope.md §5 "Alerts are reached via a bell icon in
/// the header") with an unread count. There's no per-student read-state
/// column in `safety_broadcasts` — this is a lightweight on-device
/// tracker, same pattern as [OnboardingPrefs] and the silent-alert
/// cooldown timestamp.
class AlertsSeenPrefs {
  AlertsSeenPrefs._();

  static const _key = 'safety_alerts_last_seen';

  static Future<DateTime?> lastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_key);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<void> markSeenNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, DateTime.now().millisecondsSinceEpoch);
  }
}
