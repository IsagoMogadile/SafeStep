import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/offline/pending_contact_queue.dart';
import '../../../../core/validation/validators.dart';
import '../../data/trusted_contact_repository.dart';
import '../../domain/student_details.dart';

/// Bottom sheet form used both during the registration wizard and from
/// the Trusted Contacts screen later, to add one contact at a time.
/// Phone is mandatory — it's the reliable way to reach a contact who
/// doesn't have the app (SMS fallback) and to check whether they already
/// have a SafeStep account (find_student_by_contact checks phone and
/// email). Email stays optional, on top of phone.
class AddContactSheet extends StatefulWidget {
  const AddContactSheet({
    super.key,
    this.studentId,
    this.repository,
    this.onLocalAdd,
    this.existingContact,
  }) : assert(
         (studentId != null && repository != null) || onLocalAdd != null,
         'Either studentId+repository (writes immediately) or onLocalAdd '
         '(collects in memory, for the pre-account wizard) must be given.',
       );

  final String? studentId;
  final TrustedContactRepository? repository;

  /// When set, the sheet doesn't write to the database at all — it just
  /// hands the entered fields back to the caller. Used by the student
  /// wizard before an account exists yet (no studentId to attach a real
  /// row to); the caller inserts everything for real once signup
  /// actually happens at the wizard's final confirm step.
  final ValueChanged<Map<String, dynamic>>? onLocalAdd;

  /// When set, the sheet opens pre-filled for this contact and saves via
  /// `updateContact` instead of `addContact`.
  final Map<String, dynamic>? existingContact;

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

  // Live "does this match an existing SafeStep account?" check, shown
  // right in this sheet instead of only after saving — feedback: "what
  // happened to showing app linked or SMS when adding trusted
  // contacts?" It never showed here at all before; only on the list
  // screen's chip, after the fact. Only available when there's an
  // authenticated session (widget.repository != null) — the lookup RPC
  // isn't granted to anon, so this can't run during the pre-account
  // signup wizard's local contact collection.
  Timer? _linkCheckDebounce;
  int _linkCheckRequestId = 0;
  bool _isCheckingLink = false;
  bool? _isLinked;

  bool get _isEditing => widget.existingContact != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingContact;
    if (existing != null) {
      _nameController.text = existing['name'] as String? ?? '';
      _emailController.text = existing['email'] as String? ?? '';
      _phoneController.text = existing['phone'] as String? ?? '';
      final relationship = existing['relationship'] as String?;
      if (relationship != null && relationshipOptions.contains(relationship)) {
        _relationship = relationship;
      } else if (relationship != null) {
        _relationship = 'Other';
        _otherRelationshipController.text = relationship;
      }
    }
    if (widget.repository != null) {
      _emailController.addListener(_scheduleLinkCheck);
      _phoneController.addListener(_scheduleLinkCheck);
      // Kick off the initial check (for edit mode's prefilled values)
      // without calling setState synchronously inside initState — set
      // the field directly instead; the check's own async continuation
      // (after the RPC await) is what safely calls setState later.
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      if (email.isNotEmpty || phone.isNotEmpty) {
        _isCheckingLink = true;
        _runLinkCheck(email, phone);
      }
    }
  }

  @override
  void dispose() {
    _linkCheckDebounce?.cancel();
    _nameController.dispose();
    _otherRelationshipController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _scheduleLinkCheck({bool immediate = false}) {
    _linkCheckDebounce?.cancel();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    if (email.isEmpty && phone.isEmpty) {
      setState(() {
        _isLinked = null;
        _isCheckingLink = false;
      });
      return;
    }
    setState(() => _isCheckingLink = true);
    if (immediate) {
      _runLinkCheck(email, phone);
    } else {
      _linkCheckDebounce = Timer(
        const Duration(milliseconds: 600),
        () => _runLinkCheck(email, phone),
      );
    }
  }

  Future<void> _runLinkCheck(String email, String phone) async {
    final requestId = ++_linkCheckRequestId;
    final linkedId = await widget.repository!.findLinkedStudentId(
      email: email.isEmpty ? null : email,
      phone: phone.isEmpty ? null : phone,
    );
    // Discard the result if a newer keystroke has since started another
    // check — otherwise a slow early request could overwrite a faster
    // later one and show a stale answer.
    if (!mounted || requestId != _linkCheckRequestId) return;
    setState(() {
      _isCheckingLink = false;
      _isLinked = linkedId != null;
    });
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

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final relationship = _relationship == 'Other'
        ? _otherRelationshipController.text.trim()
        : _relationship!;

    try {
      if (widget.onLocalAdd != null) {
        widget.onLocalAdd!({
          'name': _nameController.text.trim(),
          'relationship': relationship,
          'email': email.isEmpty ? null : email,
          'phone': phone.isEmpty ? null : phone,
        });
      } else if (_isEditing) {
        // Editing an already-synced contact isn't queueable the way a
        // brand-new one is (see PendingContactQueue) — there's a real
        // server row that could conflict with, so this stays online-only.
        if (!await ConnectivityService.hasConnection()) {
          setState(() => _errorMessage = 'Editing a contact requires an internet connection.');
          return;
        }
        await widget.repository!.updateContact(
          contactId: widget.existingContact!['contact_id'] as String,
          name: _nameController.text.trim(),
          relationship: relationship,
          email: email.isEmpty ? null : email,
          phone: phone.isEmpty ? null : phone,
        );
      } else if (!await ConnectivityService.hasConnection()) {
        await PendingContactQueue.add(
          studentId: widget.studentId!,
          name: _nameController.text.trim(),
          relationship: relationship,
          email: email.isEmpty ? null : email,
          phone: phone.isEmpty ? null : phone,
          createdAt: DateTime.now(),
        );
      } else {
        await widget.repository!.addContact(
          studentId: widget.studentId!,
          name: _nameController.text.trim(),
          relationship: relationship,
          email: email.isEmpty ? null : email,
          phone: phone.isEmpty ? null : phone,
        );
      }
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
              _isEditing ? 'Edit Trusted Contact' : 'Add Trusted Contact',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickFromContacts,
                icon: const Icon(Icons.contacts_outlined),
                label: const Text('Choose from Contacts'),
              ),
            ],
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
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? null : emailValidator(value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Cellphone Number',
                hintText: 'Used for SMS fallback, and to check for an existing account',
              ),
              validator: (value) => phoneValidator(value, required: true),
            ),
            if (widget.repository != null) ...[
              const SizedBox(height: 10),
              _LinkStatusIndicator(isChecking: _isCheckingLink, isLinked: _isLinked),
            ],
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
                  : Text(_isEditing ? 'Save Changes' : 'Save Contact'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkStatusIndicator extends StatelessWidget {
  const _LinkStatusIndicator({required this.isChecking, required this.isLinked});

  final bool isChecking;
  final bool? isLinked;

  @override
  Widget build(BuildContext context) {
    if (isChecking) {
      return const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Checking for an existing account…', style: TextStyle(fontSize: 12.5)),
        ],
      );
    }
    if (isLinked == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    if (isLinked!) {
      return Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: colorScheme.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Has a SafeStep account — they\'ll get instant notifications',
              style: TextStyle(fontSize: 12.5, color: colorScheme.tertiary),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'No account found — they\'ll be reached by SMS',
            style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
