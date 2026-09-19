import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/offline/pending_alert_queue.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../active_sos_screen.dart';
import '../call_security_screen.dart';

/// Shared by every entry point that ends a [SosHoldButton] hold (Home tab,
/// the home-screen widget quick-launch) so they degrade offline the same
/// way rather than drifting into two copies.
///
/// scope.md §5 "Offline fallback": with no data connection there's no way
/// to write a real `alerts` row *right now*, so SOS degrades to the same
/// always-works phone call. It's also queued in [PendingAlertQueue] so
/// the real alert (and its responder fan-out) still gets created once
/// the connection comes back — the phone call is what actually keeps the
/// student safe in the moment; the queue is just so the incident doesn't
/// go permanently unrecorded.
Future<void> handleSosActivated(BuildContext context, {String alertType = 'panic'}) async {
  final online = await ConnectivityService.hasConnection();
  if (!context.mounted) return;
  if (!online) {
    // Get to the call screen the instant the hold completes — a GPS fix
    // can take several seconds with no network-assisted A-GPS (up to
    // LocationService's own 10s timeout), and making the student wait on
    // that before anything happens is exactly the "glitch"/freeze this
    // used to cause. Capturing the location and queueing the record for
    // later sync is best-effort and never blocks getting to the phone
    // call, which is the actual safety-critical part.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CallSecurityScreen(offlineNotice: true),
      ),
    );
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId != null) {
      unawaited(_queuePendingSosAlert(userId, alertType));
    }
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const ActiveSosScreen()),
  );
}

Future<void> _queuePendingSosAlert(String userId, String alertType) async {
  final position = await LocationService.getCurrentLocation();
  await PendingAlertQueue.add(
    studentId: userId,
    alertType: alertType,
    lat: position?.latitude,
    lng: position?.longitude,
    triggeredAt: DateTime.now(),
  );
}
