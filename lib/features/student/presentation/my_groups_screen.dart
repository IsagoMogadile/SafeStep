import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../../core/widgets/skeleton_loader.dart';
import 'group_detail_screen.dart';

const _statusColors = {
  'approved': Color(0xFF16A34A),
  'pending': Color(0xFFF59E0B),
  'rejected': Color(0xFFDC2626),
};

/// Groups the student has joined, plus any they created that are still
/// awaiting admin approval — unlike Browse Groups, status isn't filtered
/// here since these are the student's own.
class MyGroupsScreen extends StatefulWidget {
  const MyGroupsScreen({super.key});

  @override
  State<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<MyGroupsScreen> {
  late Future<List<Map<String, dynamic>>> _groupsFuture;

  String get _userId => SupabaseService.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _fetchGroups();
  }

  Future<List<Map<String, dynamic>>> _fetchGroups() async {
    final joined = await SupabaseService.client
        .from('group_members')
        .select('walking_groups(*)')
        .eq('student_id', _userId);
    final created = await SupabaseService.client
        .from('walking_groups')
        .select()
        .eq('created_by', _userId);

    final byId = <String, Map<String, dynamic>>{};
    for (final row in joined) {
      final group = row['walking_groups'] as Map<String, dynamic>?;
      if (group != null) byId[group['group_id'] as String] = group;
    }
    for (final group in created) {
      byId[group['group_id'] as String] = group;
    }
    final groups = byId.values.toList()
      ..sort(
        (a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String),
      );
    return groups;
  }

  Future<void> _refresh() async {
    setState(() { _groupsFuture = _fetchGroups(); });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Groups')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _groupsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SkeletonList();
            }
            final groups = snapshot.data!;
            if (groups.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.groups_outlined, size: 40, color: colorScheme.outline),
                          const SizedBox(height: 12),
                          Text(
                            "You haven't joined or created any groups yet",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Browse approved groups to join, or create your own.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
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
                final status = group['status'] as String? ?? 'pending';
                final color = _statusColors[status] ?? colorScheme.outline;
                final isCreator = group['created_by'] == _userId;

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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  group['name'] as String? ?? '',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              if (isCreator)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Chip(
                                    label: const Text('Creator'),
                                    labelStyle: const TextStyle(fontSize: 9),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                              Chip(
                                label: Text(status.toUpperCase()),
                                labelStyle: TextStyle(fontSize: 10, color: color),
                                backgroundColor: color.withValues(alpha: 0.12),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
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
