import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import 'group_detail_screen.dart';

/// Only approved groups — students never see pending-approval groups
/// while browsing (feedback: "as a student I cannot see pending approval
/// groups").
class BrowseGroupsScreen extends StatefulWidget {
  const BrowseGroupsScreen({super.key});

  @override
  State<BrowseGroupsScreen> createState() => _BrowseGroupsScreenState();
}

class _BrowseGroupsScreenState extends State<BrowseGroupsScreen> {
  late Future<List<Map<String, dynamic>>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _fetchGroups();
  }

  Future<List<Map<String, dynamic>>> _fetchGroups() {
    return SupabaseService.client
        .from('walking_groups')
        .select()
        .eq('status', 'approved')
        .order('created_at', ascending: false);
  }

  Future<void> _refresh() async {
    setState(() { _groupsFuture = _fetchGroups(); });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Browse Groups')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _groupsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final groups = snapshot.data!;
            if (groups.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Text(
                        'No approved groups yet',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  color: colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GroupDetailScreen(
                            groupId: group['group_id'] as String,
                          ),
                        ),
                      );
                      _refresh();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group['name'] as String? ?? '',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${group['route'] ?? ''} · ${group['meeting_time'] ?? ''}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
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
