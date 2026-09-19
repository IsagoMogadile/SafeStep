import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/location/route_service.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../data/walk_session_repository.dart';
import 'walk_active_screen.dart';

class WalkTimerScreen extends StatefulWidget {
  const WalkTimerScreen({super.key});

  @override
  State<WalkTimerScreen> createState() => _WalkTimerScreenState();
}

class _WalkTimerScreenState extends State<WalkTimerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _startLocationController = TextEditingController();
  final _destinationController = TextEditingController();
  final _timerController = TextEditingController(text: '15');
  final _repository = WalkSessionRepository();

  late final Future<List<Map<String, dynamic>>> _contactsFuture;
  final _selectedContactIds = <String>{};
  double? _startLat;
  double? _startLng;
  bool _isLocating = false;
  bool _isSubmitting = false;
  bool _isEstimating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final userId = SupabaseService.client.auth.currentUser!.id;
    _contactsFuture = SupabaseService.client
        .from('trusted_contacts')
        .select('contact_id, name, relationship')
        .eq('student_id', userId)
        .order('name');
  }

  @override
  void dispose() {
    _startLocationController.dispose();
    _destinationController.dispose();
    _timerController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    final position = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _isLocating = false;
      if (position != null) {
        _startLat = position.latitude;
        _startLng = position.longitude;
        _startLocationController.text =
            '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}';
      }
    });
    if (position == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't get your location — check location permission is allowed",
          ),
        ),
      );
    }
  }

  /// Auto-fills the timer from a real walking-route estimate instead of
  /// leaving the student to guess a number of minutes — feedback:
  /// "students don't have to manually add estimated time." Still just
  /// fills the field; they can override it afterward same as before.
  Future<void> _estimateTimer() async {
    if (_destinationController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Enter a destination first');
      return;
    }
    setState(() {
      _isEstimating = true;
      _errorMessage = null;
    });
    try {
      var origin = (_startLat != null && _startLng != null)
          ? LatLng(_startLat!, _startLng!)
          : null;
      if (origin == null) {
        final position = await LocationService.getCurrentLocation();
        if (position != null) {
          origin = LatLng(position.latitude, position.longitude);
        }
      }
      if (origin == null) {
        setState(() => _errorMessage = "Couldn't get your location to estimate from");
        return;
      }

      final destination = await RouteService.geocode(_destinationController.text.trim());
      if (destination == null) {
        setState(() => _errorMessage = "Couldn't find that destination");
        return;
      }

      final minutes = await RouteService.estimateDurationMinutes(
        origin,
        destination,
        profile: 'foot',
      );
      if (minutes == null) {
        setState(() => _errorMessage = "Couldn't estimate a time for that route");
        return;
      }
      // OSRM assumes brisk, uninterrupted walking — real walks run longer
      // (crossings, pace at night), so pad the raw estimate rather than
      // risk the missed-check-in escalation firing on a normal walk.
      const safetyBufferMinutes = 5;
      setState(() => _timerController.text = (minutes + safetyBufferMinutes).toString());
    } finally {
      if (mounted) setState(() => _isEstimating = false);
    }
  }

  Future<void> _start() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final userId = SupabaseService.client.auth.currentUser!.id;
      final session = await _repository.createTimerSession(
        studentId: userId,
        destination: _destinationController.text.trim(),
        timerMinutes: int.parse(_timerController.text.trim()),
        startLocationText: _startLocationController.text.trim().isEmpty
            ? null
            : _startLocationController.text.trim(),
        startLat: _startLat,
        startLng: _startLng,
        monitorContactIds: _selectedContactIds.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => WalkActiveScreen(session: session)),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Could not start your journey. Try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitor My Journey')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _startLocationController,
                  decoration: InputDecoration(
                    labelText: 'Start Location (optional)',
                    hintText: 'Where are you starting from?',
                    prefixIcon: const Icon(Icons.trip_origin),
                    suffixIcon: _isLocating
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.my_location),
                            tooltip: 'Use current location',
                            onPressed: _useCurrentLocation,
                          ),
                  ),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _timerController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Timer (minutes)',
                    prefixIcon: const Icon(Icons.timer_outlined),
                    suffixIcon: _isEstimating
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.directions_walk),
                            tooltip: 'Estimate from walking route',
                            onPressed: _estimateTimer,
                          ),
                  ),
                  validator: (value) {
                    final n = int.tryParse(value ?? '');
                    if (n == null || n <= 0) return 'Enter minutes as a number';
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap the walking icon to estimate this from a real route '
                  '(plus a 5 min buffer) instead of guessing — you can still '
                  'adjust it after.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Who should monitor this journey?',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Optional — if you miss a check-in, every trusted contact '
                  'is still alerted regardless of this selection.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
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
                      return const Text('Add a trusted contact first from Profile.');
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: contacts.map((c) {
                        final id = c['contact_id'] as String;
                        final selected = _selectedContactIds.contains(id);
                        return FilterChip(
                          label: Text(c['name'] as String? ?? ''),
                          selected: selected,
                          onSelected: (value) => setState(() {
                            if (value) {
                              _selectedContactIds.add(id);
                            } else {
                              _selectedContactIds.remove(id);
                            }
                          }),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  "If your timer runs out without a check-in, we'll ask if "
                  "you're okay — and escalate to a full alert after 5 more "
                  'minutes if there\'s no response.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  onPressed: _isSubmitting ? null : _start,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Start Journey'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
