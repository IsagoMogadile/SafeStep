import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Free, no-API-key route planning: Nominatim (OpenStreetMap's public
/// geocoder) turns a free-text destination into coordinates, and OSRM's
/// public demo routing server turns two coordinates into a real
/// road/footpath-following route. Used for Walk With Me's "the app plans
/// a route" requirement once a companion accepts an invite.
///
/// Both are shared public demo services with fair-use rate limits (~1
/// request/second) — fine for a hackathon prototype's demo traffic, not
/// meant for production scale.
class RouteService {
  RouteService._();

  static const _userAgent = 'SafeStep-Hackathon-Prototype/1.0';
  static const _straightLineDistance = Distance();
  // Real paths aren't straight lines — pad the raw distance so a
  // straight-line fallback estimate doesn't undershoot a routed one.
  static const _straightLineDetourFactor = 1.3;
  static const _walkingKmh = 4.5;
  static const _drivingKmh = 30.0;

  /// Appending a locality hint disambiguates a short query like "Library"
  /// (otherwise Nominatim can match a same-named place anywhere in the
  /// world), but it backfires for a destination that's already a full
  /// address — e.g. one picked on the map and reverse-geocoded — where
  /// the locality then appears twice in the query and Nominatim matches
  /// nothing at all. Try the disambiguated query first, and fall back to
  /// the query as typed if that comes back empty.
  static Future<LatLng?> geocode(String query) async {
    final hinted = await _search('$query, Summerstrand, Gqeberha, South Africa');
    if (hinted != null) return hinted;
    return _search(query);
  }

  static Future<LatLng?> _search(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
    });
    try {
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final results = jsonDecode(response.body) as List;
      if (results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      return LatLng(
        double.parse(first['lat'] as String),
        double.parse(first['lon'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  /// Turns a tapped map point back into a human-readable address, so a
  /// destination picked on the map fills the same free-text field that
  /// [geocode] later reads back — no separate lat/lng storage needed.
  static Future<String?> reverseGeocode(LatLng point) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '${point.latitude}',
      'lon': '${point.longitude}',
      'format': 'json',
    });
    try {
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Returns the route as a polyline (list of points), or null if
  /// routing failed — callers should fall back to a straight line.
  static Future<List<LatLng>?> fetchWalkingRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/foot/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson',
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') return null;
      final routes = body['routes'] as List;
      if (routes.isEmpty) return null;
      final coords = (routes.first['geometry']['coordinates'] as List)
          .map((c) => LatLng((c as List)[1] as double, c[0] as double))
          .toList();
      return coords;
    } catch (_) {
      return null;
    }
  }

  /// Estimated travel time in whole minutes (rounded up). `profile` is
  /// `'foot'` for walking (Safe Walks) or `'driving'` for a car (Safe
  /// Ride) — OSRM's public demo server already returns a `duration`
  /// (seconds) alongside the route, we just weren't reading it before.
  /// `overview=false` skips fetching the full geometry, which this
  /// doesn't need.
  ///
  /// If OSRM's shared demo server is unreachable or rate-limited, this
  /// falls back to straight-line distance between the two points at a
  /// typical speed for the profile, rather than giving up on an estimate
  /// entirely — geocoding still succeeded at that point, so both
  /// coordinates are known regardless of whether routing is.
  static Future<int?> estimateDurationMinutes(
    LatLng origin,
    LatLng destination, {
    String profile = 'foot',
  }) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/$profile/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=false',
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['code'] == 'Ok') {
          final routes = body['routes'] as List;
          if (routes.isNotEmpty) {
            final seconds = (routes.first['duration'] as num).toDouble();
            return (seconds / 60).ceil();
          }
        }
      }
    } catch (_) {
      // fall through to the straight-line estimate below
    }

    final meters = _straightLineDistance(origin, destination) * _straightLineDetourFactor;
    final kmh = profile == 'driving' ? _drivingKmh : _walkingKmh;
    final minutes = (meters / 1000 / kmh * 60).ceil();
    return minutes < 1 ? 1 : minutes;
  }
}
