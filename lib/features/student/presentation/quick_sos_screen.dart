import 'package:flutter/material.dart';

import 'widgets/sos_activation.dart';
import 'widgets/sos_hold_button.dart';

/// Landing screen when SafeStep is launched from the home-screen SOS
/// widget — skips Home entirely so the only thing between tapping the
/// widget and the same 3-second hold-to-confirm flow used everywhere
/// else in the app is this one screen. Still deliberate-hold, not a
/// one-tap trigger (scope.md §5), so a pocket-tap on the widget can't
/// fire a false alert on its own.
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
              Icon(Icons.shield_outlined, size: 40, color: colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                'Launched from the SafeStep widget',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Hold the button below to alert responders covering your '
                'zone and your trusted contacts with your location.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              SosHoldButton(onActivated: () => handleSosActivated(context)),
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
