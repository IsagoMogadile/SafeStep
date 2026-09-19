import 'package:shared_preferences/shared_preferences.dart';

/// Local-only "swiped away" ids for a student's own alerts in
/// [AlertsScreen]. Swiping one away only hides it from this device's feed
/// — the underlying `alerts` row is left untouched, since admins still
/// need it for their own alert history and audit trail. Same
/// local/device-scoped-state pattern as [AlertsSeenPrefs]; deliberately
/// doesn't cover `safety_broadcasts`, which aren't dismissible at all.
class DismissedAlertsPrefs {
  DismissedAlertsPrefs._();

  static const _key = 'dismissed_personal_alert_ids';

  static Future<Set<String>> all() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  static Future<void> dismiss(String alertId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_key) ?? const []).toSet()..add(alertId);
    await prefs.setStringList(_key, ids.toList());
  }
}
