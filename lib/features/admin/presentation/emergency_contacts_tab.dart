import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import 'widgets/admin_async_error.dart';

/// scope.md §7 "Emergency contacts": manage the shared numbers list (same
/// across all 4 campuses).
class EmergencyContactsTab extends StatefulWidget {
  const EmergencyContactsTab({super.key});

  @override
  State<EmergencyContactsTab> createState() => _EmergencyContactsTabState();
}

class _EmergencyContactsTabState extends State<EmergencyContactsTab> {
  final _repository = AdminRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() { _future = _repository.fetchEmergencyContacts(); });

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final nameController = TextEditingController(text: existing?['service_name'] as String?);
    final phoneController = TextEditingController(text: existing?['phone_number'] as String?);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add emergency contact' : 'Edit emergency contact'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Service name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone number'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                return;
              }
              if (existing == null) {
                await _repository.createEmergencyContact(
                  serviceName: nameController.text.trim(),
                  phoneNumber: phoneController.text.trim(),
                );
              } else {
                await _repository.updateEmergencyContact(existing['contact_id'] as String, {
                  'service_name': nameController.text.trim(),
                  'phone_number': phoneController.text.trim(),
                });
              }
              if (context.mounted) Navigator.of(context).pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) _refresh();
  }

  Future<void> _confirmDelete(Map<String, dynamic> contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text('Remove "${contact['service_name']}" from the emergency numbers list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteEmergencyContact(contact['contact_id'] as String);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AdminAsyncError(error: snapshot.error!, onRetry: _refresh);
        }
        final contacts = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_call),
                label: const Text('Add contact'),
              ),
            ),
            const SizedBox(height: 16),
            for (final c in contacts)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.call_outlined)),
                  title: Text(c['service_name'] as String),
                  subtitle: Text(c['phone_number'] as String),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openForm(existing: c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(c),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
