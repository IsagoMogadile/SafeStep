import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../auth/domain/student_details.dart';

/// The only screen on the student side where medical info is actually
/// editable — reached via the "Edit" action on the view-only Medical Info
/// Card, never inline on that screen. Saves through the existing
/// `students.medical_info` column via [MedicalInfo.toRaw].
class EditMedicalInfoScreen extends StatefulWidget {
  const EditMedicalInfoScreen({super.key, required this.info});

  final MedicalInfo info;

  @override
  State<EditMedicalInfoScreen> createState() => _EditMedicalInfoScreenState();
}

class _EditMedicalInfoScreenState extends State<EditMedicalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _allergiesController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _notesController = TextEditingController();
  String? _bloodType;

  bool _isSaving = false;

  String get _userId => SupabaseService.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _bloodType = widget.info.bloodType;
    _allergiesController.text = widget.info.allergies;
    _conditionsController.text = widget.info.conditions;
    _notesController.text = widget.info.notes;
  }

  @override
  void dispose() {
    _allergiesController.dispose();
    _conditionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final info = MedicalInfo(
        bloodType: _bloodType,
        allergies: _allergiesController.text,
        conditions: _conditionsController.text,
        notes: _notesController.text,
      );
      await SupabaseService.client
          .from('students')
          .update({'medical_info': info.toRaw()})
          .eq('student_id', _userId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Medical Info')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
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
                const SizedBox(height: 24),
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
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
