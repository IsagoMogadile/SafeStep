import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';

/// Editable from Profile after registration too — the wizard step is
/// skippable, so students should be able to fill this in later.
class VehicleMobilityScreen extends StatefulWidget {
  const VehicleMobilityScreen({super.key});

  @override
  State<VehicleMobilityScreen> createState() => _VehicleMobilityScreenState();
}

class _VehicleMobilityScreenState extends State<VehicleMobilityScreen> {
  final _vehicleController = TextEditingController();
  final _mobilityController = TextEditingController();
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
        .select('vehicle_info, mobility_notes')
        .eq('student_id', _userId)
        .maybeSingle();
    _vehicleController.text = (row?['vehicle_info'] as String?) ?? '';
    _mobilityController.text = (row?['mobility_notes'] as String?) ?? '';
    if (mounted) setState(() => _isLoading = false);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _vehicleController.dispose();
    _mobilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle & Mobility Info')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
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
