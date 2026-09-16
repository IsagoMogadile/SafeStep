import 'package:flutter/material.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../active_sos_screen.dart';
import '../call_security_screen.dart';

/// Shared by every entry point that ends a [SosHoldButton] hold (Home tab,
/// the home-screen widget quick-launch) so they degrade offline the same
/// way rather than drifting into two copies.
///
/// scope.md §5 "Offline fallback": with no data connection there's no way
/// to write a real `alerts` row, so SOS degrades to the same always-works
/// phone call rather than holding for 3 seconds only to silently fail.
Future<void> handleSosActivated(BuildContext context) async {
  final online = await ConnectivityService.hasConnection();
  if (!context.mounted) return;
  if (!online) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CallSecurityScreen(offlineNotice: true),
      ),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const ActiveSosScreen()),
  );
}
