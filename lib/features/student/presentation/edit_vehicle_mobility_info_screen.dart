import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';

/// The only screen on the student side where vehicle/mobility info is
/// actually editable — reached via the "Edit" action on the view-only
/// Vehicle & Mobility Info card, never inline on that screen. Saves through
/// the existing `students.vehicle_info` / `students.mobility_notes`
/// columns, same as the wizard step and the old combined screen did.
class EditVehicleMobilityInfoScreen extends StatefulWidget {
  const EditVehicleMobilityInfoScreen({
    super.key,
    required this.vehicleInfo,
    required this.mobilityNotes,
  });

  final String vehicleInfo;
  final String mobilityNotes;

  @override
  State<EditVehicleMobilityInfoScreen> createState() =>
      _EditVehicleMobilityInfoScreenState();
}

class _EditVehicleMobilityInfoScreenState
    extends State<EditVehicleMobilityInfoScreen> {
  final _vehicleController = TextEditingController();
  final _mobilityController = TextEditingController();
  bool _isSaving = false;

  String get _userId => SupabaseService.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _vehicleController.text = widget.vehicleInfo;
    _mobilityController.text = widget.mobilityNotes;
  }

  @override
  void dispose() {
    _vehicleController.dispose();
    _mobilityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await SupabaseService.client
          .from('students')
          .update({
            'vehicle_info': _vehicleController.text.trim(),
            'mobility_notes': _mobilityController.text.trim(),
          })
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
      appBar: AppBar(title: const Text('Edit Vehicle & Mobility Info')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Both optional. Only visible to a responder during an '
                'active alert — never public, never browsable by admin.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vehicleController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Info',
                  hintText: 'Make, model, colour, plate',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobilityController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mobility Notes',
                  hintText: 'Anything responders should know',
                  prefixIcon: Icon(Icons.accessible_outlined),
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
    );
  }
}
