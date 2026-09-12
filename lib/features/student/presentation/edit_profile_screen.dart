import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/storage/storage_uploader.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../auth/domain/nmu_faculties.dart';
import '../../auth/domain/student_details.dart';
import '../../auth/domain/campus.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _uploader = StorageUploader();
  final _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _errorMessage;
  String? _avatarUrl;
  String? _selectedCampusId;
  String? _selectedFaculty;
  String? _selectedYear;
  String? _residenceType;
  List<Campus> _campuses = [];

  String get _userId => SupabaseService.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final campusRows = await SupabaseService.client
        .from('campuses')
        .select('campus_id, name')
        .order('name');
    final row = await SupabaseService.client
        .from('students')
        .select()
        .eq('student_id', _userId)
        .maybeSingle();

    _campuses = campusRows.map((r) => Campus.fromRow(r)).toList();
    _fullNameController.text = (row?['full_name'] as String?) ?? '';
    _phoneController.text = (row?['phone'] as String?) ?? '';
    _addressController.text = (row?['address'] as String?) ?? '';
    _avatarUrl = row?['avatar_url'] as String?;
    _selectedCampusId = row?['primary_campus_id'] as String?;
    // Guard against stray/legacy data that doesn't exactly match a known
    // option — DropdownButtonFormField throws if initialValue is non-null
    // but isn't one of its items, rather than just showing unselected.
    final residenceType = row?['residence_type'] as String?;
    if (residenceType != null && residenceTypeOptions.contains(residenceType)) {
      _residenceType = residenceType;
    }

    final facultyYear = row?['faculty_year'] as String?;
    if (facultyYear != null && facultyYear.contains(',')) {
      final parts = facultyYear.split(',');
      final faculty = parts.first.trim();
      final year = parts.sublist(1).join(',').trim();
      if (nmuFaculties.contains(faculty)) _selectedFaculty = faculty;
      if (yearOfStudyOptions.contains(year)) _selectedYear = year;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _changeAvatar() async {
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
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final url = await _uploader.uploadImage(
        bucket: 'avatars',
        userId: _userId,
        file: File(picked.path),
        filename: 'avatar.jpg',
      );
      // Cache-bust so the new image actually shows (same filename/URL).
      final bustedUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      await SupabaseService.client
          .from('students')
          .update({'avatar_url': bustedUrl})
          .eq('student_id', _userId);
      if (mounted) setState(() => _avatarUrl = bustedUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload photo')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.client
          .from('students')
          .update({
            'full_name': _fullNameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'primary_campus_id': _selectedCampusId,
            'residence_type': _residenceType,
            if (_selectedFaculty != null && _selectedYear != null)
              'faculty_year': '$_selectedFaculty, $_selectedYear',
          })
          .eq('student_id', _userId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _errorMessage = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: colorScheme.primaryContainer,
                              backgroundImage: _avatarUrl != null
                                  ? NetworkImage(_avatarUrl!)
                                  : null,
                              child: _avatarUrl == null
                                  ? Icon(
                                      Icons.person,
                                      size: 44,
                                      color: colorScheme.onPrimaryContainer,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Material(
                                color: colorScheme.primary,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _isUploadingAvatar ? null : _changeAvatar,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: _isUploadingAvatar
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: colorScheme.onPrimary,
                                            ),
                                          )
                                        : Icon(
                                            Icons.camera_alt_outlined,
                                            size: 16,
                                            color: colorScheme.onPrimary,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'Enter your full name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Cellphone Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCampusId,
                        decoration: const InputDecoration(
                          labelText: 'Primary Campus',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        items: _campuses
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedCampusId = value),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedFaculty,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Faculty',
                          prefixIcon: Icon(Icons.menu_book_outlined),
                        ),
                        items: nmuFaculties
                            .map(
                              (f) => DropdownMenuItem(
                                value: f,
                                child: Text(f, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedFaculty = value),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Year of Study',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        items: yearOfStudyOptions
                            .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedYear = value),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _residenceType,
                        decoration: const InputDecoration(
                          labelText: 'Residence Type',
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                        items: residenceTypeOptions
                            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _residenceType = value),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Residential Address',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4),
                              )
                            : const Text('Save Changes'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
