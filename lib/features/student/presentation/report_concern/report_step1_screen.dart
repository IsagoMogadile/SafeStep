import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/location/location_service.dart';
import 'report_step2_screen.dart';

const _categories = [
  'Suspicious activity',
  'Harassment',
  'Theft',
  'Broken lighting',
  'Unsafe area',
  'Other',
];

/// Report flow is one combined details screen, then review — not a
/// multi-step wizard (scope.md §5 / §11). The student enters their own
/// location in free text (or taps "Use current location"), rather than
/// picking from a fixed zone list.
class ReportStep1Screen extends StatefulWidget {
  const ReportStep1Screen({super.key});

  @override
  State<ReportStep1Screen> createState() => _ReportStep1ScreenState();
}

class _ReportStep1ScreenState extends State<ReportStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  String _category = _categories.first;
  bool _anonymous = false;
  bool _followUpRequested = false;
  bool _isLocating = false;
  Position? _currentPosition;
  File? _photo;

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    final position = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _isLocating = false;
      if (position != null) {
        _currentPosition = position;
        _locationController.text =
            '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}';
      }
    });
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't get your location — check location permission is allowed",
          ),
        ),
      );
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  void _review() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportStep2Screen(
          category: _category,
          locationText: _locationController.text.trim(),
          lat: _currentPosition?.latitude,
          lng: _currentPosition?.longitude,
          description: _descriptionController.text.trim(),
          anonymous: _anonymous,
          followUpRequested: _followUpRequested,
          photo: _photo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a Concern')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'What happened, and where?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a category and add the details.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((c) {
                    return ChoiceChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    hintText: 'e.g. South Campus, near Parking Zone B',
                    prefixIcon: const Icon(Icons.place_outlined),
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
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter a location'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: "Share as much detail as you're comfortable with…",
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Add a description'
                      : null,
                ),
                const SizedBox(height: 16),
                if (_photo != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _photo!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 18),
                            onPressed: () => setState(() => _photo = null),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Add Photo (optional)'),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Report anonymously'),
                      subtitle: const Text(
                        "Your name won't be attached to this report",
                      ),
                      value: _anonymous,
                      onChanged: (value) => setState(() => _anonymous = value),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Request follow-up'),
                      subtitle: const Text(
                        'Admin or student support will reach out about this report',
                      ),
                      value: _followUpRequested,
                      onChanged: (value) =>
                          setState(() => _followUpRequested = value),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _review,
                  child: const Text('Review Report'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
