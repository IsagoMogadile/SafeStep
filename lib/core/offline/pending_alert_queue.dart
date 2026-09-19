import 'pending_sync_queue.dart';

/// A panic/silent alert that was triggered with no data connection. The
/// existing phone-call/SMS fallback (see `sos_activation.dart`,
/// `silent_alert_trigger.dart`) is what actually keeps the student safe
/// in the moment — this queue only exists so the real `alerts` row (and
/// its responder fan-out) still gets created retroactively once the
/// connection comes back, instead of the incident never being recorded
/// at all.
class PendingAlertQueue {
  PendingAlertQueue._();

  static final _queue = PendingSyncQueue('pending_alerts_queue');

  static Future<void> add({
    required String studentId,
    required String alertType,
    double? lat,
    double? lng,
    required DateTime triggeredAt,
  }) {
    return _queue.add({
      'local_id': triggeredAt.microsecondsSinceEpoch.toString(),
      'student_id': studentId,
      'alert_type': alertType,
      'lat': lat,
      'lng': lng,
      'triggered_at': triggeredAt.toUtc().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> loadAll() => _queue.loadAll();

  static Future<void> removeById(String localId) => _queue.removeById(localId);
}
