import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../data/walk_session_repository.dart';
import '../active_sos_screen.dart';
import 'widgets/route_map_view.dart';

/// Journey-in-progress screen for both Walk With Me modes (scope.md §5).
/// For `self_monitored`, a missed check-in prompts the student and, if
/// unresolved for 5 more minutes, escalates into a real panic alert.
class WalkActiveScreen extends StatefulWidget {
  const WalkActiveScreen({super.key, required this.session});

  final Map<String, dynamic> session;

  @override
  State<WalkActiveScreen> createState() => _WalkActiveScreenState();
}

class _WalkActiveScreenState extends State<WalkActiveScreen> {
  final _repository = WalkSessionRepository();

  Timer? _tickTimer;
  Timer? _graceTimer;
  Timer? _acceptancePollTimer;
  Duration _remaining = Duration.zero;
  bool _showingCheckInPrompt = false;
  bool _isBusy = false;
  late Map<String, dynamic> _session;

  bool get _isTimerMode => _session['mode'] == 'self_monitored';
  bool get _companionAccepted => _session['companion_accepted_at'] != null;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    NotificationService.instance.onAction = _handleNotificationAction;
    if (_isTimerMode) {
      _recomputeRemaining();
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else {
      _showNotification();
      if (!_companionAccepted) {
        // No realtime subscriptions exist anywhere in this app yet — a
        // short poll is the simplest correct way to notice the companion
        // accepting (scope.md §5: "they must accept before the journey
        // starts").
        _acceptancePollTimer = Timer.periodic(
          const Duration(seconds: 8),
          (_) => _pollForAcceptance(),
        );
      }
    }
  }

  Future<void> _pollForAcceptance() async {
    final fresh = await _repository.fetchSession(_session['session_id'] as String);
    if (!mounted) return;
    if (fresh['companion_accepted_at'] != null) {
      _acceptancePollTimer?.cancel();
      setState(() => _session = fresh);
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _graceTimer?.cancel();
    _acceptancePollTimer?.cancel();
    NotificationService.instance.onAction = null;
    NotificationService.instance.cancelJourneyNotification();
    super.dispose();
  }

  /// Lets the student use other apps during a journey (feedback: "make it
  /// like a floating widget/ball ... so I can use other apps while in
  /// journey") via an ongoing notification with quick actions, rather
  /// than requiring SafeStep to stay in the foreground.
  Future<void> _showNotification() async {
    await NotificationService.instance.showJourneyNotification(
      title: 'Walk With Me — ${_session['destination'] ?? 'journey'}',
      body: _isTimerMode
          ? 'Time remaining: $_remainingLabel'
          : 'Your companion can see your journey status',
      showExtendAction: _isTimerMode,
    );
  }

  void _handleNotificationAction(String actionId) {
    switch (actionId) {
      case NotificationService.actionExtend:
        _extend();
      case NotificationService.actionArrived:
        _arrivedSafely();
    }
  }

  void _recomputeRemaining() {
    final startedAt = DateTime.parse(_session['started_at'] as String);
    final timerMinutes = (_session['timer_minutes'] as int?) ?? 0;
    final extendedMinutes = (_session['extended_minutes'] as int?) ?? 0;
    final deadline = startedAt.add(
      Duration(minutes: timerMinutes + extendedMinutes),
    );
    final remaining = deadline.difference(DateTime.now());
    setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);
  }

  void _tick() {
    if (!mounted) return;
    _recomputeRemaining();
    // Throttle notification updates — no need to hit the native plugin
    // every second.
    if (_remaining.inSeconds % 5 == 0) _showNotification();
    if (_remaining == Duration.zero && !_showingCheckInPrompt) {
      _tickTimer?.cancel();
      _handleMissedCheckIn();
    }
  }

  void _handleMissedCheckIn() {
    setState(() => _showingCheckInPrompt = true);

    _graceTimer = Timer(const Duration(minutes: 5), _escalate);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36),
        title: const Text('Are you okay?'),
        content: const Text(
          "You haven't checked in. If we don't hear from you in 5 minutes, "
          "we'll alert your contacts and security.",
        ),
        actions: [
          FilledButton(
            onPressed: () {
              _graceTimer?.cancel();
              Navigator.of(context).pop();
              setState(() => _showingCheckInPrompt = false);
            },
            child: const Text("I'm okay"),
          ),
        ],
      ),
    );
  }

  Future<void> _escalate() async {
    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss the check-in dialog
    final sessionId = _session['session_id'] as String;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ActiveSosScreen(
          alertType: 'walk_escalation',
          onAlertCreated: (alertId) {
            _repository.linkEscalatedAlert(
              sessionId: sessionId,
              alertId: alertId,
            );
          },
        ),
      ),
    );
  }

  Future<void> _extend() async {
    setState(() => _isBusy = true);
    try {
      await _repository.extendSession(
        _session['session_id'] as String,
        10,
      );
      _session['extended_minutes'] =
          ((_session['extended_minutes'] as int?) ?? 0) + 10;
      _recomputeRemaining();
      _showNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('10 minutes added to your timer')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _arrivedSafely() async {
    setState(() => _isBusy = true);
    try {
      await _repository.markArrived(_session['session_id'] as String);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String get _remainingLabel {
    final minutes = _remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Journey in Progress'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_session['start_location_text'] != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.trip_origin,
                                size: 18,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _session['start_location_text'] as String,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _session['destination'] as String? ?? '',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isTimerMode)
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Time remaining',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              Text(
                                _remainingLabel,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                            ),
                            onPressed: _isBusy ? null : _extend,
                            child: const Text('+ Extend 10 min'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Card(
                    elevation: 0,
                    color: _companionAccepted
                        ? Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.5)
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(_companionAccepted ? Icons.check_circle : Icons.hourglass_top),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _companionAccepted
                                  ? 'Your companion accepted and can see your journey.'
                                  : 'Waiting for your companion to accept the invite…',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_companionAccepted &&
                      _session['start_lat'] != null &&
                      _session['start_lng'] != null &&
                      (_session['destination'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    Text('Planned route', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    RouteMapView(
                      origin: LatLng(
                        (_session['start_lat'] as num).toDouble(),
                        (_session['start_lng'] as num).toDouble(),
                      ),
                      destinationQuery: _session['destination'] as String,
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isBusy ? null : _arrivedSafely,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("I've Arrived Safely"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
