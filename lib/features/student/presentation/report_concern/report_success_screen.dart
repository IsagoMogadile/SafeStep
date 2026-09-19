import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../safety_resources_screen.dart';

class ReportSuccessScreen extends StatelessWidget {
  const ReportSuccessScreen({super.key, this.queuedOffline = false});

  /// True when this report was saved locally (no connection at submit
  /// time) rather than actually sent yet — see `report_step2_screen.dart`
  /// and `SyncManager`.
  final bool queuedOffline;

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
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.safe,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  queuedOffline ? 'Report saved — Pending Sync' : 'Thank you for reporting',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  queuedOffline
                      ? "You're offline — this report is saved on your phone and "
                            'will be sent automatically once you reconnect.'
                      : "Here's what to do if you're still feeling unsafe.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SafetyResourcesScreen(),
                      ),
                    ),
                    child: const Text('View Safety Guidance'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((route) => route.isFirst),
                    child: const Text('Back to Home'),
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
