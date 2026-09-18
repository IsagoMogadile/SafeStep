import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/supabase/supabase_service.dart';
import '../data/alert_repository.dart';

/// Full-screen active-alert state, matching docs/prototype.html's
/// `#st-sos-active`. Writes a real `alerts` row on open — `zone_id` stays
/// null since geolocation isn't wired yet, so this prototype's responder
/// feed shows all open alerts rather than filtering by coverage zone.
class ActiveSosScreen extends StatefulWidget {
  const ActiveSosScreen({
    super.key,
    this.alertType = 'panic',
    this.onAlertCreated,
  });

  final String alertType;

  /// Called with the new `alert_id` once the row is written, so a caller
  /// (e.g. Walk With Me's missed-check-in escalation) can link it back to
  /// its own record.
  final ValueChanged<String>? onAlertCreated;

  @override
  State<ActiveSosScreen> createState() => _ActiveSosScreenState();
}

class _ActiveSosScreenState extends State<ActiveSosScreen>
    with TickerProviderStateMixin {
  final _repository = AlertRepository();

  late final AnimationController _pulseController;
  late final Timer _elapsedTimer;
  Duration _elapsed = Duration.zero;
  Future<Map<String, dynamic>>? _alertFuture;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
    _alertFuture = _repository
        .createAlert(
          studentId: SupabaseService.client.auth.currentUser!.id,
          alertType: widget.alertType,
        )
        .then((alert) {
          widget.onAlertCreated?.call(alert['alert_id'] as String);
          return alert;
        });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _elapsedTimer.cancel();
    super.dispose();
  }

  Future<void> _handleFalseAlarm() async {
    setState(() => _isBusy = true);
    try {
      final alert = await _alertFuture;
      if (alert != null) {
        await _repository.markFalseAlarm(alert['alert_id'] as String);
      }
      _showSnack('Alert cancelled — you can send another anytime');
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handleEndAlert() async {
    setState(() => _isBusy = true);
    try {
      final alert = await _alertFuture;
      if (alert != null) {
        await _repository.resolve(alert['alert_id'] as String);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String get _elapsedLabel {
    final minutes = _elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Text(
                  'Help request sent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 28),
                _buildPulse(),
                const SizedBox(height: 24),
                const Text(
                  'Stay where you are if it is safe to do so',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Elapsed time: $_elapsedLabel',
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _alertFuture,
                    builder: (context, snapshot) {
                      final alert = snapshot.data;
                      final hasLocation =
                          alert != null && alert['lat'] != null;
                      return Column(
                        children: [
                          _SosInfoRow(
                            icon: Icons.location_on_outlined,
                            title: hasLocation
                                ? 'Location shared'
                                : 'Location unavailable',
                            subtitle: hasLocation
                                ? 'Your GPS coordinates were sent with this alert'
                                : 'Enable location permission for next time',
                          ),
                          const SizedBox(height: 9),
                          const _SosInfoRow(
                            icon: Icons.people_outline,
                            title: 'Trusted contacts notified',
                            subtitle: 'Recorded — this prototype doesn\'t send real SMS/push',
                          ),
                          const SizedBox(height: 9),
                          const _SosInfoRow(
                            icon: Icons.verified_outlined,
                            title: 'Responders notified',
                            subtitle: 'Sent to every responder covering your area',
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.18),
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          onPressed: _isBusy ? null : _handleFalseAlarm,
                          child: const Text('This was accidental false alarm'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.alert,
                            elevation: 0,
                          ),
                          onPressed: _isBusy ? null : _handleEndAlert,
                          child: const Text("I'm safe now end alert"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPulse() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ..._buildRing(0),
          ..._buildRing(0.5),
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.campaign_outlined,
              color: AppColors.alert,
              size: 42,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRing(double delay) {
    return [
      AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final t = (_pulseController.value + delay) % 1.0;
          return Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.7 + (t * 0.8),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ];
  }
}

class _SosInfoRow extends StatelessWidget {
  const _SosInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
