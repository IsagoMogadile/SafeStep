import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../auth/domain/student_details.dart';
import 'edit_medical_info_screen.dart';

/// scope.md §5 "Medical info card": optional, restricted-tier — only
/// visible to a responder while the student has an active alert.
///
/// View-only by design, so the student can't accidentally change sensitive
/// medical data while just checking what's on file. Editing happens on
/// [EditMedicalInfoScreen], reached via the AppBar "Edit" action.
class MedicalInfoScreen extends StatefulWidget {
  const MedicalInfoScreen({super.key});

  @override
  State<MedicalInfoScreen> createState() => _MedicalInfoScreenState();
}

class _MedicalInfoScreenState extends State<MedicalInfoScreen> {
  bool _isLoading = true;
  MedicalInfo _info = const MedicalInfo();

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
    final info = MedicalInfo.parse(row?['medical_info'] as String?);
    if (mounted) {
      setState(() {
        _info = info;
        _isLoading = false;
      });
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditMedicalInfoScreen(info: _info)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Info Card'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _edit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        ],
      ),
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
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _MedicalInfoTile(
                            icon: Icons.bloodtype_outlined,
                            label: 'Blood Type',
                            value: _info.bloodType,
                          ),
                          const Divider(height: 1),
                          _MedicalInfoTile(
                            icon: Icons.warning_amber_outlined,
                            label: 'Allergies',
                            value: _info.allergies,
                          ),
                          const Divider(height: 1),
                          _MedicalInfoTile(
                            icon: Icons.medical_information_outlined,
                            label: 'Medical Conditions',
                            value: _info.conditions,
                          ),
                          const Divider(height: 1),
                          _MedicalInfoTile(
                            icon: Icons.note_alt_outlined,
                            label: 'Additional Notes',
                            value: _info.notes,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// A single read-only row: no `TextField`/`onTap`, so it can't open a
/// keyboard or any editing control — viewing this screen can never mutate
/// the underlying medical info.
class _MedicalInfoTile extends StatelessWidget {
  const _MedicalInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasValue = value != null && value!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasValue ? value! : 'Not set',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: hasValue ? null : colorScheme.onSurfaceVariant,
                    fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
