import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase/supabase_service.dart';

/// scope.md §5 "Offline fallback": these are real phone numbers dialled
/// via the OS phone app, so they still work with zero data connection.
class CallSecurityScreen extends StatefulWidget {
  const CallSecurityScreen({super.key});

  @override
  State<CallSecurityScreen> createState() => _CallSecurityScreenState();
}

class _CallSecurityScreenState extends State<CallSecurityScreen> {
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
      appBar: AppBar(title: const Text('Call for Help')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _contactsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final contacts = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (contacts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No emergency numbers configured yet',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ...contacts.map(
                (contact) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  color: colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.errorContainer,
                      child: Icon(
                        Icons.phone_outlined,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                    title: Text(contact['service_name'] as String? ?? ''),
                    subtitle: Text(contact['phone_number'] as String? ?? ''),
                    onTap: () => _call(contact['phone_number'] as String? ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'No signal? These numbers still work as a normal '
                        'phone call, even with no data connection.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
