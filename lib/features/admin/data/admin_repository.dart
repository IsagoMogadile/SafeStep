import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_service.dart';

/// Admin dashboard data access (scope.md §7). RLS for every table here is
/// already gated by the `is_admin()` Postgres function (checks the
/// `admins` row for the signed-in user's `user_id`) — this repository
/// just issues normal authenticated queries, the same way every other
/// repository in the app does; there is no service-role/back-door client
/// on the admin surface.
class AdminRepository {
  AdminRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  // ---- audit trail -----------------------------------------------------
  //
  // Every mutating method below calls this once its write succeeds, so the
  // Audit Logs tab has a complete record of admin actions. Re-reads the
  // acting admin's identity from `admins` (rather than threading it through
  // every call site) so instrumenting a method never requires touching the
  // widgets that call it.

  Future<void> _logAction({
    required String action,
    String? targetType,
    String? targetId,
    String? details,
  }) async {
    final admin = await _client
        .from('admins')
        .select('admin_id, full_name')
        .eq('user_id', _client.auth.currentUser!.id)
        .maybeSingle();
    await _client.from('audit_logs').insert({
      'admin_id': admin?['admin_id'],
      'admin_name': admin?['full_name'] as String? ?? 'Unknown admin',
      'action': action,
      'target_type': targetType,
      'target_id': targetId,
      'details': details,
    });
  }

