import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../data/safe_ride_repository.dart';
import '../domain/safe_ride_risk.dart';
import 'call_security_screen.dart';

/// "Safe Ride": check a lift/taxi's number plate against on-file offense
/// records before getting in, and report a vehicle immediately if
/// something goes wrong.
class SafeRideScreen extends StatefulWidget {
  const SafeRideScreen({super.key});

  @override
  State<SafeRideScreen> createState() => _SafeRideScreenState();
}

class _SafeRideScreenState extends State<SafeRideScreen> {
  final _repository = SafeRideRepository();
  final _plateController = TextEditingController();
  bool _isChecking = false;
  bool _hasChecked = false;
  Map<String, dynamic>? _record;
  String? _errorMessage;

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _checkPlate() async {
    final plate = _plateController.text.trim();
    if (plate.isEmpty) {
      setState(() => _errorMessage = 'Enter a number plate to check');
      return;
    }
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });
    try {
      final record = await _repository.lookupPlate(plate);
      setState(() {
        _record = record;
        _hasChecked = true;
      });
    } catch (_) {
      setState(() => _errorMessage = 'Could not check this plate. Try again.');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _openReportSheet() async {
    final reported = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReportVehicleSheet(
        repository: _repository,
        initialPlate: _plateController.text.trim(),
      ),
    );
    if (reported == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted — thank you for keeping others safe.')),
      );
      if (_hasChecked) _checkPlate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final offenses = _record == null
        ? const <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(_record!['vehicle_offenses'] as List);
    final risk = _record == null ? null : classifySafeRideRisk(offenses);

    return Scaffold(
      appBar: AppBar(title: const Text('Safe Ride')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Check a lift, taxi, or e-hailing number plate before you '
                'get in — this is simulated demo data, not a real police '
                'or traffic record.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _plateController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Number Plate',
                  hintText: 'e.g. CA123456',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                ),
                onSubmitted: (_) => _checkPlate(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isChecking ? null : _checkPlate,
                child: _isChecking
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text('Check Plate'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
              if (_hasChecked) ...[
                const SizedBox(height: 24),
                if (_record == null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.help_outline, color: colorScheme.outline),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'No record found for this plate. No history on '
                            "file doesn't guarantee safety — stay alert.",
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: risk!.color.withValues(alpha: 0.1),
                      border: Border.all(color: risk.color.withValues(alpha: 0.35)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(risk.icon, color: risk.color),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                risk.title,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: risk.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(risk.feedback),
                        const SizedBox(height: 12),
                        Text(
                          '${_record!['driver_name']} · '
                          '${[_record!['vehicle_colour'], _record!['vehicle_make'], _record!['vehicle_model']].where((v) => v != null).join(' ')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (risk == SafeRideRisk.danger) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.alert,
                              minimumSize: const Size(double.infinity, 44),
                            ),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CallSecurityScreen()),
                            ),
                            icon: const Icon(Icons.local_police_outlined),
                            label: const Text('Call Security'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (offenses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'On file (${offenses.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ...offenses.map(
                      (o) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        color: colorScheme.surfaceContainerHigh,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          dense: true,
                          title: Text(o['offense_type'] as String? ?? ''),
                          trailing: Chip(
                            label: Text(severityLabel(o['severity'] as String)),
                            labelStyle: const TextStyle(fontSize: 10),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.alert,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: _openReportSheet,
                icon: const Icon(Icons.report_gmailerrorred_outlined),
                label: const Text('Report This Car'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportVehicleSheet extends StatefulWidget {
  const _ReportVehicleSheet({required this.repository, required this.initialPlate});

  final SafeRideRepository repository;
  final String initialPlate;

  @override
  State<_ReportVehicleSheet> createState() => _ReportVehicleSheetState();
}

class _ReportVehicleSheetState extends State<_ReportVehicleSheet> {
  late final _plateController = TextEditingController(text: widget.initialPlate);
  final _driverController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _plateController.dispose();
    _driverController.dispose();
    _vehicleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_plateController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Enter the number plate');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Describe what happened');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final userId = SupabaseService.client.auth.currentUser!.id;
      final vehicleParts = _vehicleController.text.trim().split(RegExp(r'\s+'));
      await widget.repository.reportVehicle(
        plate: _plateController.text.trim(),
        studentId: userId,
        description: _descriptionController.text.trim(),
        driverName: _driverController.text.trim().isEmpty ? null : _driverController.text.trim(),
        vehicleMake: vehicleParts.isNotEmpty ? vehicleParts.first : null,
        vehicleModel: vehicleParts.length > 1 ? vehicleParts.sublist(1).join(' ') : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      setState(() => _errorMessage = 'Could not submit this report. Try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Report This Car', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Takes effect immediately and adds to this plate\'s record.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Number Plate',
                prefixIcon: Icon(Icons.directions_car_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _driverController,
              decoration: const InputDecoration(
                labelText: 'Driver Name (optional)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vehicleController,
              decoration: const InputDecoration(
                labelText: 'Vehicle (optional)',
                hintText: 'e.g. White Toyota Corolla',
                prefixIcon: Icon(Icons.local_taxi_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                alignLabelWithHint: true,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }
}
