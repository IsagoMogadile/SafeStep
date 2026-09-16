import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';

const openAlertStatuses = ['new', 'acknowledged', 'dispatched'];
const closedAlertStatuses = ['resolved', 'false_alarm_verify'];

/// Responder-side alert access, matching docs/prototype.html's rp-* screens
/// (scope.md §6). Queries go through `alert_recipients` (the fan-out
/// table) filtered to this responder's own rows, rather than the `alerts`
/// table directly — a responder should only ever see alerts they were
/// actually notified about.
class ResponderRepository {
  ResponderRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchSelf(String userId) {
    return _client
        .from('responders')
        .select('responder_id, full_name, organization, coverage_zone_id, zones(name)')
        .eq('user_id', userId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> fetchOpenAlerts(String responderId) async {
    final rows = await _client
        .from('alert_recipients')
        .select('acknowledged_at, alerts!inner(*, students(full_name), zones(name))')
        .eq('responder_id', responderId)
        .filter('alerts.status', 'in', '(${openAlertStatuses.join(',')})')
        .order('notified_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> fetchResolvedAlerts(String responderId) async {
    final rows = await _client
        .from('alert_recipients')
        .select('alerts!inner(*, students(full_name))')
        .eq('responder_id', responderId)
        .filter('alerts.status', 'in', '(${closedAlertStatuses.join(',')})')
        .order('notified_at', ascending: false)
        .limit(30);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> acknowledge(String alertId, String responderId) async {
    await _client
        .from('alerts')
        .update({'status': 'acknowledged'})
        .eq('alert_id', alertId)
        .eq('status', 'new');
    await _client
        .from('alert_recipients')
        .update({'acknowledged_at': DateTime.now().toUtc().toIso8601String()})
        .eq('alert_id', alertId)
        .eq('responder_id', responderId);
  }

  Future<void> dispatch(String alertId) async {
    await _client.from('alerts').update({'status': 'dispatched'}).eq('alert_id', alertId);
  }

  Future<void> flagFalseAlarm(String alertId) async {
    await _client
        .from('alerts')
        .update({'status': 'false_alarm_verify'})
        .eq('alert_id', alertId);
  }

  Future<void> resolveWithReport(String alertId, String notes) async {
    await _client
        .from('alerts')
        .update({
          'status': 'resolved',
          'responder_notes': notes,
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('alert_id', alertId);
  }
}
