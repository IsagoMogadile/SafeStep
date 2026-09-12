import 'package:geolocator/geolocator.dart';

/// Thin wrapper around geolocator for the app's "use current location"
/// affordances (reports, walk sessions). Returns null rather than
/// throwing when location isn't available, so callers can fall back to
/// manual entry instead of crashing.
class LocationService {
  LocationService._();

  static Future<Position?> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
