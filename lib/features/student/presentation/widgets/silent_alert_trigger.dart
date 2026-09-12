import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/supabase/supabase_service.dart';
import '../../data/alert_repository.dart';

/// Silent alert (scope.md §5, and hackathon brief §7 "Silent panic
/// features must be presented responsibly ... explain how accidental
/// activation and misuse would be managed"). Four safeguards, in order:
///
/// 1. Longer, more deliberate hold than the loud SOS button (4s vs 3s) —
///    a silent false alarm is harder to walk back than a loud one (no
///    visible "cancel"), so it should be *harder* to trigger by accident,
///    not easier.
/// 2. A cooldown after firing (2 min, persisted) — stops a pocket-press
///    or repeated fumbling from spamming multiple silent alerts.
/// 3. Confirmation via haptic feedback only, never a visible SnackBar or
///    dialog — the whole point of "silent" is that the screen doesn't
///    change, so feedback has to be something only the holder's hand
///    would notice.
/// 4. Responder-side: every silent alert is labelled "unconfirmed/silent"
///    everywhere a responder sees it (alert_feed_tab.dart,
///    alert_detail_screen.dart) — responders are told explicitly not to
///    treat it the same as a confirmed panic alert, and can mark it False
///    Alarm – Verify in one tap if it turns out to be nothing.
class SilentAlertTrigger extends StatefulWidget {
  const SilentAlertTrigger({super.key});

  @override
  State<SilentAlertTrigger> createState() => _SilentAlertTriggerState();
}

class _SilentAlertTriggerState extends State<SilentAlertTrigger> {
  static const _holdDuration = Duration(seconds: 4);
  static const _cooldown = Duration(minutes: 2);
  static const _lastTriggeredKey = 'silent_alert_last_triggered';

  final _repository = AlertRepository();

  Timer? _completionGuard;
  bool _isTriggering = false;

  void _startHold() {
    _completionGuard = Timer(_holdDuration, _trigger);
  }

  void _cancelHold() {
    _completionGuard?.cancel();
  }

  Future<void> _trigger() async {
    if (_isTriggering) return;

    final prefs = await SharedPreferences.getInstance();
    final lastMillis = prefs.getInt(_lastTriggeredKey);
    if (lastMillis != null) {
      final elapsed = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(lastMillis),
      );
      if (elapsed < _cooldown) return; // silently ignore — still "silent"
    }

    _isTriggering = true;
    try {
      await _repository.createAlert(
        studentId: SupabaseService.client.auth.currentUser!.id,
        alertType: 'silent',
      );
      await prefs.setInt(
        _lastTriggeredKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      // Two short buzzes — deliberately not a visible SnackBar/dialog, so
      // the screen genuinely never changes. Only the person holding the
      // phone feels it.
      HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      HapticFeedback.heavyImpact();
    } finally {
      _isTriggering = false;
    }
  }

  @override
  void dispose() {
    _completionGuard?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Listener + raw pointer events rather than GestureDetector's
    // onLongPress* family — the latter cancels on small finger movement,
    // which would defeat a hold-based control sitting in a scrollable
    // page. See sos_hold_button.dart for the fuller explanation.
    return Listener(
      onPointerDown: (_) => _startHold(),
      onPointerUp: (_) => _cancelHold(),
      onPointerCancel: (_) => _cancelHold(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'Hold here for a silent alert',
          style: TextStyle(fontSize: 10.5, color: colorScheme.outline),
        ),
      ),
    );
  }
}
