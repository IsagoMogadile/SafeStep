import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/location/route_service.dart';
import '../../data/walk_session_repository.dart';
import 'companion_start_location_screen.dart';
import 'monitor_tracking_screen.dart';
import 'widgets/journey_tracking_map.dart';

/// Shown to the companion right after they accept an invite for which a
/// meeting point was computed — roughly midway between the walker's
/// location and the companion's own, at accept time. The companion walks
/// there first, pushing their own live location the same way the walker
/// already does; once both of them have arrived, this hands off to
/// [MonitorTrackingScreen] for the rest of the walker's journey to the
/// real destination.
class CompanionMeetingScreen extends StatefulWidget {
  const CompanionMeetingScreen({super.key, required this.session});

  final Map<String, dynamic> session;

  @override
  State<CompanionMeetingScreen> createState() => _CompanionMeetingScreenState();
}

class _CompanionMeetingScreenState extends State<CompanionMeetingScreen> {
  final _repository = WalkSessionRepository();
  Timer? _locationTimer;
  Timer? _pollTimer;
  late Map<String, dynamic> _session;
  late final LatLng _meetingPoint;
  LatLng? _companionPosition;
  bool _companionReached = false;
  bool _handedOff = false;
  bool _confirmingArrival = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _meetingPoint = LatLng(
      (_session['meeting_lat'] as num).toDouble(),
      (_session['meeting_lng'] as num).toDouble(),
    );
    _companionReached = _session['companion_reached_meeting_at'] != null;
    _pushCompanionLocation();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pushCompanionLocation(),
    );
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _poll());
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pushCompanionLocation() async {
    final position = await LocationService.getCurrentLocation();
    if (position == null || !mounted) return;
    final here = LatLng(position.latitude, position.longitude);
    final sessionId = _session['session_id'] as String;
    setState(() => _companionPosition = here);
    await _repository.updateCompanionLocation(
      sessionId: sessionId,
      lat: here.latitude,
      lng: here.longitude,
    );
    if (!_companionReached &&
        RouteService.distanceMeters(here, _meetingPoint) <=
            RouteService.meetingArrivalRadiusMeters) {
      _companionReached = true;
      await _repository.markCompanionReachedMeeting(sessionId);
    }
    _checkHandoff();
  }

  /// Lets the companion confirm arrival themselves instead of relying only
  /// on the automatic GPS-proximity check — useful when a phone's fix
  /// drifts just outside [RouteService.meetingArrivalRadiusMeters] even
  /// though they're actually there.
  Future<void> _confirmArrivedManually() async {
    if (_companionReached || _confirmingArrival) return;
    setState(() => _confirmingArrival = true);
    final sessionId = _session['session_id'] as String;
    await _repository.markCompanionReachedMeeting(sessionId);
    if (!mounted) return;
    setState(() {
      _companionReached = true;
      _confirmingArrival = false;
    });
    _checkHandoff();
  }

  Future<void> _poll() async {
    final fresh = await _repository.fetchSession(_session['session_id'] as String);
    if (!mounted) return;
    setState(() => _session = fresh);
    _checkHandoff();
  }

  void _checkHandoff() {
    if (_handedOff || !mounted) return;
    final walkerReached = _session['walker_reached_meeting_at'] != null;
    if (walkerReached && _companionReached) {
      _handedOff = true;
      _locationTimer?.cancel();
      _pollTimer?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MonitorTrackingScreen(session: _session)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = (_session['students'] as Map?)?['full_name'] as String? ?? 'your friend';

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Meet up first'),
          automaticallyImplyLeading: false,
        ),
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
                        Icon(Icons.handshake_outlined, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Walk to the meeting point to join $name — you'll continue "
                            "to their destination together from there.",
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_companionPosition == null)
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
                        Expanded(child: Text('Getting your location…')),
                      ],
                    ),
                  )
                else
                  JourneyTrackingMap(
                    currentPosition: _companionPosition!,
                    destinationPoint: _meetingPoint,
                    destinationIcon: Icons.handshake,
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _companionReached
                        ? colorScheme.tertiaryContainer.withValues(alpha: 0.5)
                        : colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(_companionReached ? Icons.check_circle : Icons.hourglass_top),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _companionReached
                              ? "You're at the meeting point — waiting for $name…"
                              : 'Head to the meeting point shown above.',
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_companionReached) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _confirmingArrival ? null : _confirmArrivedManually,
                    icon: _confirmingArrival
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : const Icon(Icons.handshake_outlined),
                    label: const Text('Arrived at Meeting Point'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Routes into the right screen for a companion re-opening an
/// `invite_companion` session — [CompanionStartLocationScreen] if they
/// haven't entered their own starting point yet, [CompanionMeetingScreen]
/// if a meeting point still needs to be reached by either side, otherwise
/// straight into the normal destination tracking.
Widget companionTrackingScreenFor(Map<String, dynamic> session) {
  final hasCompanionStart = session['companion_lat'] != null && session['companion_lng'] != null;
  if (!hasCompanionStart) {
    return CompanionStartLocationScreen(session: session);
  }
  final hasMeetingPoint = session['meeting_lat'] != null && session['meeting_lng'] != null;
  final bothAtMeetingPoint =
      session['walker_reached_meeting_at'] != null &&
      session['companion_reached_meeting_at'] != null;
  if (hasMeetingPoint && !bothAtMeetingPoint) {
    return CompanionMeetingScreen(session: session);
  }
  return MonitorTrackingScreen(session: session);
}
