import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'widgets/sos_hold_button.dart';

/// A safe rehearsal of the real Home tab SOS flow — same 3-second hold
/// button, same countdown feel — but activating it never actually
/// creates an alert, calls anyone, or touches the network. Lets a
/// student build muscle memory (and understand exactly what would
/// happen) without needing to trigger a real alert just to find out.
class PracticeSosScreen extends StatelessWidget {
  const PracticeSosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Practice Emergency Alert')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.caution.withValues(alpha: 0.12),
                  border: Border.all(color: AppColors.caution.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.caution),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Practice mode — nothing will be sent. No responders, "
                        "trusted contacts, or calls are involved.",
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(Icons.shield_outlined, size: 40, color: colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                'Try holding the button below',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'This is exactly what the real Home tab SOS button feels like — '
                'hold for 3 seconds to see what would happen in a real emergency.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              SosHoldButton(
                onActivated: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _PracticeResultScreen()),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done practicing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeResultScreen extends StatelessWidget {
  const _PracticeResultScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.safe.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: AppColors.safe, size: 40),
                ),
                const SizedBox(height: 20),
                Text("That's the full hold", style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(
                  'In a real emergency, this is what happens next:',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                _PracticeStep(
                  icon: Icons.location_on_outlined,
                  text: 'Your current location is captured.',
                ),
                _PracticeStep(
                  icon: Icons.campaign_outlined,
                  text: 'Every responder covering your zone is notified.',
                ),
                _PracticeStep(
                  icon: Icons.people_outline,
                  text: 'All your trusted contacts are notified with your location.',
                ),
                _PracticeStep(
                  icon: Icons.wifi_off_rounded,
                  text: 'With no connection, it calls security directly and texts your '
                      'contacts instead — and still records the alert once you\'re back '
                      'online.',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Close this result screen and PracticeSosScreen
                      // underneath it, landing back on Settings —
                      // popUntil(isFirst) would overshoot all the way to
                      // Home since Settings itself is pushed on top of it.
                      final navigator = Navigator.of(context);
                      navigator.pop();
                      navigator.pop();
                    },
                    child: const Text('Back to Settings'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PracticeStep extends StatelessWidget {
  const _PracticeStep({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
