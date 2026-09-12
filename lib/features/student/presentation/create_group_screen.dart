import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _routeController = TextEditingController();
  final _timeController = TextEditingController();
  bool _requestPatrol = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _routeController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final userId = SupabaseService.client.auth.currentUser!.id;
      await SupabaseService.client.from('walking_groups').insert({
        'created_by': userId,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'route': _routeController.text.trim(),
        'meeting_time': _timeController.text.trim(),
        'requested_patrol': _requestPatrol,
        'status': 'pending',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group submitted for admin approval')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _errorMessage = 'Could not submit. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create a Group')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'e.g. 4pm Study Walk',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter a group name'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: "Who this is for and when you'll meet",
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _routeController,
                  decoration: const InputDecoration(
                    labelText: 'Route / Destination',
                    hintText: 'e.g. Library to North Residence',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter a route'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _timeController,
                  decoration: const InputDecoration(
                    labelText: 'Time',
                    hintText: 'e.g. 16:00, daily',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter a time'
                      : null,
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Request patrol coverage'),
                    subtitle: const Text(
                      'Most relevant for night / off-campus routes',
                    ),
                    value: _requestPatrol,
                    onChanged: (value) => setState(() => _requestPatrol = value),
                  ),
                ),
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
                          'Every group needs admin approval before it '
                          'becomes visible to other students.',
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
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Submit for Approval'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
