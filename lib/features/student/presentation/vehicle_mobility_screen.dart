import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import 'edit_vehicle_mobility_info_screen.dart';

/// View-only by design, so the student can't accidentally change vehicle
/// or mobility info while just checking what's on file. Editing happens on
/// [EditVehicleMobilityInfoScreen], reached via the AppBar "Edit" action —
/// same pattern as the Medical Info Card / [EditMedicalInfoScreen].
class VehicleMobilityScreen extends StatefulWidget {
  const VehicleMobilityScreen({super.key});

  @override
  State<VehicleMobilityScreen> createState() => _VehicleMobilityScreenState();
}

class _VehicleMobilityScreenState extends State<VehicleMobilityScreen> {
  bool _isLoading = true;
  String _vehicleInfo = '';
  String _mobilityNotes = '';

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
    if (mounted) {
      setState(() {
        _vehicleInfo = (row?['vehicle_info'] as String?) ?? '';
        _mobilityNotes = (row?['mobility_notes'] as String?) ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditVehicleMobilityInfoScreen(
          vehicleInfo: _vehicleInfo,
          mobilityNotes: _mobilityNotes,
        ),
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle & Mobility Info'),
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
                      'Both optional. Only visible to a responder during an '
                      'active alert — never public, never browsable by admin.',
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
                          _VehicleMobilityTile(
                            icon: Icons.directions_car_outlined,
                            label: 'Vehicle Info',
                            value: _vehicleInfo,
                          ),
                          const Divider(height: 1),
                          _VehicleMobilityTile(
                            icon: Icons.accessible_outlined,
                            label: 'Mobility Notes',
                            value: _mobilityNotes,
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
/// the underlying vehicle/mobility info.
class _VehicleMobilityTile extends StatelessWidget {
  const _VehicleMobilityTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasValue = value.trim().isNotEmpty;

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
                  hasValue ? value : 'Not set',
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
