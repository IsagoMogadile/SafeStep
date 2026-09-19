import 'package:flutter/material.dart';

/// scope.md §7 "Overview dashboard": the admin's entry point into every
/// section — this used to be a NavigationRail, now rendered as a tile grid
/// (see git history for the older stat-card layout this replaced).
class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, required this.onNavigateToSection});

  final void Function(int sectionIndex) onNavigateToSection;

  @override
  Widget build(BuildContext context) {
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
        Text('Manage', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _NavTile(
              icon: Icons.campaign_outlined,
              label: 'Active Alerts',
              onTap: () => onNavigateToSection(1),
            ),
            _NavTile(
              icon: Icons.badge_outlined,
              label: 'Responders & Admins',
              onTap: () => onNavigateToSection(2),
            ),
            _NavTile(
              icon: Icons.map_outlined,
              label: 'Zones',
              onTap: () => onNavigateToSection(3),
            ),
            _NavTile(
              icon: Icons.campaign_outlined,
              label: 'Safety Broadcasts',
              onTap: () => onNavigateToSection(4),
            ),
            _NavTile(
              icon: Icons.menu_book_outlined,
              label: 'Resources',
              onTap: () => onNavigateToSection(5),
            ),
            _NavTile(
              icon: Icons.report_outlined,
              label: 'Incident Reports',
              onTap: () => onNavigateToSection(6),
            ),
            _NavTile(
              icon: Icons.directions_car_outlined,
              label: 'Safe Ride Reports',
              onTap: () => onNavigateToSection(7),
            ),
            _NavTile(
              icon: Icons.groups_outlined,
              label: 'Walking Groups',
              onTap: () => onNavigateToSection(8),
            ),
            _NavTile(
              icon: Icons.call_outlined,
              label: 'Emergency Contacts',
              onTap: () => onNavigateToSection(9),
            ),
            _NavTile(
              icon: Icons.school_outlined,
              label: 'Students',
              onTap: () => onNavigateToSection(10),
            ),
            _NavTile(
              icon: Icons.history_outlined,
              label: 'Audit Logs',
              onTap: () => onNavigateToSection(11),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  // Fixed size so every tile matches the tallest one (a two-line label
  // like "Responders & Admins") regardless of how short its own label is.
  static const _width = 160.0;
  static const _height = 140.0;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: _width,
        height: _height,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
