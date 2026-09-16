import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../../core/supabase/supabase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/alert_repository.dart';

/// The panic button, matching docs/prototype.html's `.sos-launch` design:
/// a horizontal red card that must be held for 3 seconds (scope.md §5 —
/// deliberate, not one-tap, to avoid accidental activation). Holding it
/// raises a bottom sheet with a countdown ring; releasing early cancels.
///
/// Uses an [OverlayEntry] rather than [showModalBottomSheet] so the
/// in-progress long-press gesture keeps receiving pointer-move/up events
/// uninterrupted (a new modal route would otherwise contest the gesture
/// arena for a fresh pointer, not the one already down).
class SosHoldButton extends StatefulWidget {
  const SosHoldButton({super.key, required this.onActivated});

  final VoidCallback onActivated;

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<SosHoldButton>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 3);

  final _repository = AlertRepository();
  late final AnimationController _controller;
  OverlayEntry? _overlayEntry;
  Timer? _completionGuard;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _holdDuration);
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    _completionGuard?.cancel();
    super.dispose();
  }

  Future<void> _startHold() async {
    // Misuse-prevention (hackathon brief §7): no more than 3 SOS triggers
    // per *student* in any rolling 10 minutes — a 4th attempt starts a
    // 1-hour ban for that account. Tracked server-side, off the
    // student's own `alerts` history (see AlertRepository.checkSosGate)
    // rather than on-device, so testing multiple accounts on one phone
    // doesn't cross-contaminate bans between them. Checked here, before
    // the hold even starts, so a banned student gets immediate feedback
    // instead of holding for 3 seconds for nothing.
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId != null) {
      final bannedUntil = await _repository.checkSosGate(userId);
      if (bannedUntil != null) {
        if (mounted) _showBannedMessage(bannedUntil);
        return;
      }
    }

    HapticFeedback.heavyImpact(); // confirms the hold registered, for anyone not looking at the screen
    _controller.forward(from: 0);
    _showOverlay();
    // Gating this on `_controller.value >= 1.0` used to cause a real race:
    // this Timer runs on the real-time event loop, while the
    // AnimationController only advances on frame callbacks (~16ms apart),
    // so at the exact instant this fires the animation's value could still
    // read fractionally under 1.0 — silently dropping the activation with
    // no error, no alert, and an overlay that only ever closed on finger-up.
    // This Timer only ever fires at all if `_cancelHold` didn't already
    // cancel it, which is itself sufficient proof the hold was long enough.
    _completionGuard = Timer(_holdDuration, () {
      HapticFeedback.heavyImpact();
      _removeOverlay();
      widget.onActivated();
    });
  }

  void _showBannedMessage(DateTime until, {bool justTriggered = false}) {
    final minutesLeft = until.difference(DateTime.now()).inMinutes + 1;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text(
          justTriggered
              ? "Too many SOS alerts sent — SOS is disabled for 1 hour to "
                    'prevent misuse. If this is a real emergency, call '
                    'security directly.'
              : 'SOS is temporarily disabled ($minutesLeft min left) after '
                    'repeated triggers. Call security directly for a real '
                    'emergency.',
        ),
      ),
    );
  }

  void _cancelHold() {
    _completionGuard?.cancel();
    if (_controller.status != AnimationStatus.completed) {
      _controller.reverse();
    }
    _removeOverlay();
  }

  void _showOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (context) => _SosCountdownSheet(controller: _controller),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    // Listener + raw pointer events instead of GestureDetector's
    // onLongPress* family: the latter cancels on small finger movement
    // (normal hand tremor), which is especially likely to misfire here
    // since this button sits inside a scrollable Home tab — any tiny
    // drag lets the ScrollView's gesture win the arena and silently
    // cancels the hold with no feedback ("nothing happens" when held).
    // Tracking the pointer directly ignores movement and only reacts to
    // the finger actually lifting or the touch being cancelled by the OS.
    return Semantics(
      button: true,
      label: 'Emergency SOS',
      hint:
          'Hold for 3 seconds to send an alert with your location to '
          'responders and trusted contacts',
      child: Listener(
        onPointerDown: (_) => _startHold(),
        onPointerUp: (_) => _cancelHold(),
        onPointerCancel: (_) => _cancelHold(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.alert, Color(0xFFB91C1C)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hold for 3 seconds to send an alert',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosCountdownSheet extends StatelessWidget {
  const _SosCountdownSheet({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) => Container(
                color: Colors.black.withValues(alpha: 0.45 * controller.value),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: controller,
                    builder: (context, child) {
                      final secondsLeft = (3 - (controller.value * 3))
                          .ceil()
                          .clamp(1, 3);
                      return Semantics(
                        liveRegion: true,
                        label: '$secondsLeft seconds remaining, hold to send',
                        child: SizedBox(
                          width: 92,
                          height: 92,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: controller.value,
                                strokeWidth: 5,
                                backgroundColor: AppColors.alert.withValues(
                                  alpha: 0.15,
                                ),
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.alert,
                                ),
                              ),
                              Text(
                                '$secondsLeft',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.alert,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hold to send SOS…',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Responders covering your zone and your trusted contacts '
                    'will be alerted with your location.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Release to cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
