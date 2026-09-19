import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase/supabase_service.dart';
import '../data/emergency_contacts_cache.dart';


class CallSecurityScreen extends StatefulWidget {
  const CallSecurityScreen({super.key, this.offlineNotice = false});

  /// True when this screen was opened as SOS's offline fallback rather
  /// than from the normal Quick Actions tile — shows an explanatory
  /// banner instead of pretending this was the button the student meant
  /// to press.
  final bool offlineNotice;

  @override
  State<CallSecurityScreen> createState() => _CallSecurityScreenState();
}

class _CallSecurityScreenState extends State<CallSecurityScreen> {
  late final Future<List<Map<String, dynamic>>> _contactsFuture;

  @override
  void initState() {
    super.initState();
    _contactsFuture = _loadContacts();
  }

  Future<List<Map<String, dynamic>>> _loadContacts() async {
    try {
      final rows = await SupabaseService.client
          .from('emergency_contacts')
          .select()
          .order('service_name');
      final contacts = List<Map<String, dynamic>>.from(rows);
      if (contacts.isNotEmpty) {
        await EmergencyContactsCache.save(contacts);
      }
      return contacts;
    } catch (_) {
      // No connection (or the request failed for any other reason) —
      // fall back to whatever was cached the last time this loaded
      // successfully, rather than showing a blank/broken screen.
      return EmergencyContactsCache.load();
    }
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
              if (widget.offlineNotice) ...[
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.wifi_off, size: 18, color: colorScheme.error),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          "No connection right now, so SOS can't send a real "
                          'alert — call security directly instead. This '
                          'still reaches help immediately.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
