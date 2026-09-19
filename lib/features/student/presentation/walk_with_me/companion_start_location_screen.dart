import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/location/route_service.dart';
import '../../data/walk_session_repository.dart';
import 'companion_meeting_screen.dart';
import 'widgets/map_destination_picker_sheet.dart';

/// Shown right after the companion accepts an `invite_companion` invite.
/// The walker already entered their own starting point when they sent the
/// invite; this asks the companion for theirs, then computes the meeting
/// point roughly midway between the two starting points before handing
/// off to [CompanionMeetingScreen] to walk there.
class CompanionStartLocationScreen extends StatefulWidget {
  const CompanionStartLocationScreen({super.key, required this.session});

  final Map<String, dynamic> session;

  @override
  State<CompanionStartLocationScreen> createState() =>
      _CompanionStartLocationScreenState();
}

class _CompanionStartLocationScreenState
    extends State<CompanionStartLocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _startLocationController = TextEditingController();
  final _repository = WalkSessionRepository();

  double? _startLat;
  double? _startLng;
  bool _isLocating = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _startLocationController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    final position = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _isLocating = false;
      if (position != null) {
        _startLat = position.latitude;
        _startLng = position.longitude;
        _startLocationController.text =
            '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}';
      }
    });
    if (position == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't get your location — check location permission is allowed",
          ),
        ),
      );
    }
  }

  Future<void> _pickOnMap() async {
    final picked = await pickDestinationOnMap(
      context,
      title: 'Choose your starting point',
    );
    if (picked != null && mounted) {
      setState(() {
        _startLocationController.text = picked.label;
        _startLat = picked.point.latitude;
        _startLng = picked.point.longitude;
      });
    }
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_startLat == null || _startLng == null) {
        final resolved = await RouteService.geocode(
          _startLocationController.text.trim(),
        );
        if (resolved == null) {
          setState(() {
            _errorMessage =
                "Couldn't find that starting location — try Use current "
                'location, or pick it on the map instead.';
            _isSubmitting = false;
          });
          return;
        }
        _startLat = resolved.latitude;
        _startLng = resolved.longitude;
      }

      final sessionId = widget.session['session_id'] as String;
      final walkerLat = widget.session['start_lat'] as num?;
      final walkerLng = widget.session['start_lng'] as num?;

      LatLng? meetingPoint;
      if (walkerLat != null && walkerLng != null) {
        final walkerPoint = LatLng(walkerLat.toDouble(), walkerLng.toDouble());
        final companionPoint = LatLng(_startLat!, _startLng!);
        if (RouteService.distanceMeters(walkerPoint, companionPoint) <=
            RouteService.maxMeetingPointDistanceMeters) {
          meetingPoint = RouteService.midpoint(walkerPoint, companionPoint);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "You and your friend are too far apart for a shared meeting point — "
                "you'll watch their journey straight to the destination instead.",
              ),
            ),
          );
        }
      }

      await _repository.setCompanionMeetingPoint(
        sessionId,
        companionLat: _startLat!,
        companionLng: _startLng!,
        meetingLat: meetingPoint?.latitude,
        meetingLng: meetingPoint?.longitude,
      );
      if (!mounted) return;
      final session = await _repository.fetchSession(sessionId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => companionTrackingScreenFor(session)),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Could not set your starting point. Try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        (widget.session['students'] as Map?)?['full_name'] as String? ?? 'your friend';

    return Scaffold(
      appBar: AppBar(title: const Text('Your Starting Point')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "You accepted $name's invite. Enter where you're "
                          "starting from and we'll find a meeting point "
                          "roughly halfway between you two.",
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _startLocationController,
                  decoration: InputDecoration(
                    labelText: 'Your Start Location',
                    hintText: 'Where are you starting from?',
                    prefixIcon: const Icon(Icons.trip_origin),
                    suffixIcon: _isLocating
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.map_outlined),
                                tooltip: 'Pick on map',
                                onPressed: _pickOnMap,
                              ),
                              IconButton(
                                icon: const Icon(Icons.my_location),
                                tooltip: 'Use current location',
                                onPressed: _useCurrentLocation,
                              ),
                            ],
                          ),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter your starting location'
                      : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _confirm,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Confirm & Find Meeting Point'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
