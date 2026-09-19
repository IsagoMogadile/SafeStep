import 'package:flutter/material.dart';

/// scope.md §5 "Shuttle & library hours": simple seeded reference content.
/// There's no dedicated table for this in the data model (§9), so it's
/// static content here rather than a query.
class ShuttleLibraryScreen extends StatelessWidget {
  const ShuttleLibraryScreen({super.key});

  static const _shuttleRoutes = [
    ('South ↔ Missionvale Campus', 'Every 20 min · 07:00–21:00'),
    ('South ↔ 2nd Avenue Campus', 'Every 30 min · 07:00–20:00'),
    ('South ↔ Bird Street Campus', 'Every 45 min · 07:30–17:30'),
  ];

  static const _libraryHours = [
    ('South Campus Library', 'Mon–Thu 08:00–22:00 · Fri 08:00–20:00'),
    ('2nd Avenue Library', 'Mon–Fri 08:00–20:00'),
     ('Missionvale Library', 'Mon–Fri 08:00–20:00'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Shuttle & Library Times')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Campus Shuttle', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._shuttleRoutes.map(
            (route) => _InfoRow(
              icon: Icons.directions_bus_outlined,
              color: colorScheme.primary,
              title: route.$1,
              subtitle: route.$2,
            ),
          ),
          const SizedBox(height: 20),
          Text('Library Hours', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._libraryHours.map(
            (lib) => _InfoRow(
              icon: Icons.menu_book_outlined,
              color: const Color(0xFF16A34A),
              title: lib.$1,
              subtitle: lib.$2,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Late-night walking group activity helps inform future '
                    'shuttle time changes.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13.5)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
    );
  }
}
