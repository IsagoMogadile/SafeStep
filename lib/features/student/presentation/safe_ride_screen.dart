import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/location_service.dart';
import '../../../core/location/route_service.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../data/safe_ride_repository.dart';
import '../domain/safe_ride_risk.dart';
import 'call_security_screen.dart';

/// Picks the recognized text line that looks most like a number plate:
/// letters and digits only, 5-8 characters, containing at least one of
/// each — good enough for a demo scan, not a certified ANPR system.
String? _bestPlateGuess(RecognizedText result) {
  final candidates = <String>[];
  for (final block in result.blocks) {
    for (final line in block.lines) {
      final cleaned = line.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (cleaned.length < 5 || cleaned.length > 8) continue;
      final hasLetter = RegExp(r'[A-Z]').hasMatch(cleaned);
      final hasDigit = RegExp(r'[0-9]').hasMatch(cleaned);
      if (hasLetter && hasDigit) candidates.add(cleaned);
    }
  }
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => b.length.compareTo(a.length));
  return candidates.first;
}

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
  final _destinationController = TextEditingController();
  final _textRecognizer = TextRecognizer();
  bool _isChecking = false;
  bool _isScanning = false;
  bool _isEstimatingDrive = false;
  bool _hasChecked = false;
  Map<String, dynamic>? _record;
  String? _errorMessage;
  int? _driveMinutes;
  String? _driveEstimateError;

  @override
  void dispose() {
    _plateController.dispose();
    _destinationController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  /// Informational only — no journey tracking, no check-ins, just "about
  /// how long is this drive" so the student has context, same idea as
  /// the walking-time estimate in Safe Walks but for a car.
  Future<void> _estimateDriveTime() async {
    if (_destinationController.text.trim().isEmpty) {
      setState(() => _driveEstimateError = 'Enter a destination first');
      return;
    }
    setState(() {
      _isEstimatingDrive = true;
      _driveEstimateError = null;
      _driveMinutes = null;
    });
    try {
      final position = await LocationService.getCurrentLocation();
      if (position == null) {
        setState(() => _driveEstimateError = "Couldn't get your current location");
        return;
      }
      final origin = LatLng(position.latitude, position.longitude);
      final destination = await RouteService.geocode(_destinationController.text.trim());
      if (destination == null) {
        setState(() => _driveEstimateError = "Couldn't find that destination");
        return;
      }
      final minutes = await RouteService.estimateDurationMinutes(
        origin,
        destination,
        profile: 'driving',
      );
      if (minutes == null) {
        setState(() => _driveEstimateError = "Couldn't estimate a drive time for that route");
        return;
      }
      setState(() => _driveMinutes = minutes);
    } finally {
      if (mounted) setState(() => _isEstimatingDrive = false);
    }
  }

  Future<void> _scanPlate() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
    );
    if (photo == null || !mounted) return;

    setState(() => _isScanning = true);
    try {
      final result = await _textRecognizer.processImage(
        InputImage.fromFilePath(photo.path),
      );
      final guess = _bestPlateGuess(result);
      if (!mounted) return;
      if (guess != null) {
        setState(() => _plateController.text = guess);
        _checkPlate();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't read a plate from that photo — try again, or type it in.",
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
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
        existingRecord: _record,
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
        : List<Map<String, dynamic>>.from(_record!['vehicle_offenses'] as List)
            // A student report only affects what other students see once
            // an admin has reviewed it — never posted straight from the
            // reporter (see _ReportVehicleSheet / SafeRideRepository).
            .where((o) => o['status'] == 'approved')
            .toList();
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
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isScanning ? null : _scanPlate,
                icon: _isScanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.camera_alt_outlined),
                label: Text(_isScanning ? 'Reading plate…' : 'Scan plate with camera'),
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
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Text('Estimate drive time', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Informational only — not tracked, no check-ins.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _destinationController,
                decoration: InputDecoration(
                  labelText: 'Destination (optional)',
                  prefixIcon: const Icon(Icons.flag_outlined),
                  suffixIcon: _isEstimatingDrive
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.directions_car),
                          tooltip: 'Estimate drive time',
                          onPressed: _estimateDriveTime,
                        ),
                ),
                onSubmitted: (_) => _estimateDriveTime(),
              ),
              if (_driveEstimateError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _driveEstimateError!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
              if (_driveMinutes != null) ...[
                const SizedBox(height: 8),
                Text(
                  '~$_driveMinutes min drive from your current location',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                            'No ride info — this plate isn\'t a registered '
                            'e-hailing/taxi driver on file. No record doesn\'t '
                            'guarantee safety — stay alert.',
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
                          _record!['driver_name'] as String? ?? 'Unknown driver',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          [
                            _record!['vehicle_colour'],
                            _record!['vehicle_make'],
                            _record!['vehicle_model'],
                          ].where((v) => v != null).join(' '),
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
  const _ReportVehicleSheet({
    required this.repository,
    required this.initialPlate,
    this.existingRecord,
  });

  final SafeRideRepository repository;
  final String initialPlate;

  /// The vehicle_records row already on file for this plate, if the
  /// student just checked it — auto-fills driver/vehicle details instead
  /// of asking the student to re-type facts the app already knows.
  final Map<String, dynamic>? existingRecord;

  @override
  State<_ReportVehicleSheet> createState() => _ReportVehicleSheetState();
}

class _ReportVehicleSheetState extends State<_ReportVehicleSheet> {
  late final _plateController = TextEditingController(text: widget.initialPlate);
  late final _driverController = TextEditingController(
    text: widget.existingRecord?['driver_name'] as String? ?? '',
  );
  late final _vehicleController = TextEditingController(
    text: [
      widget.existingRecord?['vehicle_colour'],
      widget.existingRecord?['vehicle_make'],
      widget.existingRecord?['vehicle_model'],
    ].where((v) => v != null).join(' '),
  );
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isKnownVehicle => widget.existingRecord != null;

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
              'An admin reviews every report before it affects this plate\'s '
              'record — you\'ll be notified once it\'s resolved.',
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
              enabled: !_isKnownVehicle,
              decoration: InputDecoration(
                labelText: _isKnownVehicle ? 'Driver Name (on file)' : 'Driver Name (optional)',
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _vehicleController,
              enabled: !_isKnownVehicle,
              decoration: InputDecoration(
                labelText: _isKnownVehicle ? 'Vehicle (on file)' : 'Vehicle (optional)',
                hintText: 'e.g. White Toyota Corolla',
                prefixIcon: const Icon(Icons.local_taxi_outlined),
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
