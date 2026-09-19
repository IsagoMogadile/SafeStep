import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';

/// Every timestamp written here uses `.toUtc()` before serializing —
/// this database's session timezone is UTC, and it interprets any
/// offset-less ISO string as already being in that timezone. Without
/// `.toUtc()`, `DateTime.now().toIso8601String()` sends local wall-clock
/// digits with no timezone marker at all, which Postgres then reads as
/// UTC — silently shifting every stored instant by the device's UTC
/// offset. That's the exact root cause of "1 minute" journeys reading
/// back as hours: `started_at` got stored hours in the future (on a
/// UTC+2 device), so `deadline - now()` came out hours too large.
class WalkSessionRepository {
  WalkSessionRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> createInviteSession({
    required String studentId,
    required String companionContactId,
    required String destination,
    String? startLocationText,
    double? startLat,
    double? startLng,
  }) async {
    return await _client
        .from('walk_sessions')
        .insert({
          'student_id': studentId,
          'mode': 'invite_companion',
          'companion_contact_id': companionContactId,
          'destination': destination,
          'start_location_text': startLocationText,
          'start_lat': startLat,
          'start_lng': startLng,
          'status': 'active',
          'started_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
  }

  /// Re-fetches a single session — used to poll for the companion's
  /// acceptance (scope.md §5: "they must accept before the journey
  /// starts") since this app doesn't have a realtime subscription set up
  /// anywhere yet; a short poll is the simplest correct thing here.
  Future<Map<String, dynamic>> fetchSession(String sessionId) {
    return _client
        .from('walk_sessions')
        .select('*, students(full_name)')
        .eq('session_id', sessionId)
        .single();
  }

  /// Every `invite_companion` session where the signed-in student is the
  /// companion (their own `trusted_contacts` row, linked back to them,
  /// is the target) and hasn't accepted yet.
  Future<List<Map<String, dynamic>>> fetchPendingCompanionInvites(
    String companionStudentId,
  ) async {
    final myContactRows = await _client
        .from('trusted_contacts')
        .select('contact_id')
        .eq('linked_student_id', companionStudentId);
    final contactIds = myContactRows.map((r) => r['contact_id'] as String).toList();
    if (contactIds.isEmpty) return [];

    final rows = await _client
        .from('walk_sessions')
        .select('*, students(full_name)')
        .inFilter('companion_contact_id', contactIds)
        .eq('mode', 'invite_companion')
        .eq('status', 'active')
        .filter('companion_accepted_at', 'is', null);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Accepting also records the companion's own location and, when a
  /// meeting point could be computed (needs the walker's location too —
  /// see [CompanionInvitesScreen]), where the two of them will meet before
  /// continuing together to the real destination.
  Future<void> acceptCompanionInvite(
    String sessionId, {
    double? companionLat,
    double? companionLng,
    double? meetingLat,
    double? meetingLng,
  }) async {
    await _client
        .from('walk_sessions')
        .update({
          'companion_accepted_at': DateTime.now().toUtc().toIso8601String(),
          'companion_lat': ?companionLat,
          'companion_lng': ?companionLng,
          'meeting_lat': ?meetingLat,
          'meeting_lng': ?meetingLng,
        })
        .eq('session_id', sessionId);
  }

  /// The companion's live position while they walk to the meeting point —
  /// separate columns from [updateLocation] (the walker's), since both
  /// sides are moving independently until they meet up.
  Future<void> updateCompanionLocation({
    required String sessionId,
    required double lat,
    required double lng,
  }) async {
    await _client
        .from('walk_sessions')
        .update({
          'companion_lat': lat,
          'companion_lng': lng,
          'companion_location_updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('session_id', sessionId);
  }

  Future<void> markWalkerReachedMeeting(String sessionId) async {
    await _client
        .from('walk_sessions')
        .update({'walker_reached_meeting_at': DateTime.now().toUtc().toIso8601String()})
        .eq('session_id', sessionId);
  }

  Future<void> markCompanionReachedMeeting(String sessionId) async {
    await _client
        .from('walk_sessions')
        .update({'companion_reached_meeting_at': DateTime.now().toUtc().toIso8601String()})
        .eq('session_id', sessionId);
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
          'started_at': DateTime.now().toUtc().toIso8601String(),
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
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('session_id', sessionId);
  }

  Future<void> updateLocation({
    required String sessionId,
    required double lat,
    required double lng,
  }) async {
    await _client
        .from('walk_sessions')
        .update({
          'current_lat': lat,
          'current_lng': lng,
          'location_updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('session_id', sessionId);
  }

  /// Every active journey the signed-in student can currently watch live
  /// on a map: `self_monitored` sessions where they're one of the chosen
  /// monitors, plus `invite_companion` sessions where they're the
  /// companion and have already accepted — both linked via their own
  /// `trusted_contacts` row, same pattern as [fetchPendingCompanionInvites].
  Future<List<Map<String, dynamic>>> fetchActiveMonitoredSessions(
    String monitorStudentId,
  ) async {
    final myContactRows = await _client
        .from('trusted_contacts')
        .select('contact_id')
        .eq('linked_student_id', monitorStudentId);
    final contactIds = myContactRows.map((r) => r['contact_id'] as String).toList();
    if (contactIds.isEmpty) return [];

    final monitored = await _client
        .from('walk_sessions')
        .select('*, students(full_name)')
        .eq('mode', 'self_monitored')
        .eq('status', 'active')
        .overlaps('monitor_contact_ids', contactIds);

    final companionJourneys = await _client
        .from('walk_sessions')
        .select('*, students(full_name)')
        .eq('mode', 'invite_companion')
        .eq('status', 'active')
        .inFilter('companion_contact_id', contactIds)
        .not('companion_accepted_at', 'is', null);

    return [
      ...List<Map<String, dynamic>>.from(monitored),
      ...List<Map<String, dynamic>>.from(companionJourneys),
    ];
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
