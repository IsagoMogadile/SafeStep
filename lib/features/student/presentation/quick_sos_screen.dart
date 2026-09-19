import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'widgets/sos_activation.dart';
import 'widgets/sos_tap_button.dart';

/// Landing screen when SafeStep is launched from the home-screen SOS
/// widget — skips Home entirely. Unlike the Home tab's 3-second
/// hold-to-confirm [SosHoldButton], this uses [SosTapButton] (a single
/// tap) — reaching this screen already meant deliberately finding and
/// tapping the widget itself, so the extra hold mainly costs time a
/// rushed or coerced student may not have. To make that trade-off feel
/// right, this screen reads unmistakably as an emergency control (red,
/// bold, explicit) — the discreet, blend-in styling belongs to the
/// widget tile on the home screen, not to this already-deliberate
/// confirmation step.
class QuickSosScreen extends StatelessWidget {
  const QuickSosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency SOS')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.warning_rounded, size: 48, color: AppColors.alert),
              const SizedBox(height: 12),
              Text(
                'Emergency SOS',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppColors.alert, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the button below to instantly alert responders covering '
                'your zone and your trusted contacts with your location.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              SosTapButton(onActivated: () => handleSosActivated(context)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not an emergency — go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
