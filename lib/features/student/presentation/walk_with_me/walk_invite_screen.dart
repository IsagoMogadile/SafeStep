import 'package:flutter/material.dart';

import '../../../../core/supabase/supabase_service.dart';
import '../../data/walk_session_repository.dart';
import 'walk_active_screen.dart';

class WalkInviteScreen extends StatefulWidget {
  const WalkInviteScreen({super.key});

  @override
  State<WalkInviteScreen> createState() => _WalkInviteScreenState();
}

class _WalkInviteScreenState extends State<WalkInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  final _repository = WalkSessionRepository();

  late final Future<List<Map<String, dynamic>>> _contactsFuture;
  String? _selectedContactId;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final userId = SupabaseService.client.auth.currentUser!.id;
    // Only app_linked contacts can actually receive and accept a live
    // invite — someone without the app has nothing to open.
    _contactsFuture = SupabaseService.client
        .from('trusted_contacts')
        .select('contact_id, name, relationship')
        .eq('student_id', userId)
        .eq('status', 'app_linked')
        .order('name');
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedContactId == null) {
      setState(() => _errorMessage = 'Choose a contact to invite');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final userId = SupabaseService.client.auth.currentUser!.id;
      final session = await _repository.createInviteSession(
        studentId: userId,
        companionContactId: _selectedContactId!,
        destination: _destinationController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WalkActiveScreen(session: session),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Could not send the invite. Try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite a Companion')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _contactsFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      );
                    }
                    final contacts = snapshot.data!;
                    if (contacts.isEmpty) {
                      return const Text(
                        'None of your trusted contacts have a SafeStep '
                        'account yet — only contacts with the app can '
                        'accept a live invite. Try Monitor My Journey '
                        'instead.',
                      );
                    }
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedContactId,
                      decoration: const InputDecoration(
                        labelText: 'Choose contact',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: contacts
                          .map(
                            (c) => DropdownMenuItem(
                              value: c['contact_id'] as String,
                              child: Text(
                                '${c['name']} (${c['relationship']})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedContactId = value),
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _destinationController,
                  decoration: const InputDecoration(
                    labelText: 'Destination',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter a destination'
                      : null,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Route suggestions are coming with the map '
                          'update — for now your companion sees your '
                          'destination and live status.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
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
                  onPressed: _isSubmitting ? null : _sendInvite,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Send Invite'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
