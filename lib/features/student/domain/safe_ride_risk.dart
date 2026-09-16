import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Safe Ride risk classification — combines both the *magnitude* (how
/// severe) and the *number* of offenses on file for a plate, not just a
/// raw count:
///
/// - Danger (red): any single severe offense, or 3+ moderate offenses.
///   A single severe incident (assault, DUI, attempted robbery) is
///   disqualifying on its own — it shouldn't take repeats to flag.
/// - Moderate (orange): 1-2 moderate offenses, or 3+ minor ones with
///   nothing worse — a pattern worth being cautious about, not yet
///   disqualifying.
/// - Clean (green): nothing on file, or only 1-2 minor offenses.
enum SafeRideRisk { clean, moderate, danger }

SafeRideRisk classifySafeRideRisk(List<Map<String, dynamic>> offenses) {
  final severities = offenses.map((o) => o['severity'] as String).toList();
  final severeCount = severities.where((s) => s == 'severe').length;
  final moderateCount = severities.where((s) => s == 'moderate').length;
  final minorCount = severities.where((s) => s == 'minor').length;

  if (severeCount > 0 || moderateCount >= 3) return SafeRideRisk.danger;
  if (moderateCount >= 1 || minorCount >= 3) return SafeRideRisk.moderate;
  return SafeRideRisk.clean;
}

extension SafeRideRiskDisplay on SafeRideRisk {
  Color get color => switch (this) {
    SafeRideRisk.clean => AppColors.safe,
    SafeRideRisk.moderate => AppColors.caution,
    SafeRideRisk.danger => AppColors.alert,
  };

  IconData get icon => switch (this) {
    SafeRideRisk.clean => Icons.check_circle_outline,
    SafeRideRisk.moderate => Icons.warning_amber_outlined,
    SafeRideRisk.danger => Icons.dangerous_outlined,
  };

  String get title => switch (this) {
    SafeRideRisk.clean => 'Clean record',
    SafeRideRisk.moderate => 'Moderate record — proceed with caution',
    SafeRideRisk.danger => 'Concerning record — not recommended',
  };

  String get feedback => switch (this) {
    SafeRideRisk.clean =>
      'No offenses on file for this driver/vehicle. Always still trust '
          'your own judgement.',
    SafeRideRisk.moderate =>
      'This driver/vehicle has some history on file. Consider sharing '
          'your trip with a trusted contact before getting in.',
    SafeRideRisk.danger =>
      'This driver/vehicle has a serious history on file. We recommend '
          "you don't get in this vehicle — use Call Security or find "
          'another ride instead.',
  };
}

String severityLabel(String severity) => switch (severity) {
  'minor' => 'Minor',
  'moderate' => 'Moderate',
  'severe' => 'Severe',
  _ => severity,
};
