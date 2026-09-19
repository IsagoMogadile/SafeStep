import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';

class TrustedContactRepository {
  TrustedContactRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchForStudent(String studentId) {
    return _client
        .from('trusted_contacts')
        .select()
        .eq('student_id', studentId)
        .order('created_at');
  }

  /// Auto-links a contact to an existing SafeStep account by email or
  /// phone (scope.md §5) via the `find_student_by_contact` RPC
  /// (supabase/migrations/0001_phone_and_contact_lookup.sql) — a narrow
  /// SECURITY DEFINER function that only ever returns a single
  /// student_id, never a full row, so it's safe to expose to any
  /// authenticated user despite bypassing student-row RLS. Falls back to
  /// `sms_only` if the migration hasn't been applied yet (RPC missing) or
  /// no match is found.
  Future<void> addContact({
    required String studentId,
    required String name,
    required String relationship,
    String? email,
    String? phone,
  }) async {
    String? linkedStudentId;
    try {
      linkedStudentId = await _client.rpc(
        'find_student_by_contact',
        params: {'p_email': email, 'p_phone': phone},
      );
    } catch (_) {
      // Migration not applied yet, or no match — fall back below.
    }

    await _client.from('trusted_contacts').insert({
      'student_id': studentId,
      'name': name,
      'relationship': relationship,
      'email': email,
      'phone': phone,
      'linked_student_id': linkedStudentId,
      'status': linkedStudentId != null ? 'app_linked' : 'sms_only',
    });
  }

  /// Re-runs the same app-account lookup as [addContact] — if the edited
  /// email/phone now matches (or no longer matches) an existing SafeStep
  /// account, the linked status is updated to reflect that rather than
  /// staying stuck at whatever it was when the contact was first added.
  Future<void> updateContact({
    required String contactId,
    required String name,
    required String relationship,
    String? email,
    String? phone,
  }) async {
    String? linkedStudentId;
    try {
      linkedStudentId = await _client.rpc(
        'find_student_by_contact',
        params: {'p_email': email, 'p_phone': phone},
      );
    } catch (_) {
      // Migration not applied yet, or no match — fall back below.
    }

    await _client
        .from('trusted_contacts')
        .update({
          'name': name,
          'relationship': relationship,
          'email': email,
          'phone': phone,
          'linked_student_id': linkedStudentId,
          'status': linkedStudentId != null ? 'app_linked' : 'sms_only',
        })
        .eq('contact_id', contactId);
  }

  Future<void> removeContact(String contactId) async {
    await _client.from('trusted_contacts').delete().eq('contact_id', contactId);
  }

  /// Re-creates a contact from the row data of one just removed — used
  /// for the "Undo" action on the remove-contact SnackBar. Gets a fresh
  /// contact_id rather than restoring the exact same row, which is fine
  /// since nothing else references a trusted_contacts row by id across a
  /// delete (alert_recipients cascades away with the original delete).
  Future<void> restoreContact(Map<String, dynamic> contact) async {
    await _client.from('trusted_contacts').insert({
      'student_id': contact['student_id'],
      'name': contact['name'],
      'relationship': contact['relationship'],
      'email': contact['email'],
      'phone': contact['phone'],
      'linked_student_id': contact['linked_student_id'],
      'status': contact['status'],
    });
  }
}
