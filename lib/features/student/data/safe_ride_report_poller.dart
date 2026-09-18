import 'dart:async';

import '../../../core/notifications/notification_service.dart';
import 'safe_ride_repository.dart';

/// Mirrors AlertStatusPoller, but for this student's own Safe Ride
/// vehicle reports — notifies when an admin has approved or rejected a
/// report they submitted (feedback: "report received, report resolved").
/// "Received" is confirmed immediately in the UI on submit; this covers
/// "resolved".
class SafeRideReportPoller {
  SafeRideReportPoller({required this.studentId});

  final String studentId;
  final _repository = SafeRideRepository();
  Timer? _timer;
  final Map<String, String> _lastKnownStatus = {};
  bool _seeded = false;

  void start() {
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _poll());
  }

  void stop() => _timer?.cancel();

  Future<void> _poll() async {
    List<Map<String, dynamic>> rows;
    try {
      rows = await _repository.fetchOwnReports(studentId);
    } catch (_) {
      return;
    }

    for (final row in rows) {
      final id = row['offense_id'] as String;
      final status = row['status'] as String;
      final previous = _lastKnownStatus[id];
      if (_seeded && previous == 'pending_review' && previous != status) {
        final plate = (row['vehicle_records'] as Map?)?['plate_number'] as String?;
        await NotificationService.instance.showAlertStatusNotification(
          title: 'Safe Ride report resolved',
          body: status == 'approved'
              ? 'Your report on ${plate ?? 'a vehicle'} was reviewed and approved.'
              : 'Your report on ${plate ?? 'a vehicle'} was reviewed and closed.',
        );
      }
      _lastKnownStatus[id] = status;
    }
    _seeded = true;
  }
}
