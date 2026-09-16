import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/data/trusted_contact_repository.dart';
import '../../auth/presentation/widgets/add_contact_sheet.dart';

const _maxContacts = 10;
const _minContacts = 3;

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  final _repository = TrustedContactRepository();
  late Future<List<Map<String, dynamic>>> _contactsFuture;

  String get _userId => SupabaseService.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _contactsFuture = _repository.fetchForStudent(_userId);
  }

  void _refresh() {
    setState(() { _contactsFuture = _repository.fetchForStudent(_userId); });
  }

  Future<void> _addContact() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          AddContactSheet(studentId: _userId, repository: _repository),
    );
    if (added == true) _refresh();
  }

  Future<void> _removeContact(Map<String, dynamic> contact) async {
    final name = contact['name'] as String? ?? 'this contact';
    await _repository.removeContact(contact['contact_id'] as String);
    _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed $name'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await _repository.restoreContact(contact);
            _refresh();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Trusted Contacts')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _contactsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SkeletonList();
          }
          final contacts = snapshot.data!;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${contacts.length} of $_maxContacts added'
                    '${contacts.length < _minContacts ? ' · add at least $_minContacts' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: contacts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 40,
                                color: colorScheme.outline,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No trusted contacts yet',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Add at least $_minContacts people who should be '
                                "notified with your location whenever you send an "
                                'alert.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          final linked = contact['status'] == 'app_linked';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
                            color: colorScheme.surfaceContainerHigh,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ListTile(
                              title: Text(contact['name'] as String? ?? ''),
                              subtitle: Text(
                                contact['relationship'] as String? ?? '',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    label: Text(linked ? 'App linked' : 'SMS only'),
                                    labelStyle: const TextStyle(fontSize: 11),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: linked
                                        ? colorScheme.tertiaryContainer
                                        : colorScheme.surfaceContainerHighest,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () => _removeContact(contact),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton.icon(
                  onPressed: contacts.length >= _maxContacts ? null : _addContact,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add Contact'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
