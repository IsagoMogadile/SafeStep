import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Display labels/colors for the Postgres enums the admin dashboard reads
/// and writes (scope.md §9): org_type, risk_status, coverage_type,
/// broadcast_level, group_status, report_status, resource_status,
/// resource_type, area_type, responder_status.
String orgLabel(String value) =>
    value == 'nmu_campus_security' ? 'NMU Campus Security' : 'Security Company';

const riskStatusOptions = ['safe', 'moderate', 'high'];
String riskLabel(String value) => switch (value) {
  'safe' => 'Safe',
  'moderate' => 'Moderate',
  'high' => 'High',
  _ => value,
};
Color riskColor(String value) => switch (value) {
  'safe' => AppColors.safe,
  'moderate' => AppColors.caution,
  'high' => AppColors.alert,
  _ => Colors.grey,
};

const coverageOptions = ['nmu', 'security_company', 'both'];
String coverageLabel(String value) => switch (value) {
  'nmu' => 'NMU Campus Security',
  'security_company' => 'Security Company',
  'both' => 'Both',
  _ => value,
};

const areaTypeOptions = ['on_campus', 'off_campus'];
String areaTypeLabel(String value) =>
    value == 'on_campus' ? 'On campus' : 'Off campus (Summerstrand)';

const broadcastLevelOptions = ['info', 'caution', 'urgent'];
String broadcastLevelLabel(String value) => switch (value) {
  'info' => 'Info',
  'caution' => 'Caution',
  'urgent' => 'Urgent',
  _ => value,
};
Color broadcastLevelColor(String value) => switch (value) {
  'info' => AppColors.seed,
  'caution' => AppColors.caution,
  'urgent' => AppColors.alert,
  _ => Colors.grey,
};

String groupStatusLabel(String value) => switch (value) {
  'pending' => 'Pending approval',
  'approved' => 'Approved',
  'rejected' => 'Rejected',
  _ => value,
};
Color groupStatusColor(String value) => switch (value) {
  'pending' => AppColors.caution,
  'approved' => AppColors.safe,
  'rejected' => AppColors.alert,
  _ => Colors.grey,
};

const reportStatusOptions = ['new', 'flagged_for_support', 'closed'];
String reportStatusLabel(String value) => switch (value) {
  'new' => 'New',
  'flagged_for_support' => 'Flagged for support',
  'closed' => 'Closed',
  _ => value,
};
Color reportStatusColor(String value) => switch (value) {
  'new' => AppColors.caution,
  'flagged_for_support' => AppColors.alert,
  'closed' => AppColors.safe,
  _ => Colors.grey,
};

String resourceStatusLabel(String value) =>
    value == 'published' ? 'Published' : 'Pending verification';
Color resourceStatusColor(String value) =>
    value == 'published' ? AppColors.safe : AppColors.caution;

const resourceTypeOptions = ['guidance', 'community_tip'];
String resourceTypeLabel(String value) =>
    value == 'guidance' ? 'Admin guidance' : 'Community tip';

String alertStatusLabel(String value) => switch (value) {
  'new' => 'New',
  'acknowledged' => 'Acknowledged',
  'dispatched' => 'Dispatched',
  'resolved' => 'Resolved',
  'false_alarm_verify' => 'Possible false alarm',
  _ => value,
};
Color alertStatusColor(String value) => switch (value) {
  'new' => AppColors.alert,
  'acknowledged' => AppColors.caution,
  'dispatched' => AppColors.caution,
  'resolved' => AppColors.safe,
  'false_alarm_verify' => Colors.grey,
  _ => Colors.grey,
};

const openAlertStatuses = ['new', 'acknowledged', 'dispatched'];
