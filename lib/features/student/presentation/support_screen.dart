import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

/// A visible, always-reachable support entry point (scope.md §12 flagged
/// this as a known gap) — distinct in tone from Call Security: this is
/// for "I need someone to talk to," not "I'm in danger right now."
/// Reuses the same real `emergency_contacts` data (counselling/wellness
/// numbers are already seeded there) rather than a separate table.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final Future<List<Map<String, dynamic>>> _contactsFuture;

  @override
  void initState() {
    super.initState();
    _contactsFuture = SupabaseService.client
        .from('emergency_contacts')
        .select()
        .order('service_name');
  }

  Future<void> _call(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start a call to $phoneNumber')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Get Support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.seed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.favorite_outline, color: AppColors.seed),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "You don't have to be in immediate danger to reach out. "
                    "If you're struggling, worried, or just need to talk to "
                    'someone, these are here for that.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _contactsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final contacts = snapshot.data!;
              return Column(
                children: contacts
                    .map(
                      (contact) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 0,
                        color: colorScheme.surfaceContainerHigh,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.seed.withValues(alpha: 0.15),
                            child: Icon(Icons.call_outlined, color: AppColors.seed),
                          ),
                          title: Text(contact['service_name'] as String? ?? ''),
                          subtitle: Text(contact['phone_number'] as String? ?? ''),
                          onTap: () => _call(contact['phone_number'] as String? ?? ''),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            "In immediate danger? Use the SOS button on Home instead — "
            "it alerts responders and your trusted contacts directly.",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
