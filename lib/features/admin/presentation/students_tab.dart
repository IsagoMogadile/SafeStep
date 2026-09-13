import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import 'widgets/admin_async_error.dart';

/// Browsable student directory. Deliberately limited to name, email,
/// campus, and join date — scope.md §5 marks DOB/gender/faculty/year as
/// admin-*aggregate*-only (never a browsable individual profile field)
/// and address/vehicle/mobility/medical info as restricted to a
/// responder during that student's own active alert, never
/// admin-browsable at all. This view doesn't query those columns.
class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final _repository = AdminRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() { _future = _repository.fetchStudents(); });

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
        final students = snapshot.data ?? [];
        final filtered = _search.isEmpty
            ? students
            : students.where((s) {
                final name = (s['full_name'] as String? ?? '').toLowerCase();
                final email = (s['email'] as String? ?? '').toLowerCase();
                final q = _search.toLowerCase();
                return name.contains(q) || email.contains(q);
              }).toList();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by name or email',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 16),
                Text('${filtered.length} students'),
              ],
            ),
            const SizedBox(height: 16),
            for (final s in filtered)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(s['full_name'] as String? ?? 'Unknown'),
                  subtitle: Text(
                    '${s['email']} · ${(s['campuses'] as Map?)?['name'] ?? 'No campus set'}',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
