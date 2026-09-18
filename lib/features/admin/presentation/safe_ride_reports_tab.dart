import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/admin_repository.dart';
import 'widgets/admin_async_error.dart';

/// Student-submitted Safe Ride vehicle offense reports, pending admin
/// review — approving or rejecting here is what makes a report actually
/// affect (or not) what other students see on that plate (feedback:
/// "admin should review the report ... they are not to be posted").
class SafeRideReportsTab extends StatefulWidget {
  const SafeRideReportsTab({super.key});

  @override
  State<SafeRideReportsTab> createState() => _SafeRideReportsTabState();
}

class _SafeRideReportsTabState extends State<SafeRideReportsTab> {
  final _repository = AdminRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() { _future = _repository.fetchPendingSafeRideReports(); });

  Future<void> _resolve(String offenseId, {required bool approve}) async {
    await _repository.resolveSafeRideReport(offenseId, approve: approve);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AdminAsyncError(error: snapshot.error!, onRetry: _refresh);
        }
        final reports = snapshot.data ?? [];
        if (reports.isEmpty) {
          return const Center(child: Text('No Safe Ride reports awaiting review.'));
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            for (final r in reports)
              _SafeRideReportCard(
                report: r,
                onApprove: () => _resolve(r['offense_id'] as String, approve: true),
                onReject: () => _resolve(r['offense_id'] as String, approve: false),
              ),
          ],
        );
      },
    );
  }
}

class _SafeRideReportCard extends StatelessWidget {
  const _SafeRideReportCard({
    required this.report,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> report;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final vehicle = report['vehicle_records'] as Map?;
    final plate = vehicle?['plate_number'] as String? ?? 'Unknown plate';
    final car = [vehicle?['vehicle_make'], vehicle?['vehicle_model']]
        .where((v) => v != null)
        .join(' ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$plate${car.isNotEmpty ? ' · $car' : ''}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.caution.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PENDING REVIEW',
                    style: TextStyle(
                      color: AppColors.caution,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(report['offense_type'] as String? ?? ''),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.alert),
                    onPressed: onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
