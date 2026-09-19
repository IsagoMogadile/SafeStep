import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../../core/supabase/supabase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/alert_repository.dart';

/// One-tap emergency trigger — used only on [QuickSosScreen] (the
/// home-screen-widget landing screen), never the in-app Home tab's
/// [SosHoldButton]. Reaching this screen already took a deliberate
/// action (finding and tapping the widget itself, off the phone's normal
/// unlock flow), so the extra 3-second hold that guards the Home tab's
/// button against an accidental pocket-press doesn't buy much more
/// protection here — it only costs seconds a rushed or coerced student
/// may not have. Still runs the same misuse gate as the hold button
/// before firing, and still looks and reads unmistakably like an
/// emergency control, since by this point there's no "someone glancing
/// at the screen" concern the way there is for the discreet widget tile
/// itself.
class SosTapButton extends StatefulWidget {
  const SosTapButton({super.key, required this.onActivated});

  final VoidCallback onActivated;

  @override
  State<SosTapButton> createState() => _SosTapButtonState();
}

class _SosTapButtonState extends State<SosTapButton> {
  final _repository = AlertRepository();
  bool _isChecking = false;

  Future<void> _handleTap() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId != null) {
        final bannedUntil = await _repository.checkSosGate(userId);
        if (bannedUntil != null) {
          if (mounted) _showBannedMessage(bannedUntil);
          return;
        }
      }
      HapticFeedback.heavyImpact();
      widget.onActivated();
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _showBannedMessage(DateTime until) {
    final minutesLeft = until.difference(DateTime.now()).inMinutes + 1;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: Text(
          'SOS is temporarily disabled ($minutesLeft min left) after repeated '
          'triggers. Call security directly for a real emergency.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Emergency SOS',
      hint:
          'Tap once to send an alert with your location to responders and '
          'trusted contacts',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.alert, Color(0xFFB91C1C)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.alert.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _isChecking
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                      )
                    : const Icon(Icons.campaign_rounded, color: Colors.white, size: 44),
                const SizedBox(height: 12),
                const Text(
                  'TAP FOR EMERGENCY SOS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sends your location instantly — no hold required',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
