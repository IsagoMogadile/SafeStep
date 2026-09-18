/// Shared field validators for `Form`/`TextFormField` across the app —
/// centralised so every form gets the same rules instead of each screen
/// inventing its own ad-hoc `.isEmpty` check with no user-facing message.
library;

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _phonePattern = RegExp(r'^[0-9+()\-\s]{7,15}$');

String? requiredValidator(String? value, {String field = 'This field'}) {
  if (value == null || value.trim().isEmpty) return '$field is required';
  return null;
}

String? emailValidator(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return 'Email is required';
  if (!_emailPattern.hasMatch(trimmed)) return 'Enter a valid email address';
  return null;
}

/// Optional by default — pass `required: true` for a field that must be
/// filled in (e.g. a trusted contact's phone when no email was given).
String? phoneValidator(String? value, {bool required = false}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return required ? 'Phone number is required' : null;
  if (!_phonePattern.hasMatch(trimmed)) return 'Enter a valid phone number';
  return null;
}
