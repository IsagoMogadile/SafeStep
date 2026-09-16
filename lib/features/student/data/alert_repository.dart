import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/location/location_service.dart';
import '../../../core/location/zone_lookup_service.dart';
import '../../../core/supabase/supabase_service.dart';

/// Zone-based routing (scope.md §3): a triggered alert's real lat/lng is
/// matched to the nearest `zones` row, and the fan-out notifies only
/// responders whose `coverage_zone_id` matches that zone — "every
/// responder covering a zone is notified simultaneously" — rather than
/// every active responder everywhere. If location wasn't available, or
/// the matched zone genuinely has no responders assigned to it, this
/// fails *open* (notifies every active responder) rather than silently
/// notifying no one — a safety alert should never go unseen because of
/// a zone-matching edge case.
class AlertRepository {
  AlertRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  /// Misuse-prevention gate (hackathon brief §7): no more than 3 panic
  /// triggers per student in any rolling 10 minutes; the 4th attempt is
  /// blocked and starts a 1-hour ban for *that student only*.
  ///
  /// This used to be tracked in SharedPreferences, which is scoped to
  /// the device, not the account — testing multiple student logins on
  /// one physical phone meant every account shared the same ban state,
  /// so one student's misuse blocked everyone else on that device too.
  /// Tracking it server-side, per student_id, off the student's own real
  /// `alerts` history fixes that (and can't be bypassed by reinstalling
  /// the app, unlike the old local version).
  ///
  /// Returns null if this attempt is allowed. Returns the ban-until time
  /// if the student is already banned, or if this attempt just triggered
  /// a fresh 1-hour ban.
  Future<DateTime?> checkSosGate(String studentId) async {
    final student = await _client
        .from('students')
        .select('sos_banned_until')
        .eq('student_id', studentId)
        .single();

    final bannedUntilRaw = student['sos_banned_until'] as String?;
    if (bannedUntilRaw != null) {
      final bannedUntil = DateTime.parse(bannedUntilRaw);
      if (bannedUntil.isAfter(DateTime.now())) return bannedUntil;
    }

    final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10));
    final recent = await _client
        .from('alerts')
        .select('alert_id')
        .eq('student_id', studentId)
        .eq('alert_type', 'panic')
        .gte('triggered_at', tenMinutesAgo.toIso8601String())
        .count(CountOption.exact);

    if (recent.count >= 3) {
      final until = DateTime.now().add(const Duration(hours: 1));
      await _client
          .from('students')
          .update({'sos_banned_until': until.toIso8601String()})
          .eq('student_id', studentId);
      return until;
    }

    return null;
  }

  /// Creates the alert, then fans it out to every zone-assigned, active,
  /// activated responder and every one of the student's trusted contacts
  /// as `alert_recipients` rows — this is what makes "every responder
  /// covering a zone is notified, whoever acknowledges first wins"
  /// (scope.md §3) actually have data to work with.
  Future<Map<String, dynamic>> createAlert({
    required String studentId,
    required String alertType,
  }) async {
    // Best-effort — a slow or denied location fix should never block
    // sending the alert itself.
    final position = await LocationService.getCurrentLocation();

    String? zoneId;
    if (position != null) {
      zoneId = await ZoneLookupService.findNearestZoneId(
        client: _client,
        lat: position.latitude,
        lng: position.longitude,
      );
    }

    final alert = await _client
        .from('alerts')
        .insert({
          'student_id': studentId,
          'alert_type': alertType,
          'status': 'new',
          'zone_id': zoneId,
          'lat': position?.latitude,
          'lng': position?.longitude,
          // .toUtc() matters: the DB session timezone is UTC, and treats
          // an offset-less timestamp as already being UTC — without this,
          // a local (non-UTC) DateTime silently gets stored hours off by
          // the device's own UTC offset.
          'triggered_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    final alertId = alert['alert_id'] as String;

    try {
      var responders = <Map<String, dynamic>>[];
      if (zoneId != null) {
        responders = List<Map<String, dynamic>>.from(
          await _client
              .from('responders')
              .select('responder_id')
              .eq('status', 'active')
              .eq('activation_status', 'active')
              .eq('coverage_zone_id', zoneId),
        );
      }
      // Fail open: no matched zone, or a matched zone with nobody
      // assigned to it, still needs to reach *somebody*.
      if (responders.isEmpty) {
        responders = List<Map<String, dynamic>>.from(
          await _client
              .from('responders')
              .select('responder_id')
              .eq('status', 'active')
              .eq('activation_status', 'active'),
        );
      }
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
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('alert_id', alertId);
  }
}
