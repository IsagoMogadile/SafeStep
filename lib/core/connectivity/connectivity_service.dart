import 'package:connectivity_plus/connectivity_plus.dart';

/// scope.md §5 "Offline fallback": a tiered degrade when there's no data
/// connection. `connectivity_plus` only reports whether a network
/// *interface* is connected (e.g. Wi-Fi with no internet still reads
/// "connected"), so this isn't a perfect signal — but it's the same
/// tradeoff every offline-aware mobile app makes, and it's enough to
/// choose between "try the real alert" and "fall back to a phone call"
/// without waiting for a slow request to time out first.
class ConnectivityService {
  ConnectivityService._();

  static Future<bool> hasConnection() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
