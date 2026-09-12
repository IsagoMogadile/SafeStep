import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../data/trusted_contact_repository.dart';
import '../../domain/student_details.dart';

/// Bottom sheet form used both during the registration wizard and from
/// the Trusted Contacts screen later, to add one contact at a time
/// (scope.md §5: "Added by email ... or phone").
class AddContactSheet extends StatefulWidget {
  const AddContactSheet({
    super.key,
    required this.studentId,
    required this.repository,
  });

  final String studentId;
  final TrustedContactRepository repository;

  @override
  State<AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<AddContactSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _otherRelationshipController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _relationship;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _otherRelationshipController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickFromContacts() async {
    try {
      // Some OEM contacts providers (confirmed on Samsung's) still
      // enforce READ_CONTACTS even for a single contact picked via
      // openExternalPick(), despite that method existing specifically to
      // avoid needing it — request it explicitly rather than crash.
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contacts permission denied — enter details manually'),
          ),
        );
        return;
      }

      final contact = await FlutterContacts.openExternalPick();
      if (contact == null || !mounted) return;
      setState(() {
        _nameController.text = contact.displayName;
        if (contact.phones.isNotEmpty) {
          _phoneController.text = contact.phones.first.number;
        }
        if (contact.emails.isNotEmpty) {
          _emailController.text = contact.emails.first.address;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open contacts')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_relationship == null) {
      setState(() => _errorMessage = 'Select a relationship');
      return;
    }

    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    if (email.isEmpty && phone.isEmpty) {
      setState(() => _errorMessage = 'Add an email or a phone number');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final relationship = _relationship == 'Other'
        ? _otherRelationshipController.text.trim()
        : _relationship!;

    try {
      await widget.repository.addContact(
        studentId: widget.studentId,
        name: _nameController.text.trim(),
        relationship: relationship,
        email: email.isEmpty ? null : email,
        phone: phone.isEmpty ? null : phone,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _errorMessage = 'Could not save this contact. Try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Add Trusted Contact',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickFromContacts,
              icon: const Icon(Icons.contacts_outlined),
              label: const Text('Choose from Contacts'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _relationship,
              decoration: const InputDecoration(labelText: 'Relationship'),
              items: relationshipOptions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (value) => setState(() => _relationship = value),
            ),
            if (_relationship == 'Other') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _otherRelationshipController,
                decoration: const InputDecoration(labelText: 'Please specify'),
                validator: (value) => (_relationship == 'Other' &&
                        (value == null || value.trim().isEmpty))
                    ? 'Enter a relationship'
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                hintText: 'Checked against SafeStep accounts',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                hintText: 'Used if they don\'t have the app',
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _save,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('Save Contact'),
            ),
          ],
        ),
      ),
    );
  }
}
