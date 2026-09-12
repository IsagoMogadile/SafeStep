import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'active_sos_screen.dart';
import 'call_security_screen.dart';
import 'map_tab.dart';
import 'report_concern/report_step1_screen.dart';
import 'walk_with_me/walk_hub_screen.dart';
import 'widgets/quick_action_tile.dart';
import 'widgets/silent_alert_trigger.dart';
import 'widgets/sos_hold_button.dart';

/// Student home tab: status pill + SOS + exactly 4 quick-action tiles, no
/// scrolling required (scope.md §5 "Home screen"). Everything else lives
/// in the drawer.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.campusName});

  final String? campusName;

  void _handleSosActivated(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActiveSosScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.safe.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.safe.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.safe,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              campusName == null
                                  ? 'No active alerts'
                                  : 'No active alerts on $campusName',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.safe,
                              ),
                            ),
                            Text(
                              "You're all set",
                              style: TextStyle(
                                fontSize: 10.5,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SosHoldButton(onActivated: () => _handleSosActivated(context)),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Quick actions',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.15,
                  children: [
                    QuickActionTile(
                      icon: Icons.local_police_outlined,
                      label: 'Call Security',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CallSecurityScreen(),
                        ),
                      ),
                    ),
                    QuickActionTile(
                      icon: Icons.directions_walk,
                      label: 'Walk With Me',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WalkHubScreen()),
                      ),
                    ),
                    QuickActionTile(
                      icon: Icons.map_outlined,
                      label: 'Map',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MapTab()),
                      ),
                    ),
                    QuickActionTile(
                      icon: Icons.report_outlined,
                      label: 'Report a Concern',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReportStep1Screen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SilentAlertTrigger(),
              ],
            ),
          ),
        );
      },
    );
  }
}
