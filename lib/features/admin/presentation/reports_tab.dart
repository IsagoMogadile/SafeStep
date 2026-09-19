import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../domain/admin_enums.dart';
import 'widgets/admin_async_error.dart';

/// scope.md §7 "Incident reports": view reports — anonymous ones show
/// content only, never identity; named ones show identity. Identity
/// fields are RLS-readable by admins (same tiered-visibility pattern as
/// medical_info elsewhere in this app), but this widget deliberately
/// never renders the joined student name/email when `is_anonymous` is
/// true — that promise is enforced here, at render time, not by hiding
/// the column from the query.
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  final _repository = AdminRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() { _future = _repository.fetchReports(); });

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
          return const Center(child: Text('No incident reports yet.'));
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            for (final r in reports) _ReportCard(report: r, onChanged: _refresh),
          ],
        );
      },
    );
  }
}

void _openFullScreenPhoto(BuildContext context, String url) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FullScreenPhotoScreen(url: url),
    ),
  );
}

class _FullScreenPhotoScreen extends StatelessWidget {
  const _FullScreenPhotoScreen({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onChanged});

  final Map<String, dynamic> report;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isAnonymous = report['is_anonymous'] as bool? ?? false;
    final status = report['status'] as String;
    final student = report['students'] as Map?;
    final zone = (report['zones'] as Map?)?['name'] as String?;
    final repo = AdminRepository();

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
                    report['category'] as String? ?? 'Report',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: reportStatusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    reportStatusLabel(status),
                    style: TextStyle(
                      color: reportStatusColor(status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isAnonymous
                  ? 'Submitted anonymously'
                  : 'Submitted by ${student?['full_name'] ?? 'Unknown'} (${student?['email'] ?? '—'})',
              style: TextStyle(
                fontStyle: isAnonymous ? FontStyle.italic : FontStyle.normal,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 6),
            Text(report['description'] as String? ?? ''),
            const SizedBox(height: 6),
            Text(
              '${report['location_text'] ?? zone ?? 'Location not provided'}'
              '${(report['follow_up_requested'] as bool? ?? false) ? ' · Follow-up requested' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (report['photo_url'] != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _openFullScreenPhoto(context, report['photo_url'] as String),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    report['photo_url'] as String,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final option in reportStatusOptions)
                  ChoiceChip(
                    label: Text(reportStatusLabel(option)),
                    selected: status == option,
                    onSelected: (selected) async {
                      if (!selected) return;
                      await repo.setReportStatus(report['report_id'] as String, option);
                      onChanged();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
