import 'package:flutter/material.dart';

import 'walk_invite_screen.dart';
import 'walk_timer_screen.dart';

class WalkHubScreen extends StatelessWidget {
  const WalkHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Safe Walks')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            "Choose how you'd like to feel safer on your journey.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _WalkOptionCard(
            icon: Icons.people_outline,
            iconColor: colorScheme.tertiary,
            title: 'Invite a companion',
            description:
                'A trusted contact accepts and watches your live location '
                'until you arrive.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WalkInviteScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _WalkOptionCard(
            icon: Icons.directions_walk,
            iconColor: colorScheme.primary,
            title: 'Monitor my own journey',
            description:
                "Set a timer. If you don't check in, we notify your "
                'contacts and security.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WalkTimerScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkOptionCard extends StatelessWidget {
  const _WalkOptionCard({
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
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
            ],
          ),
        ),
      ),
    );
  }
}
