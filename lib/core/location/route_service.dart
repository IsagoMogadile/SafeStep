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

  static Future<LatLng?> geocode(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': '$query, Summerstrand, Gqeberha, South Africa',
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
}
