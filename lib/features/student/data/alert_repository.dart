import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/location/location_service.dart';
import '../../../core/supabase/supabase_service.dart';

/// Zone-based routing (scope.md §3) would need a real zone lookup from
/// the captured lat/lng — that lookup isn't wired yet, so alerts still
/// carry `zone_id: null` even though real coordinates are captured. The
/// responder-side alert feed shows all open alerts rather than filtering
/// by coverage zone until that's in place.
class AlertRepository {
  AlertRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  /// Creates the alert, then fans it out to every active, activated
  /// responder and every one of the student's trusted contacts as
  /// `alert_recipients` rows — this is what makes "every responder
  /// covering a zone is notified, whoever acknowledges first wins"
  /// (scope.md §3) actually have data to work with. Since zone lookup
  /// isn't wired, this fans out to *all* active responders rather than
  /// zone-scoped ones.
  Future<Map<String, dynamic>> createAlert({
    required String studentId,
    required String alertType,
  }) async {
    // Best-effort — a slow or denied location fix should never block
    // sending the alert itself.
    final position = await LocationService.getCurrentLocation();

    final alert = await _client
        .from('alerts')
        .insert({
          'student_id': studentId,
          'alert_type': alertType,
          'status': 'new',
          'lat': position?.latitude,
          'lng': position?.longitude,
          'triggered_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    final alertId = alert['alert_id'] as String;

    try {
      final responders = await _client
          .from('responders')
          .select('responder_id')
          .eq('status', 'active')
          .eq('activation_status', 'active');
      final contacts = await _client
          .from('trusted_contacts')
          .select('contact_id')
          .eq('student_id', studentId);

      final recipients = [
        ...responders.map(
          (r) => {
            'alert_id': alertId,
            'recipient_type': 'responder',
            'responder_id': r['responder_id'],
          },
        ),
        ...contacts.map(
          (c) => {
            'alert_id': alertId,
            'recipient_type': 'trusted_contact',
            'contact_id': c['contact_id'],
          },
        ),
      ];
      if (recipients.isNotEmpty) {
        await _client.from('alert_recipients').insert(recipients);
      }
    } catch (_) {
      // Best-effort fan-out: the alert itself is already saved, which is
      // the safety-critical part.
    }

    return alert;
  }

  Future<void> markFalseAlarm(String alertId) async {
    await _client
        .from('alerts')
        .update({'status': 'false_alarm_verify'})
        .eq('alert_id', alertId);
  }

  Future<void> resolve(String alertId) async {
    await _client
        .from('alerts')
        .update({
          'status': 'resolved',
          'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('alert_id', alertId);
  }
}