  Future<List<Map<String, dynamic>>> fetchAuditLogs({int limit = 300}) async {
    final rows = await _client
        .from('audit_logs')
        .select('*')
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  // ---- self / overview ----------------------------------------------

  Future<Map<String, dynamic>?> fetchSelf(String userId) {
    return _client
        .from('admins')
        .select('admin_id, full_name, email')
        .eq('user_id', userId)
        .maybeSingle();
  }

  Future<Map<String, int>> fetchOverviewCounts() async {
    final activeAlerts = await _client
        .from('alerts')
        .select('alert_id')
        .filter('status', 'in', '(new,acknowledged,dispatched)')
        .count(CountOption.exact);

    final weekAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String();
    final reportsThisWeek = await _client
        .from('incident_reports')
        .select('report_id')
        .gte('created_at', weekAgo)
        .count(CountOption.exact);

    final pendingGroups = await _client
        .from('walking_groups')
        .select('group_id')
        .eq('status', 'pending')
        .count(CountOption.exact);

    final pendingResources = await _client
        .from('resources')
        .select('resource_id')
        .eq('status', 'pending_verification')
        .count(CountOption.exact);

    final patrolRequests = await _client
        .from('walking_groups')
        .select('group_id')
        .eq('requested_patrol', true)
        .eq('status', 'approved')
        .count(CountOption.exact);

    return {
      'activeAlerts': activeAlerts.count,
      'reportsThisWeek': reportsThisWeek.count,
      'pendingGroups': pendingGroups.count,
      'pendingResources': pendingResources.count,
      'patrolRequests': patrolRequests.count,
    };
  }

  // ---- alerts (admin-wide, unscoped by zone) ---------------------------

  Future<List<Map<String, dynamic>>> fetchAlerts() async {
    final rows = await _client
        .from('alerts')
        .select('*, students(full_name), zones(name)')
        .order('triggered_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> fetchAlertDetail(String alertId) async {
    final alert = await _client
        .from('alerts')
        .select('*, students(full_name, medical_info), zones(name)')
        .eq('alert_id', alertId)
        .single();
    final recipients = await _client
        .from('alert_recipients')
        .select(
          'notified_at, acknowledged_at, '
          'responders(full_name, organization), trusted_contacts(name)',
        )
        .eq('alert_id', alertId)
        .order('notified_at');
    return {
      'alert': alert,
      'recipients': List<Map<String, dynamic>>.from(recipients),
    };
  }

  Future<void> dispatchAlert(String alertId) async {
    await _client.from('alerts').update({'status': 'dispatched'}).eq('alert_id', alertId);
    await _logAction(
      action: 'alert.dispatch',
      targetType: 'alert',
      targetId: alertId,
      details: 'Dispatched alert',
    );
  }

  Future<void> resolveAlert(String alertId, {String? notes}) async {
    await _client
        .from('alerts')
        .update({
          'status': 'resolved',
          if (notes != null && notes.isNotEmpty) 'responder_notes': notes,
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('alert_id', alertId);
    await _logAction(
      action: 'alert.resolve',
      targetType: 'alert',
      targetId: alertId,
      details: 'Resolved alert'
          '${notes != null && notes.isNotEmpty ? ' with notes' : ''}',
    );
  }

  Future<void> flagAlertFalseAlarm(String alertId) async {
    await _client
        .from('alerts')
        .update({'status': 'false_alarm_verify'})
        .eq('alert_id', alertId);
    await _logAction(
      action: 'alert.false_alarm_flag',
      targetType: 'alert',
      targetId: alertId,
      details: 'Flagged alert as a suspected false alarm',
    );
  }

  // ---- students (name/email/campus only — scope.md §5: DOB, gender,
  // faculty/year are admin-aggregate-only, never a browsable individual
  // profile field; address/vehicle/mobility/medical info are restricted
  // to a responder during that student's own active alert. None of those
  // fields are selected here.) ---------------------------------------

  Future<List<Map<String, dynamic>>> fetchStudents() async {
    final rows = await _client
        .from('students')
        .select('student_id, full_name, email, created_at, campuses(name)')
        .order('full_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  // ---- campuses / zones -----------------------------------------------

  Future<List<Map<String, dynamic>>> fetchCampuses() async {
    final rows = await _client.from('campuses').select('*').order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> fetchZones() async {
    final rows = await _client
        .from('zones')
        .select('*, campuses(name)')
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> createZone({
    required String name,
    required String areaType,
    String? campusId,
    required String riskStatus,
    required String coveredBy,
    double? lat,
    double? lng,
  }) async {
    await _client.from('zones').insert({
      'name': name,
      'area_type': areaType,
      'campus_id': campusId,
      'risk_status': riskStatus,
      'covered_by': coveredBy,
      'lat': lat,
      'lng': lng,
    });
    await _logAction(
      action: 'zone.create',
      targetType: 'zone',
      details: 'Created zone "$name"',
    );
  }

  Future<void> updateZone(String zoneId, Map<String, dynamic> patch) async {
    await _client.from('zones').update(patch).eq('zone_id', zoneId);
    await _logAction(
      action: 'zone.update',
      targetType: 'zone',
      targetId: zoneId,
      details: 'Updated zone "${patch['name'] ?? zoneId}"',
    );
  }

  Future<void> deleteZone(String zoneId) async {
    await _client.from('zones').delete().eq('zone_id', zoneId);
    await _logAction(
      action: 'zone.delete',
      targetType: 'zone',
      targetId: zoneId,
      details: 'Deleted zone',
    );
  }

  // ---- responders / admins ("people") ----------------------------------

  Future<List<Map<String, dynamic>>> fetchResponders() async {
    final rows = await _client
        .from('responders')
        .select('*, zones(name)')
        .order('full_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> fetchAdmins() async {
    final rows = await _client.from('admins').select('*').order('full_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> inviteResponder({
    required String email,
    required String fullName,
    String? phone,
    required String organization,
    String? coverageZoneId,
  }) async {
    await _client.from('responders').insert({
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'organization': organization,
      'coverage_zone_id': coverageZoneId,
      'activation_status': 'invited',
      'status': 'active',
    });
    await _logAction(
      action: 'responder.invite',
      targetType: 'responder',
      details: 'Invited responder $fullName ($email)',
    );
  }

  Future<void> inviteAdmin({
    required String email,
    required String fullName,
    required String phone,
  }) async {
    await _client.from('admins').insert({
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'activation_status': 'invited',
      'is_active': true,
    });
    await _logAction(
      action: 'admin.invite',
      targetType: 'admin',
      details: 'Invited admin $fullName ($email)',
    );
  }

  Future<void> setResponderDutyStatus(String responderId, String status) async {
    await _client
        .from('responders')
        .update({'status': status})
        .eq('responder_id', responderId);
    await _logAction(
      action: 'responder.status',
      targetType: 'responder',
      targetId: responderId,
      details: 'Set responder duty status to "$status"',
    );
  }

  Future<void> setAdminActive(String adminId, bool isActive) async {
    await _client
        .from('admins')
        .update({'is_active': isActive})
        .eq('admin_id', adminId);
    await _logAction(
      action: 'admin.active',
      targetType: 'admin',
      targetId: adminId,
      details: isActive ? 'Reactivated admin account' : 'Deactivated admin account',
    );
  }

  // ---- safety broadcasts -----------------------------------------------

  Future<List<Map<String, dynamic>>> fetchBroadcasts() async {
    final rows = await _client
        .from('safety_broadcasts')
        .select('*, campuses(name)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> createBroadcast({
    required String adminId,
    required String title,
    required String message,
    required String level,
    String? targetCampusId,
    DateTime? scheduledAt,
  }) async {
    final now = DateTime.now();
    final isImmediate = scheduledAt == null || !scheduledAt.isAfter(now);
    await _client.from('safety_broadcasts').insert({
      'title': title,
      'message': message,
      'level': level,
      'target_campus_id': targetCampusId,
      'created_by': adminId,
      // .toUtc(): the DB session timezone is UTC and reads an
      // offset-less timestamp as already UTC, so a local DateTime here
      // would silently store hours off by the device's own UTC offset.
      'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
      'sent_at': isImmediate ? now.toUtc().toIso8601String() : null,
    });
    await _logAction(
      action: 'broadcast.create',
      targetType: 'broadcast',
      details: 'Created ${isImmediate ? 'and sent' : 'a scheduled'} '
          'broadcast "$title" ($level)',
    );
  }

  Future<void> retractBroadcast(String broadcastId) async {
    await _client
        .from('safety_broadcasts')
        .update({'retracted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('broadcast_id', broadcastId);
    await _logAction(
      action: 'broadcast.retract',
      targetType: 'broadcast',
      targetId: broadcastId,
      details: 'Retracted broadcast',
    );
  }

  // ---- resources ---------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchResources() async {
    final rows = await _client
        .from('resources')
        .select('*')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> createResource({
    required String title,
    required String content,
    String? category,
    required String type,
  }) async {
    await _client.from('resources').insert({
      'title': title,
      'content': content,
      'category': category,
      'type': type,
      'status': 'published',
    });
    await _logAction(
      action: 'resource.create',
      targetType: 'resource',
      details: 'Added resource "$title"',
    );
  }

  Future<void> updateResource(String resourceId, Map<String, dynamic> patch) {
    return _client
        .from('resources')
        .update(patch)
        .eq('resource_id', resourceId);
  }

  Future<void> approveResource(String resourceId) async {
    await updateResource(resourceId, {'status': 'published'});
    await _logAction(
      action: 'resource.approve',
      targetType: 'resource',
      targetId: resourceId,
      details: 'Approved a community-submitted resource',
    );
  }

  Future<void> rejectResource(String resourceId) async {
    await _deleteResourceRow(resourceId);
    await _logAction(
      action: 'resource.reject',
      targetType: 'resource',
      targetId: resourceId,
      details: 'Rejected a community-submitted resource',
    );
  }

  Future<void> deleteResource(String resourceId) => _deleteResourceRow(resourceId);

  /// A Supabase `.delete()` that RLS blocks doesn't error — it just
  /// deletes zero rows and still returns HTTP 200, which looks identical
  /// to success unless you check what actually came back. Found this the
  /// hard way: the resources DELETE policy was missing entirely, so
  /// "Delete guidance"/"Reject" silently did nothing for every admin.
  /// `.select()` after `.delete()` returns the rows that were actually
  /// removed, so an empty result here is a real, detectable failure
  /// rather than a silent no-op.
  Future<void> _deleteResourceRow(String resourceId) async {
    final deleted = await _client
        .from('resources')
        .delete()
        .eq('resource_id', resourceId)
        .select();
    if (deleted.isEmpty) {
      throw Exception('Delete did not remove any row — check permissions');
    }
  }

  // ---- incident reports ----------------------------------------------

  Future<List<Map<String, dynamic>>> fetchReports() async {
    final rows = await _client
        .from('incident_reports')
        .select('*, zones(name), students(full_name, email)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> setReportStatus(String reportId, String status) async {
    await _client
        .from('incident_reports')
        .update({'status': status})
        .eq('report_id', reportId);
    await _logAction(
      action: 'report.status',
      targetType: 'incident_report',
      targetId: reportId,
      details: 'Set incident report status to "$status"',
    );
  }

  // ---- walking groups --------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchGroups() async {
    final rows = await _client
        .from('walking_groups')
        .select('*, students(full_name)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> setGroupStatus(String groupId, String status) async {
    await _client
        .from('walking_groups')
        .update({'status': status})
        .eq('group_id', groupId);
    await _logAction(
      action: 'group.status',
      targetType: 'walking_group',
      targetId: groupId,
      details: 'Set walking group status to "$status"',
    );
  }

  // ---- emergency contacts -----------------------------------------------

  Future<List<Map<String, dynamic>>> fetchEmergencyContacts() async {
    final rows = await _client
        .from('emergency_contacts')
        .select('*')
        .order('service_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> createEmergencyContact({
    required String serviceName,
    required String phoneNumber,
  }) async {
    await _client.from('emergency_contacts').insert({
      'service_name': serviceName,
      'phone_number': phoneNumber,
    });
    await _logAction(
      action: 'contact.create',
      targetType: 'emergency_contact',
      details: 'Added emergency contact "$serviceName"',
    );
  }

  Future<void> updateEmergencyContact(
    String contactId,
    Map<String, dynamic> patch,
  ) async {
    await _client
        .from('emergency_contacts')
        .update(patch)
        .eq('contact_id', contactId);
    await _logAction(
      action: 'contact.update',
      targetType: 'emergency_contact',
      targetId: contactId,
      details: 'Updated emergency contact "${patch['service_name'] ?? contactId}"',
    );
  }

  Future<void> deleteEmergencyContact(String contactId) async {
    await _client
        .from('emergency_contacts')
        .delete()
        .eq('contact_id', contactId);
    await _logAction(
      action: 'contact.delete',
      targetType: 'emergency_contact',
      targetId: contactId,
      details: 'Deleted emergency contact',
    );
  }

  // ---- Safe Ride reports -------------------------------------------
  //
  // Student-submitted vehicle offense reports start as pending_review
  // and only affect what other students see once approved here —
  // feedback: "admin should review the report ... they are not to be
  // posted [straight from the reporter]".

  Future<List<Map<String, dynamic>>> fetchPendingSafeRideReports() async {
    final rows = await _client
        .from('vehicle_offenses')
        .select('*, vehicle_records(plate_number, vehicle_make, vehicle_model)')
        .eq('source', 'student_report')
        .eq('status', 'pending_review')
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> resolveSafeRideReport(
    String offenseId, {
    required bool approve,
    String? severity,
    bool needsIntervention = false,
  }) async {
    await _client
        .from('vehicle_offenses')
        .update({
          'status': approve ? 'approved' : 'rejected',
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          if (approve && severity != null) 'severity': severity,
          if (approve) 'needs_intervention': needsIntervention,
        })
        .eq('offense_id', offenseId);
    await _logAction(
      action: 'safe_ride_report.review',
      targetType: 'vehicle_offense',
      targetId: offenseId,
      details: approve
          ? 'Approved a Safe Ride offense report'
          : 'Rejected a Safe Ride offense report',
    );
  }
}
