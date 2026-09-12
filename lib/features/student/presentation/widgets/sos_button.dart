import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// The panic button: deliberately requires a 3-second hold rather than a
/// single tap, to avoid accidental activation (scope.md §5 "Panic button").
///
/// Wiring this to actually fan out to responders + trusted contacts is a
/// separate backend task (zone lookup, alert_recipients fan-out per §3) —
/// this widget owns the interaction only and calls [onActivated] once the
/// hold completes.
class SosButton extends StatefulWidget {
  const SosButton({super.key, required this.onActivated});

  final VoidCallback onActivated;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(seconds: 3);

  late final AnimationController _controller;
  Timer? _completionGuard;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _holdDuration);
  }

  @override
  void dispose() {
    _controller.dispose();
    _completionGuard?.cancel();
    super.dispose();
  }

  void _startHold() {
    _controller.forward(from: 0);
    _completionGuard = Timer(_holdDuration, () {
      if (_controller.value >= 1.0) {
        widget.onActivated();
      }
    });
  }

  void _cancelHold() {
    _completionGuard?.cancel();
    if (_controller.status != AnimationStatus.completed) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startHold(),
      onLongPressEnd: (_) => _cancelHold(),
      onLongPressCancel: _cancelHold,
      child: SizedBox(
        width: 180,
        height: 180,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: _controller.value,
                    strokeWidth: 6,
                    backgroundColor: AppColors.alert.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(AppColors.alert),
                  ),
                ),
                Container(
                  width: 148,
                  height: 148,
                  decoration: const BoxDecoration(
                    color: AppColors.alert,
                    shape: BoxShape.circle,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_rounded, color: Colors.white, size: 40),
                      SizedBox(height: 6),
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Hold 3 seconds',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
