import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../student/presentation/student_home_shell.dart';
import '../data/student_registration_repository.dart';
import '../data/trusted_contact_repository.dart';
import '../domain/campus.dart';
import '../domain/nmu_faculties.dart';
import '../domain/student_details.dart';
import 'welcome_screen.dart';
import 'widgets/add_contact_sheet.dart';

/// Post-signup details wizard (scope.md §5 "Registration" row + trusted
/// contacts, matching docs/prototype.html's registration flow): primary
/// campus & full name, DOB & gender, faculty & year & residence type,
/// address, trusted contacts (min 3), then optional vehicle & mobility
/// info before landing on Home.
class StudentWizardScreen extends StatefulWidget {
  const StudentWizardScreen({
    super.key,
    required this.userId,
    required this.email,
  });

  final String userId;
  final String email;

  @override
  State<StudentWizardScreen> createState() => _StudentWizardScreenState();
}

class _StudentWizardScreenState extends State<StudentWizardScreen> {
  final _repository = StudentRegistrationRepository();
  final _contactRepository = TrustedContactRepository();
  final _pageController = PageController();

  final _aboutYouFormKey = GlobalKey<FormState>();
  final _addressFormKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _vehicleInfoController = TextEditingController();
  final _mobilityNotesController = TextEditingController();

  late Future<List<Campus>> _campusesFuture;
  int _step = 0;
  String? _selectedCampusId;
  DateTime? _dob;
  String? _gender;
  String? _selectedFaculty;
  String? _selectedYear;
  String? _residenceType;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _contacts = [];

  static const _totalSteps = 6;
  static const _minContacts = 3;

