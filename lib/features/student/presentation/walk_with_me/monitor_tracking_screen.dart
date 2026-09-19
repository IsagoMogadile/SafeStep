import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../data/walk_session_repository.dart';
import 'widgets/journey_tracking_map.dart';

/// A monitor's live view of a single "Monitor My Journey" session: polls
/// for the walker's latest position and status, and closes itself the
/// moment the walker marks arrived — nothing left to track at that point.
class MonitorTrackingScreen extends StatefulWidget {
  const MonitorTrackingScreen({super.key, required this.session});

  final Map<String, dynamic> session;

  @override
  State<MonitorTrackingScreen> createState() => _MonitorTrackingScreenState();
}

class _MonitorTrackingScreenState extends State<MonitorTrackingScreen> {
  final _repository = WalkSessionRepository();
  Timer? _pollTimer;
  late Map<String, dynamic> _session;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final fresh = await _repository.fetchSession(_session['session_id'] as String);
    if (!mounted) return;
    setState(() => _session = fresh);
    if (fresh['status'] == 'arrived' && !_closing) {
      _closing = true;
      _pollTimer?.cancel();
      final name = (fresh['students'] as Map?)?['full_name'] as String? ?? 'They';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name arrived safely — closing this journey.')),
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = (_session['students'] as Map?)?['full_name'] as String? ?? 'Student';
    final destination = _session['destination'] as String? ?? '';
    final currentLat = _session['current_lat'] as num?;
    final currentLng = _session['current_lng'] as num?;
    final status = _session['status'] as String? ?? 'active';

    return Scaffold(
      appBar: AppBar(title: Text('Tracking $name')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(destination, style: Theme.of(context).textTheme.titleSmall),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (currentLat == null || currentLng == null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.hourglass_top),
                      SizedBox(width: 12),
                      Expanded(child: Text('Waiting for their first location update…')),
                    ],
                  ),
                )
              else
                JourneyTrackingMap(
                  currentPosition: LatLng(currentLat.toDouble(), currentLng.toDouble()),
                  destinationQuery: destination,
                ),
              if (status == 'check_in_missed' || status == 'escalated_alert') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          status == 'escalated_alert'
                              ? "$name missed their check-in and this has escalated to a full alert."
                              : "$name missed their check-in.",
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
