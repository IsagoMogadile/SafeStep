import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../data/admin_repository.dart';

/// scope.md §7 "Overview dashboard": the admin's entry point — a personal
/// greeting, today's key numbers, a live feed of recent admin activity
/// (straight from the audit trail), then the section grid (which used to
/// be a NavigationRail; see git history for that and the older flat
/// stat-card layout this replaced).
class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key, required this.onNavigateToSection});

  final void Function(int sectionIndex) onNavigateToSection;

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  final _repository = AdminRepository();
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final userId = SupabaseService.client.auth.currentUser!.id;
    final results = await Future.wait([
      _repository.fetchQuickStats(),
      _repository.fetchAuditLogs(limit: 6),
      _repository.fetchSelf(userId),
    ]);
    return _DashboardData(
      stats: results[0] as Map<String, int>,
      activity: results[1] as List<Map<String, dynamic>>,
      adminName: (results[2] as Map<String, dynamic>?)?['full_name'] as String? ?? '',
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  List<({IconData icon, String label, Color color, int section})> _navTileSpecs(
    ColorScheme colorScheme,
  ) => [
    (icon: Icons.campaign_outlined, label: 'Active Alerts', color: AppColors.alert, section: 1),
    (icon: Icons.badge_outlined, label: 'Responders & Admins', color: colorScheme.primary, section: 2),
    (icon: Icons.map_outlined, label: 'Zones', color: colorScheme.tertiary, section: 3),
    (icon: Icons.campaign_outlined, label: 'Safety Broadcasts', color: AppColors.caution, section: 4),
    (icon: Icons.menu_book_outlined, label: 'Resources', color: colorScheme.secondary, section: 5),
    (icon: Icons.report_outlined, label: 'Incident Reports', color: AppColors.caution, section: 6),
    (icon: Icons.directions_car_outlined, label: 'Safe Ride Reports', color: colorScheme.tertiary, section: 7),
    (icon: Icons.groups_outlined, label: 'Walking Groups', color: AppColors.safe, section: 8),
    (icon: Icons.call_outlined, label: 'Emergency Contacts', color: AppColors.alert, section: 9),
    (icon: Icons.school_outlined, label: 'Students', color: colorScheme.secondary, section: 10),
    (icon: Icons.history_outlined, label: 'Audit Logs', color: colorScheme.outline, section: 11),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          FutureBuilder<_DashboardData>(
            future: _future,
            builder: (context, snapshot) {
              return _GreetingBanner(adminName: snapshot.data?.adminName ?? '');
            },
          ),
          const SizedBox(height: 12),
          Text(
            'This is a hackathon prototype: every alert, report, and '
            'account here is simulated demo data.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 24),
          Text('Today at a glance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          FutureBuilder<_DashboardData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: List.generate(
                    4,
                    (_) => const SkeletonBox(width: 220, height: 68, borderRadius: 16),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  "Couldn't load today's numbers.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                );
              }
              final stats = snapshot.data!.stats;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatPill(
                    icon: Icons.campaign_outlined,
                    label: 'Active alerts',
                    value: stats['activeAlerts'] ?? 0,
                    color: AppColors.alert,
                    onTap: () => widget.onNavigateToSection(1),
                  ),
                  _StatPill(
                    icon: Icons.report_outlined,
                    label: 'Reports this week',
                    value: stats['reportsThisWeek'] ?? 0,
                    color: AppColors.caution,
                    onTap: () => widget.onNavigateToSection(6),
                  ),
                  _StatPill(
                    icon: Icons.pending_actions_outlined,
                    label: 'Pending approvals',
                    value: stats['pendingApprovals'] ?? 0,
                    color: colorScheme.primary,
                    onTap: () => widget.onNavigateToSection(8),
                  ),
                  _StatPill(
                    icon: Icons.school_outlined,
                    label: 'Registered students',
                    value: stats['students'] ?? 0,
                    color: colorScheme.secondary,
                    onTap: () => widget.onNavigateToSection(10),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Text('Recent activity', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          FutureBuilder<_DashboardData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SkeletonList(itemCount: 3, padding: EdgeInsets.zero);
              }
              if (snapshot.hasError) {
                return Text(
                  "Couldn't load recent activity.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                );
              }
              final activity = snapshot.data!.activity;
              if (activity.isEmpty) {
                return Text(
                  'No admin activity yet — actions taken across the dashboard '
                  'will show up here.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                );
              }
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < activity.length; i++) ...[
                      _ActivityRow(log: activity[i]),
                      if (i != activity.length - 1) const Divider(height: 1, indent: 56),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          Text('Manage', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final (i, spec) in _navTileSpecs(colorScheme).indexed)
                _FadeSlideIn(
                  delay: Duration(milliseconds: 40 * i),
                  child: _NavTile(
                    icon: spec.icon,
                    label: spec.label,
                    color: spec.color,
                    onTap: () => widget.onNavigateToSection(spec.section),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardData {
  const _DashboardData({required this.stats, required this.activity, required this.adminName});

  final Map<String, int> stats;
  final List<Map<String, dynamic>> activity;
  final String adminName;
}

class _GreetingBanner extends StatelessWidget {
  const _GreetingBanner({required this.adminName});

  final String adminName;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());
    final firstName = adminName.isEmpty ? null : adminName.split(' ').first;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.seed, Color.lerp(AppColors.seed, Colors.black, 0.3)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstName == null ? _greeting : '$_greeting, $firstName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(today, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                const Text(
                  "Here's what's happening across campus right now.",
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const Icon(Icons.shield_outlined, size: 56, color: Colors.white24),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.18),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$value',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.log});

  final Map<String, dynamic> log;

  static final _dateFormat = DateFormat('d MMM');

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _dateFormat.format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final action = log['action'] as String? ?? '';
    final category = action.split('.').first;
    final (icon, color) = switch (category) {
      'alert' => (Icons.campaign_outlined, AppColors.alert),
      'broadcast' => (Icons.campaign, AppColors.caution),
      'zone' => (Icons.map_outlined, colorScheme.tertiary),
      'resource' => (Icons.menu_book_outlined, colorScheme.secondary),
      'report' => (Icons.report_outlined, AppColors.caution),
      'group' => (Icons.groups_outlined, AppColors.safe),
      'contact' => (Icons.call_outlined, AppColors.alert),
      'responder' || 'admin' => (Icons.badge_outlined, colorScheme.primary),
      'safe_ride_report' => (Icons.directions_car_outlined, colorScheme.tertiary),
      _ => (Icons.history_outlined, colorScheme.outline),
    };
    final adminName = log['admin_name'] as String? ?? 'An admin';
    final details = log['details'] as String? ?? action;
    final createdAt = DateTime.tryParse(log['created_at'] as String? ?? '')?.toLocal();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(details, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  '$adminName${createdAt != null ? ' · ${_relativeTime(createdAt)}' : ''}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A gentle staggered fade + rise, purely cosmetic — makes the Manage
/// grid feel like it's populating in rather than just appearing.
class _FadeSlideIn extends StatefulWidget {
  const _FadeSlideIn({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  // Fixed size so every tile matches the tallest one (a two-line label
  // like "Responders & Admins") regardless of how short its own label is.
  static const _width = 200.0;
  static const _height = 180.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withValues(alpha: 0.16),
        highlightColor: color.withValues(alpha: 0.08),
        child: Container(
          width: _width,
          height: _height,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withValues(alpha: 0.16),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