  @override
  void initState() {
    super.initState();
    _campusesFuture = _repository.fetchCampuses();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _vehicleInfoController.dispose();
    _mobilityNotesController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _next() async {
    switch (_step) {
      case 0:
        if (!_aboutYouFormKey.currentState!.validate()) return;
        if (_selectedCampusId == null) {
          setState(() => _errorMessage = 'Select your primary campus');
          return;
        }
      case 1:
        if (_dob == null) {
          setState(() => _errorMessage = 'Select your date of birth');
          return;
        }
        if (_gender == null) {
          setState(() => _errorMessage = 'Select a gender option');
          return;
        }
      case 2:
        if (_selectedFaculty == null) {
          setState(() => _errorMessage = 'Select your faculty');
          return;
        }
        if (_selectedYear == null) {
          setState(() => _errorMessage = 'Select your year of study');
          return;
        }
        if (_residenceType == null) {
          setState(() => _errorMessage = 'Select your residence type');
          return;
        }
      case 3:
        if (!_addressFormKey.currentState!.validate()) return;
        if (!await _saveStudentRow()) return;
      case 4:
        if (_contacts.length < _minContacts) {
          setState(
            () => _errorMessage =
                'Add at least $_minContacts trusted contacts to continue',
          );
          return;
        }
    }
    setState(() => _errorMessage = null);
    _goToStep(_step + 1);
  }

  /// Upsert so that going back to an earlier step and changing something
  /// (full name, faculty, address, ...) actually persists, rather than
  /// silently being dropped because the row already existed.
  Future<bool> _saveStudentRow() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _repository.upsertStudent(
        studentId: widget.userId,
        email: widget.email,
        details: StudentDetails(
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
          primaryCampusId: _selectedCampusId!,
          dob: _dob!,
          gender: _gender!,
          facultyYear: '$_selectedFaculty, $_selectedYear',
          residenceType: _residenceType!,
          address: _addressController.text.trim(),
        ),
      );
      return true;
    } catch (e) {
      setState(
        () => _errorMessage = 'Could not save your details. Please try again.',
      );
      return false;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openAddContactSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddContactSheet(
        studentId: widget.userId,
        repository: _contactRepository,
      ),
    );
    if (added == true) {
      final contacts = await _contactRepository.fetchForStudent(widget.userId);
      setState(() {
        _contacts = contacts;
        _errorMessage = null;
      });
    }
  }

  Future<void> _finish() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_vehicleInfoController.text.trim().isNotEmpty ||
          _mobilityNotesController.text.trim().isNotEmpty) {
        await _repository.updateVehicleAndMobility(
          studentId: widget.userId,
          vehicleInfo: _vehicleInfoController.text.trim(),
          mobilityNotes: _mobilityNotesController.text.trim(),
        );
      }
      _goHome();
    } catch (e) {
      setState(
        () => _errorMessage = 'Could not save. You can add this later from Profile.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StudentHomeShell()),
      (route) => false,
    );
  }

  Future<void> _cancelSetup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel account setup?'),
        content: const Text(
          "You'll need to log in again to pick up where you left off.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel Setup'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await SupabaseService.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 15),
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isLastStep = _step == _totalSteps - 1;
    final isContactsStep = _step == 4;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_step == 0) {
          _cancelSetup();
        } else {
          _goToStep(_step - 1);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Your Profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _step == 0 ? _cancelSetup : () => _goToStep(_step - 1),
          ),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                child: LinearProgressIndicator(
                  value: (_step + 1) / _totalSteps,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Step ${_step + 1} of $_totalSteps',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildAboutYouStep(),
                    _buildDobGenderStep(),
                    _buildFacultyResidenceStep(),
                    _buildAddressStep(),
                    _buildTrustedContactsStep(),
                    _buildVehicleMobilityStep(),
                  ],
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    if (isContactsStep)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OutlinedButton.icon(
                          onPressed: _openAddContactSheet,
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: const Text('Add Contact'),
                        ),
                      ),
                    ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : (isLastStep ? _finish : _next),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : Text(isLastStep ? 'Finish Setup' : 'Continue'),
                    ),
                    if (isLastStep)
                      TextButton(
                        onPressed: _isSubmitting ? null : _goHome,
                        child: const Text('Skip for now'),
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

  Widget _buildAboutYouStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _aboutYouFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('About you', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
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
                hintText: '+27 82 000 0000',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter your cellphone number'
                  : null,
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Campus>>(
              future: _campusesFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  );
                }
                final campuses = snapshot.data!;
                return DropdownButtonFormField<String>(
                  initialValue: _selectedCampusId,
                  decoration: const InputDecoration(
                    labelText: 'Primary Campus',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  items: campuses
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedCampusId = value),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDobGenderStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Date of birth & gender',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickDob,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                prefixIcon: Icon(Icons.cake_outlined),
              ),
              child: Text(
                _dob == null
                    ? 'Select a date'
                    : DateFormat('d MMMM yyyy').format(_dob!),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Gender', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: genderOptions.map((option) {
              final selected = _gender == option;
              return ChoiceChip(
                label: Text(option),
                selected: selected,
                onSelected: (_) => setState(() => _gender = option),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyResidenceStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Faculty & residence',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
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
            onChanged: (value) => setState(() => _selectedFaculty = value),
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
          const SizedBox(height: 24),
          Text(
            'Residence Type',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _residenceType,
            onChanged: (value) => setState(() => _residenceType = value),
            child: Column(
              children: residenceTypeOptions
                  .map(
                    (option) => RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(option),
                      value: option,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _addressFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Residential address',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Full Residential Address',
                prefixIcon: Icon(Icons.home_outlined),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter your residential address'
                  : null,
            ),
            const SizedBox(height: 16),
            _InfoBanner(
              text:
                  'Your address is treated like medical info: hidden by '
                  'default, visible to a responder only while you have an '
                  'active alert.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustedContactsStep() {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Trusted contacts',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Add at least $_minContacts contacts (max 10). They\'ll be '
            'notified with your location whenever you send an alert.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_contacts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No contacts added yet',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ..._contacts.map(
              (contact) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 0,
                color: colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  title: Text(contact['name'] as String? ?? ''),
                  subtitle: Text(contact['relationship'] as String? ?? ''),
                  trailing: Chip(
                    label: Text(
                      contact['status'] == 'app_linked'
                          ? 'App linked'
                          : 'SMS only',
                    ),
                    labelStyle: const TextStyle(fontSize: 11),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVehicleMobilityStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Vehicle & mobility info',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Both optional. Only visible to a responder during an active '
            'alert — never public, never browsable by admin.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _vehicleInfoController,
            decoration: const InputDecoration(
              labelText: 'Vehicle Info (optional)',
              hintText: 'Make, model, colour, plate',
              prefixIcon: Icon(Icons.directions_car_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _mobilityNotesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Mobility Notes (optional)',
              hintText: 'Anything responders should know',
              prefixIcon: Icon(Icons.accessible_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
