import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/notifications/notification_service.dart';
import 'walk_session_repository.dart';

/// Polls two separate things for the signed-in student, since they get
/// different treatment:
///
/// 1. Accepted "Invite a Companion" journeys, which feed the trackable
///    "Journeys You Track" list/badge via [onChange] — this is the one
///    case actually built around live tracking.
/// 2. "Monitor My Journey" picks, which only ever raise a one-shot local
///    notification the moment a new one starts — no list, no badge, no
///    live map. Being picked as a monitor for someone's self-monitored
///    walk means "you'll be told if this starts," not "you can watch it."
///
/// Same polling approach as AlertStatusPoller, since this app has no
/// realtime/push mechanism to notify another student's device instantly.
/// Accepted companion journeys don't get a notification: accepting was
/// already that student's own action, so a follow-up "X started a
/// journey" right after would just echo what they already know — they're
/// taken straight to the tracking screen instead.
class MonitoredJourneyPoller {
  MonitoredJourneyPoller({required this.studentId, this.onChange});

  final String studentId;

  /// Called whenever the trackable (Invite a Companion) list changes, so
  /// the caller can refresh a badge count.
  final VoidCallback? onChange;

  final _repository = WalkSessionRepository();
  Timer? _timer;
  final _knownTrackableIds = <String>{};
  final _knownSelfMonitoredIds = <String>{};
  bool _seeded = false;

  void start() {
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
  }

  void stop() => _timer?.cancel();

  Future<void> _poll() async {
    List<Map<String, dynamic>> trackable;
    List<Map<String, dynamic>> selfMonitored;
    try {
      trackable = await _repository.fetchActiveMonitoredSessions(studentId);
      selfMonitored = await _repository.fetchSelfMonitoredNotifiableSessions(studentId);
    } catch (_) {
      return; // offline or transient error — just try again next tick
    }

    final currentTrackableIds = trackable.map((s) => s['session_id'] as String).toSet();
    final currentSelfMonitoredIds = selfMonitored.map((s) => s['session_id'] as String).toSet();

    if (_seeded) {
      final newSelfMonitoredIds = currentSelfMonitoredIds.difference(_knownSelfMonitoredIds);
      for (final session in selfMonitored.where((s) => newSelfMonitoredIds.contains(s['session_id']))) {
        await _notify(session);
      }
      if (!setEquals(currentTrackableIds, _knownTrackableIds)) onChange?.call();
    }

    _knownTrackableIds
      ..clear()
      ..addAll(currentTrackableIds);
    _knownSelfMonitoredIds
      ..clear()
      ..addAll(currentSelfMonitoredIds);
    _seeded = true;
  }

  Future<void> _notify(Map<String, dynamic> session) async {
    final name = (session['students'] as Map?)?['full_name'] as String? ?? 'Someone';
    final destination = session['destination'] as String? ?? 'their destination';
    await NotificationService.instance.showMonitoredJourneyNotification(
      title: 'Monitoring $name',
      body: '$name started a journey to $destination.',
    );
  }
}
