import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../auth/domain/student_details.dart';

/// scope.md §5 "Medical info card": optional, restricted-tier — only
/// visible to a responder while the student has an active alert.
///
/// The schema only has one `medical_info` text column, so this structured
/// form composes its fields into one formatted block on save, and parses
/// that same format back out when loading.
class MedicalInfoScreen extends StatefulWidget {
  const MedicalInfoScreen({super.key});

  @override
  State<MedicalInfoScreen> createState() => _MedicalInfoScreenState();
}

class _MedicalInfoScreenState extends State<MedicalInfoScreen> {
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _notesController = TextEditingController();
  String? _bloodType;

  bool _isLoading = true;
  bool _isSaving = false;

  String get _userId => SupabaseService.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final row = await SupabaseService.client
        .from('students')
        .select('medical_info')
        .eq('student_id', _userId)
        .maybeSingle();
    final raw = row?['medical_info'] as String?;
    if (raw != null && raw.isNotEmpty) {
      for (final line in raw.split('\n')) {
        if (line.startsWith('Blood type: ')) {
          final value = line.substring('Blood type: '.length).trim();
          if (bloodTypeOptions.contains(value)) _bloodType = value;
        } else if (line.startsWith('Allergies: ')) {
          _allergiesController.text = line.substring('Allergies: '.length);
        } else if (line.startsWith('Conditions: ')) {
          _conditionsController.text = line.substring('Conditions: '.length);
        } else if (line.startsWith('Notes: ')) {
          _notesController.text = line.substring('Notes: '.length);
        }
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final lines = <String>[
        if (_bloodType != null) 'Blood type: $_bloodType',
        if (_allergiesController.text.trim().isNotEmpty)
          'Allergies: ${_allergiesController.text.trim()}',
        if (_conditionsController.text.trim().isNotEmpty)
          'Conditions: ${_conditionsController.text.trim()}',
        if (_notesController.text.trim().isNotEmpty)
          'Notes: ${_notesController.text.trim()}',
      ];
      await SupabaseService.client
          .from('students')
          .update({'medical_info': lines.join('\n')})
          .eq('student_id', _userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Medical info saved')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _allergiesController.dispose();
    _conditionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medical Info Card')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Only visible to responders while you have an active '
                      'alert. Optional.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _bloodType,
                      decoration: const InputDecoration(
                        labelText: 'Blood Type',
                        prefixIcon: Icon(Icons.bloodtype_outlined),
                      ),
                      items: bloodTypeOptions
                          .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (value) => setState(() => _bloodType = value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _allergiesController,
                      decoration: const InputDecoration(
                        labelText: 'Allergies',
                        hintText: 'e.g. Penicillin, peanuts',
                        prefixIcon: Icon(Icons.warning_amber_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _conditionsController,
                      decoration: const InputDecoration(
                        labelText: 'Medical Conditions',
                        hintText: 'e.g. Asthma, epilepsy, diabetes',
                        prefixIcon: Icon(Icons.medical_information_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Additional Notes',
                        hintText: 'Anything else a responder should know',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
