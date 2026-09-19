import 'package:flutter/material.dart';

import '../../../core/connectivity/connectivity_service.dart';
import '../../../core/offline/pending_contact_queue.dart';
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
  late Future<List<Map<String, dynamic>>> _pendingFuture;

  String get _userId => SupabaseService.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _contactsFuture = _repository.fetchForStudent(_userId);
    _pendingFuture = PendingContactQueue.loadAll();
  }

  void _refresh() {
    setState(() {
      _contactsFuture = _repository.fetchForStudent(_userId);
      _pendingFuture = PendingContactQueue.loadAll();
    });
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

  Future<void> _editContact(Map<String, dynamic> contact) async {
    if (!await ConnectivityService.hasConnection()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Editing a contact requires an internet connection.')),
      );
      return;
    }
    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddContactSheet(
        studentId: _userId,
        repository: _repository,
        existingContact: contact,
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _removeContact(Map<String, dynamic> contact) async {
    if (!await ConnectivityService.hasConnection()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removing a contact requires an internet connection.')),
      );
      return;
    }
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

  Future<void> _removePendingContact(String localId) async {
    await PendingContactQueue.removeById(localId);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Trusted Contacts')),
      body: FutureBuilder<List<List<Map<String, dynamic>>>>(
        future: Future.wait([_contactsFuture, _pendingFuture]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SkeletonList();
          }
          final contacts = snapshot.data![0];
          final pending = snapshot.data![1];
          final total = contacts.length + pending.length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$total of $_maxContacts added'
                    '${total < _minContacts ? ' · add at least $_minContacts' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: contacts.isEmpty && pending.isEmpty
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
                        itemCount: contacts.length + pending.length,
                        itemBuilder: (context, index) {
                          if (index >= contacts.length) {
                            final queued = pending[index - contacts.length];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 0,
                              color: colorScheme.surfaceContainerHigh,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                title: Text(queued['name'] as String? ?? ''),
                                subtitle: Text(queued['relationship'] as String? ?? ''),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Chip(
                                      label: const Text('Pending Sync'),
                                      labelStyle: const TextStyle(fontSize: 11),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: colorScheme.tertiaryContainer,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      tooltip: 'Remove',
                                      onPressed: () =>
                                          _removePendingContact(queued['local_id'] as String),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
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
                              onTap: () => _editContact(contact),
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
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    tooltip: 'Edit',
                                    onPressed: () => _editContact(contact),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    tooltip: 'Remove',
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
                  onPressed: total >= _maxContacts ? null : _addContact,
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
