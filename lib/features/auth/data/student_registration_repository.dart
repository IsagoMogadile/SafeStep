import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';
import '../domain/campus.dart';
import '../domain/student_details.dart';

class StudentRegistrationRepository {
  StudentRegistrationRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<Campus>> fetchCampuses() async {
    final rows = await _client
        .from('campuses')
        .select('campus_id, name')
        .order('name');
    return rows.map((row) => Campus.fromRow(row)).toList();
  }

  /// Creates (or, if the student went back and edited earlier steps,
  /// updates) the `students` row for a just-registered auth user. The
  /// row's primary key is the auth user id itself (scope.md §9:
  /// `students.student_id` -> `auth.users(id)`). Called once the core
  /// wizard steps (about you / DOB & gender / faculty & residence /
  /// address) are done, so later steps (trusted contacts, optional
  /// vehicle & mobility) have a student row to attach to. Uses upsert so
  /// navigating back to an earlier step and changing something actually
  /// persists instead of being silently dropped.
  Future<void> upsertStudent({
    required String studentId,
    required String email,
    required StudentDetails details,
  }) async {
    await _client.from('students').upsert({
      'student_id': studentId,
      'email': email,
      'full_name': details.fullName,
      'phone': details.phone,
      'dob': details.dob.toIso8601String().split('T').first,
      'gender': details.gender,
      'faculty_year': details.facultyYear,
      'residence_type': details.residenceType,
      'address': details.address,
      'primary_campus_id': details.primaryCampusId,
    });
  }

  /// Optional restricted-tier fields (scope.md §5), collected as the last,
  /// skippable wizard step.
  Future<void> updateVehicleAndMobility({
    required String studentId,
    String? vehicleInfo,
    String? mobilityNotes,
  }) async {
    await _client
        .from('students')
        .update({
          if (vehicleInfo != null && vehicleInfo.isNotEmpty)
            'vehicle_info': vehicleInfo,
          if (mobilityNotes != null && mobilityNotes.isNotEmpty)
            'mobility_notes': mobilityNotes,
        })
        .eq('student_id', studentId);
  }
}
