import 'dart:async';

import '../../../core/notifications/notification_service.dart';
import '../../../core/supabase/supabase_service.dart';

/// Polls this student's own alerts for a status change (Acknowledged /
/// Dispatched / Resolved / False Alarm – Verify) and raises a local
/// notification scoped to just this student — the same "Alerts" bell
/// icon already used for admin safety broadcasts also lists these, see
/// AlertsScreen. Polling rather than Supabase Realtime, matching this
/// codebase's existing pattern for the companion-invite accept flow
/// (walk_active_screen.dart) rather than introducing a new mechanism.
class AlertStatusPoller {
  AlertStatusPoller({required this.studentId});

  final String studentId;
  Timer? _timer;
  final Map<String, String> _lastKnownStatus = {};
  bool _seeded = false;

  void start() {
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
  }

  void stop() => _timer?.cancel();

  Future<void> _poll() async {
    List<Map<String, dynamic>> rows;
    try {
      rows = await SupabaseService.client
          .from('alerts')
          .select('alert_id, status, alert_type')
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .limit(10);
    } catch (_) {
      return; // offline or transient error — just try again next tick
    }

    for (final row in rows) {
      final id = row['alert_id'] as String;
      final status = row['status'] as String;
      final previous = _lastKnownStatus[id];
      if (_seeded && previous != null && previous != status) {
        await _notify(status);
      }
      _lastKnownStatus[id] = status;
    }
    _seeded = true;
  }

  Future<void> _notify(String status) async {
    final body = switch (status) {
      'acknowledged' => 'A responder has acknowledged your alert.',
      'dispatched' => 'A responder has been dispatched to you.',
      'resolved' => 'Your alert has been marked resolved.',
      'false_alarm_verify' =>
        'Your alert is marked as a possible false alarm — security will still check in.',
      _ => 'Your alert status changed.',
    };
    await NotificationService.instance.showAlertStatusNotification(
      title: 'SafeStep alert update',
      body: body,
    );
  }
}
