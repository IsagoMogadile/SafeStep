import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../../core/widgets/skeleton_loader.dart';

const _statusColors = {
  'new': Color(0xFF1A56DB),
  'flagged_for_support': Color(0xFFF59E0B),
  'closed': Color(0xFF16A34A),
};

/// scope.md §5: "my reports" lives in the drawer.
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  late Future<List<Map<String, dynamic>>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _fetchReports();
  }

  Future<List<Map<String, dynamic>>> _fetchReports() {
    final userId = SupabaseService.client.auth.currentUser!.id;
    return SupabaseService.client
        .from('incident_reports')
        .select()
        .eq('student_id', userId)
        .order('created_at', ascending: false);
  }

  Future<void> _refresh() async {
    setState(() { _reportsFuture = _fetchReports(); });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _reportsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SkeletonList();
            }
            final reports = snapshot.data!;
            if (reports.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag_outlined, size: 40, color: colorScheme.outline),
                          const SizedBox(height: 12),
                          Text(
                            "You haven't submitted any reports yet",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final report = reports[index];
                final status = report['status'] as String? ?? 'new';
                final color = _statusColors[status] ?? colorScheme.outline;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(Icons.flag_outlined, color: color, size: 18),
                  ),
                  title: Text(report['category'] as String? ?? ''),
                  subtitle: Text(
                    report['description'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Chip(
                    label: Text(status.replaceAll('_', ' ').toUpperCase()),
                    labelStyle: TextStyle(fontSize: 9, color: color),
                    backgroundColor: color.withValues(alpha: 0.12),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
