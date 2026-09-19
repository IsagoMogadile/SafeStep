import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_service.dart';
import 'walk_session_repository.dart';

/// Polls for journeys the signed-in student can watch live (both "Monitor
/// My Journey" sessions where they were picked as a monitor, and accepted
/// "Invite a Companion" journeys), and raises a local notification the
/// moment a new *monitored* one starts — same polling approach as
/// AlertStatusPoller, since this app has no realtime/push mechanism to
/// notify another student's device the instant a journey begins. Accepted
/// companion journeys don't get this notification: accepting was already
/// that student's own action, so a follow-up "X started a journey"
/// notification right after would just be a confusing echo of what they
/// already know — they're taken straight to the tracking screen instead.
class MonitoredJourneyPoller {
  MonitoredJourneyPoller({required this.studentId, this.onChange});

  final String studentId;

  /// Called whenever a new monitored journey appears or an existing one
  /// stops being active, so the caller can refresh a badge count.
  final VoidCallback? onChange;

  final _repository = WalkSessionRepository();
  Timer? _timer;
  final _knownSessionIds = <String>{};
  bool _seeded = false;

  void start() {
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
  }

  void stop() => _timer?.cancel();

  Future<void> _poll() async {
    List<Map<String, dynamic>> sessions;
    try {
      sessions = await _repository.fetchActiveMonitoredSessions(studentId);
    } catch (_) {
      return; // offline or transient error — just try again next tick
    }

    final currentIds = sessions.map((s) => s['session_id'] as String).toSet();
    final newIds = currentIds.difference(_knownSessionIds);
    if (_seeded && newIds.isNotEmpty) {
      final newSessions = sessions.where(
        (s) => newIds.contains(s['session_id']) && s['mode'] == 'self_monitored',
      );
      for (final session in newSessions) {
        await _notify(session);
      }
    }
    if (_seeded && !setEquals(currentIds, _knownSessionIds)) onChange?.call();

    _knownSessionIds
      ..clear()
      ..addAll(currentIds);
    _seeded = true;
  }

  Future<void> _notify(Map<String, dynamic> session) async {
    final name = (session['students'] as Map?)?['full_name'] as String? ?? 'Someone';
    final destination = session['destination'] as String? ?? 'their destination';
    await NotificationService.instance.showMonitoredJourneyNotification(
      title: 'Monitoring $name',
      body: '$name started a journey to $destination — tap to track them.',
    );
  }
}
