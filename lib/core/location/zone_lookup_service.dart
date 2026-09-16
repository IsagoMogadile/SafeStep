import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Zones only have a single lat/lng point each (no stored boundary
/// polygon), so "which zone is this alert in" is a nearest-point lookup
/// rather than a true point-in-polygon test — the right tradeoff for a
/// prototype without real GIS data.
class ZoneLookupService {
  ZoneLookupService._();

  static Future<String?> findNearestZoneId({
    required SupabaseClient client,
    required double lat,
    required double lng,
  }) async {
    final zones = await client.from('zones').select('zone_id, lat, lng');
    String? nearestId;
    double? nearestDistance;

    for (final zone in zones) {
      final zoneLat = zone['lat'] as num?;
      final zoneLng = zone['lng'] as num?;
      if (zoneLat == null || zoneLng == null) continue;

      final distance = _haversineMeters(
        lat,
        lng,
        zoneLat.toDouble(),
        zoneLng.toDouble(),
      );
      if (nearestDistance == null || distance < nearestDistance) {
        nearestDistance = distance;
        nearestId = zone['zone_id'] as String;
      }
    }

    return nearestId;
  }

  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
}
