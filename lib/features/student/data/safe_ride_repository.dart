import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';

/// "Safe Ride": look up a lift-share/taxi's number plate against
/// on-file offense records before getting in, and report a vehicle
/// immediately if something goes wrong. Real table, real data — see
/// safe_ride_risk.dart for how a plate's offense history turns into a
/// green/orange/red rating.
class SafeRideRepository {
  SafeRideRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  String normalizePlate(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Null means no record at all for this plate — not the same as "clean
  /// record" (which is a real record with zero/minor offenses only).
  Future<Map<String, dynamic>?> lookupPlate(String plate) {
    return _client
        .from('vehicle_records')
        .select('*, vehicle_offenses(*)')
        .eq('plate_number', normalizePlate(plate))
        .maybeSingle();
  }

  /// Reports a vehicle right away: finds or creates the plate's record,
  /// then adds a new offense against it sourced from this student. Takes
  /// effect immediately (no moderation queue) — `source` and
  /// `reported_by_student_id` keep the report attributable and distinct
  /// from seeded/admin-entered offenses.
  Future<void> reportVehicle({
    required String plate,
    required String studentId,
    required String description,
    String? driverName,
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleColour,
  }) async {
    final normalized = normalizePlate(plate);
    final existing = await _client
        .from('vehicle_records')
        .select('record_id')
        .eq('plate_number', normalized)
        .maybeSingle();

    String recordId;
    if (existing != null) {
      recordId = existing['record_id'] as String;
    } else {
      final inserted = await _client
          .from('vehicle_records')
          .insert({
            'plate_number': normalized,
            'driver_name': (driverName?.trim().isNotEmpty ?? false)
                ? driverName!.trim()
                : 'Unknown driver',
            'vehicle_make': vehicleMake,
            'vehicle_model': vehicleModel,
            'vehicle_colour': vehicleColour,
          })
          .select('record_id')
          .single();
      recordId = inserted['record_id'] as String;
    }

    await _client.from('vehicle_offenses').insert({
      'record_id': recordId,
      'offense_type': description,
      'severity': 'moderate',
      'source': 'student_report',
      'reported_by_student_id': studentId,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
