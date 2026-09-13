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

  Future<void> dispatchAlert(String alertId) {
    return _client.from('alerts').update({'status': 'dispatched'}).eq('alert_id', alertId);
  }

  Future<void> resolveAlert(String alertId, {String? notes}) {
    return _client
        .from('alerts')
        .update({
          'status': 'resolved',
          if (notes != null && notes.isNotEmpty) 'responder_notes': notes,
          'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('alert_id', alertId);
  }

  Future<void> flagAlertFalseAlarm(String alertId) {
    return _client
        .from('alerts')
        .update({'status': 'false_alarm_verify'})
        .eq('alert_id', alertId);
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
  }) {
    return _client.from('zones').insert({
      'name': name,
      'area_type': areaType,
      'campus_id': campusId,
      'risk_status': riskStatus,
      'covered_by': coveredBy,
      'lat': lat,
      'lng': lng,
    });
  }

  Future<void> updateZone(String zoneId, Map<String, dynamic> patch) {
    return _client.from('zones').update(patch).eq('zone_id', zoneId);
  }

  Future<void> deleteZone(String zoneId) {
    return _client.from('zones').delete().eq('zone_id', zoneId);
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
  }) {
    return _client.from('responders').insert({
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'organization': organization,
      'coverage_zone_id': coverageZoneId,
      'activation_status': 'invited',
      'status': 'active',
    });
  }

  Future<void> inviteAdmin({required String email, required String fullName}) {
    return _client.from('admins').insert({
      'email': email,
      'full_name': fullName,
      'activation_status': 'invited',
      'is_active': true,
    });
  }

  Future<void> setResponderDutyStatus(String responderId, String status) {
    return _client
        .from('responders')
        .update({'status': status})
        .eq('responder_id', responderId);
  }

  Future<void> setAdminActive(String adminId, bool isActive) {
    return _client
        .from('admins')
        .update({'is_active': isActive})
        .eq('admin_id', adminId);
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
  }) {
    final now = DateTime.now();
    final isImmediate = scheduledAt == null || !scheduledAt.isAfter(now);
    return _client.from('safety_broadcasts').insert({
      'title': title,
      'message': message,
      'level': level,
      'target_campus_id': targetCampusId,
      'created_by': adminId,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'sent_at': isImmediate ? now.toIso8601String() : null,
    });
  }

  Future<void> retractBroadcast(String broadcastId) {
    return _client
        .from('safety_broadcasts')
        .update({'retracted_at': DateTime.now().toIso8601String()})
        .eq('broadcast_id', broadcastId);
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
  }) {
    return _client.from('resources').insert({
      'title': title,
      'content': content,
      'category': category,
      'type': type,
      'status': 'published',
    });
  }

  Future<void> updateResource(String resourceId, Map<String, dynamic> patch) {
    return _client
        .from('resources')
        .update(patch)
        .eq('resource_id', resourceId);
  }

  Future<void> approveResource(String resourceId) {
    return updateResource(resourceId, {'status': 'published'});
  }

  Future<void> rejectResource(String resourceId) {
    return _client.from('resources').delete().eq('resource_id', resourceId);
  }

  // ---- incident reports ----------------------------------------------

  Future<List<Map<String, dynamic>>> fetchReports() async {
    final rows = await _client
        .from('incident_reports')
        .select('*, zones(name), students(full_name, email)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> setReportStatus(String reportId, String status) {
    return _client
        .from('incident_reports')
        .update({'status': status})
        .eq('report_id', reportId);
  }

  // ---- walking groups --------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchGroups() async {
    final rows = await _client
        .from('walking_groups')
        .select('*, students(full_name)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> setGroupStatus(String groupId, String status) {
    return _client
        .from('walking_groups')
        .update({'status': status})
        .eq('group_id', groupId);
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
  }) {
    return _client.from('emergency_contacts').insert({
      'service_name': serviceName,
      'phone_number': phoneNumber,
    });
  }

  Future<void> updateEmergencyContact(
    String contactId,
    Map<String, dynamic> patch,
  ) {
    return _client
        .from('emergency_contacts')
        .update(patch)
        .eq('contact_id', contactId);
  }

  Future<void> deleteEmergencyContact(String contactId) {
    return _client
        .from('emergency_contacts')
        .delete()
        .eq('contact_id', contactId);
  }
}
