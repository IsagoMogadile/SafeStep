import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/admin_repository.dart';
import 'widgets/admin_async_error.dart';

/// scope.md §7 "Overview dashboard": active alerts, reports this week,
/// pending approvals, walking-group activity patterns. Every stat card
/// jumps straight to the section it summarizes.
class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key, required this.onNavigateToSection});

  final void Function(int sectionIndex) onNavigateToSection;

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  final _repository = AdminRepository();
  late Future<Map<String, int>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchOverviewCounts();
  }

  void _refresh() => setState(() { _future = _repository.fetchOverviewCounts(); });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<Map<String, int>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AdminAsyncError(error: snapshot.error!, onRetry: _refresh);
          }
          final counts = snapshot.data ?? const {};

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'This is a hackathon prototype: every alert, report, and '
                'account here is simulated demo data.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    icon: Icons.campaign,
                    color: AppColors.alert,
                    label: 'Active alerts',
                    value: counts['activeAlerts'] ?? 0,
                    onTap: () => widget.onNavigateToSection(1),
                  ),
                  _StatCard(
                    icon: Icons.report_outlined,
                    color: AppColors.caution,
                    label: 'Reports this week',
                    value: counts['reportsThisWeek'] ?? 0,
                    onTap: () => widget.onNavigateToSection(6),
                  ),
                  _StatCard(
                    icon: Icons.groups_outlined,
                    color: AppColors.seed,
                    label: 'Groups pending approval',
                    value: counts['pendingGroups'] ?? 0,
                    onTap: () => widget.onNavigateToSection(7),
                  ),
                  _StatCard(
                    icon: Icons.menu_book_outlined,
                    color: AppColors.seed,
                    label: 'Resources pending review',
                    value: counts['pendingResources'] ?? 0,
                    onTap: () => widget.onNavigateToSection(5),
                  ),
                  _StatCard(
                    icon: Icons.shield_outlined,
                    color: AppColors.safe,
                    label: 'Approved groups requesting patrol',
                    value: counts['patrolRequests'] ?? 0,
                    onTap: () => widget.onNavigateToSection(7),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$value',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
