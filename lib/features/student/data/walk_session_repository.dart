import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';

class WalkSessionRepository {
  WalkSessionRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> createInviteSession({
    required String studentId,
    required String companionContactId,
    required String destination,
  }) async {
    return await _client
        .from('walk_sessions')
        .insert({
          'student_id': studentId,
          'mode': 'invite_companion',
          'companion_contact_id': companionContactId,
          'destination': destination,
          'status': 'active',
          'started_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
  }

  Future<Map<String, dynamic>> createTimerSession({
    required String studentId,
    required String destination,
    required int timerMinutes,
    String? startLocationText,
    double? startLat,
    double? startLng,
    List<String> monitorContactIds = const [],
  }) async {
    return await _client
        .from('walk_sessions')
        .insert({
          'student_id': studentId,
          'mode': 'self_monitored',
          'destination': destination,
          'timer_minutes': timerMinutes,
          'start_location_text': startLocationText,
          'start_lat': startLat,
          'start_lng': startLng,
          'monitor_contact_ids': monitorContactIds,
          'status': 'active',
          'started_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
  }

  Future<void> extendSession(String sessionId, int extraMinutes) async {
    final row = await _client
        .from('walk_sessions')
        .select('extended_minutes')
        .eq('session_id', sessionId)
        .single();
    final current = (row['extended_minutes'] as int?) ?? 0;
    await _client
        .from('walk_sessions')
        .update({'extended_minutes': current + extraMinutes})
        .eq('session_id', sessionId);
  }

  Future<void> markArrived(String sessionId) async {
    await _client
        .from('walk_sessions')
        .update({
          'status': 'arrived',
          'ended_at': DateTime.now().toIso8601String(),
        })
        .eq('session_id', sessionId);
  }

  Future<void> markCheckInMissed(String sessionId) async {
    await _client
        .from('walk_sessions')
        .update({'status': 'check_in_missed'})
        .eq('session_id', sessionId);
  }

  /// Missed check-in with no response within 5 more minutes escalates into
  /// a real panic alert (scope.md §5 "Walk With Me — self-monitored").
  /// The alert row itself is created by [ActiveSosScreen] (single source
  /// of truth for alert creation); this just links it back.
  Future<void> linkEscalatedAlert({
    required String sessionId,
    required String alertId,
  }) async {
    await _client
        .from('walk_sessions')
        .update({'status': 'escalated_alert', 'escalated_alert_id': alertId})
        .eq('session_id', sessionId);
  }
}
