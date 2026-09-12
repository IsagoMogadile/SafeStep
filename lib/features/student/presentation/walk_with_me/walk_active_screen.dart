import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../data/walk_session_repository.dart';
import '../active_sos_screen.dart';

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
  Duration _remaining = Duration.zero;
  bool _showingCheckInPrompt = false;
  bool _isBusy = false;

  bool get _isTimerMode => widget.session['mode'] == 'self_monitored';

  @override
  void initState() {
    super.initState();
    NotificationService.instance.onAction = _handleNotificationAction;
    if (_isTimerMode) {
      _recomputeRemaining();
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else {
      _showNotification();
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _graceTimer?.cancel();
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
      title: 'Walk With Me — ${widget.session['destination'] ?? 'journey'}',
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
    final startedAt = DateTime.parse(widget.session['started_at'] as String);
    final timerMinutes = (widget.session['timer_minutes'] as int?) ?? 0;
    final extendedMinutes = (widget.session['extended_minutes'] as int?) ?? 0;
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
    final sessionId = widget.session['session_id'] as String;
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
        widget.session['session_id'] as String,
        10,
      );
      widget.session['extended_minutes'] =
          ((widget.session['extended_minutes'] as int?) ?? 0) + 10;
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
      await _repository.markArrived(widget.session['session_id'] as String);
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
          child: Padding(
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
                        if (widget.session['start_location_text'] != null) ...[
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
                                  widget.session['start_location_text'] as String,
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
                                widget.session['destination'] as String? ?? '',
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
                else
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Your companion can see your journey status "
                              'until you arrive.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
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
