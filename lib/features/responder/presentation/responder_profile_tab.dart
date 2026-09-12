import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../../core/widgets/confirm_logout.dart';
import '../../auth/presentation/welcome_screen.dart';

class ResponderProfileTab extends StatelessWidget {
  const ResponderProfileTab({super.key, required this.fullName, required this.org});

  final String fullName;
  final String org;

  Future<void> _signOut(BuildContext context) async {
    if (!await confirmLogout(context)) return;
    await SupabaseService.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                fullName
                    .trim()
                    .split(RegExp(r'\s+'))
                    .where((p) => p.isNotEmpty)
                    .map((p) => p[0])
                    .take(2)
                    .join()
                    .toUpperCase(),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullName, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  org,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(height: 24),
        ListTile(
          leading: Icon(Icons.logout, color: colorScheme.error),
          title: Text('Log Out', style: TextStyle(color: colorScheme.error)),
          onTap: () => _signOut(context),
        ),
      ],
    );
  }
}
