import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'call_security_screen.dart';
import 'report_concern/report_step1_screen.dart';
import 'safe_ride_screen.dart';
import 'walk_with_me/walk_hub_screen.dart';
import 'widgets/quick_action_tile.dart';
import 'widgets/silent_alert_trigger.dart';
import 'widgets/sos_activation.dart';
import 'widgets/sos_hold_button.dart';

/// Student home tab: status pill + SOS + exactly 4 quick-action tiles, no
/// scrolling required (scope.md §5 "Home screen"). Everything else lives
/// in the drawer.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.campusName,
    this.pendingInvitesFuture,
    this.onOpenPendingInvites,
    this.unreadAlertsFuture,
    this.onOpenAlerts,
  });

  final String? campusName;
  final Future<int>? pendingInvitesFuture;
  final VoidCallback? onOpenPendingInvites;
  final Future<int>? unreadAlertsFuture;
  final VoidCallback? onOpenAlerts;

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
                FutureBuilder<int>(
                  future: unreadAlertsFuture,
                  builder: (context, snapshot) {
                    final unread = snapshot.data ?? 0;
                    final hasNew = unread > 0;
                    final color = hasNew ? AppColors.alert : AppColors.safe;

                    final pill = Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasNew
                                      ? '$unread new alert${unread == 1 ? '' : 's'}'
                                      : (campusName == null
                                          ? 'No active alerts'
                                          : 'No active alerts on $campusName'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                                Text(
                                  hasNew ? 'Tap to view' : "You're all set",
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
                    );

                    if (!hasNew || onOpenAlerts == null) return pill;
                    return InkWell(
                      onTap: onOpenAlerts,
                      borderRadius: BorderRadius.circular(14),
                      child: pill,
                    );
                  },
                ),
                if (pendingInvitesFuture != null)
                  FutureBuilder<int>(
                    future: pendingInvitesFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: InkWell(
                          onTap: onOpenPendingInvites,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                              border: Border.all(
                                color: colorScheme.tertiary.withValues(alpha: 0.4),
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.directions_walk, color: colorScheme.tertiary, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    count == 1
                                        ? 'You have a Safe Walks companion invite'
                                        : 'You have $count Safe Walks companion invites',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: colorScheme.tertiary),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                SosHoldButton(onActivated: () => handleSosActivated(context)),
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
                      label: 'Safe Walks',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WalkHubScreen()),
                      ),
                    ),
                    QuickActionTile(
                      icon: Icons.local_taxi_outlined,
                      label: 'Safe Ride',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SafeRideScreen()),
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
                // const SilentAlertTrigger(),
              ],
            ),
          ),
        );
      },
    );
  }
}
