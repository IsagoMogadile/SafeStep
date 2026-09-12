import 'package:flutter/material.dart';

import 'browse_groups_screen.dart';
import 'create_group_screen.dart';
import 'my_groups_screen.dart';

/// scope.md §5 "Walking groups", restructured per feedback: a landing
/// screen with two clear paths — discover approved groups, or manage the
/// ones you're already in. Pending-approval groups are never shown to
/// students browsing (only to the student who created them, in My Groups).
class GroupsHomeScreen extends StatelessWidget {
  const GroupsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _GroupOptionCard(
            icon: Icons.explore_outlined,
            iconColor: colorScheme.primary,
            title: 'Browse Groups',
            description: 'Discover approved walking groups and join one.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BrowseGroupsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _GroupOptionCard(
            icon: Icons.groups_outlined,
            iconColor: colorScheme.tertiary,
            title: 'My Groups',
            description: "Groups you've joined or created, including ones "
                'awaiting admin approval.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyGroupsScreen()),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create a Group'),
          ),
        ],
      ),
    );
  }
}

class _GroupOptionCard extends StatelessWidget {
  const _GroupOptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
