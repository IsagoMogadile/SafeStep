import 'package:flutter/material.dart';

import '../data/admin_repository.dart';
import '../domain/admin_enums.dart';
import 'widgets/admin_async_error.dart';

/// scope.md §7 "Manage zones": create/edit on-campus + Summerstrand
/// zones, risk status, which org(s) cover each.
class ZonesTab extends StatefulWidget {
  const ZonesTab({super.key});

  @override
  State<ZonesTab> createState() => _ZonesTabState();
}

class _ZonesTabState extends State<ZonesTab> {
  final _repository = AdminRepository();
  late Future<List<Map<String, dynamic>>> _zonesFuture;
  late Future<List<Map<String, dynamic>>> _campusesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _zonesFuture = _repository.fetchZones();
      _campusesFuture = _repository.fetchCampuses();
    });
  }

  Future<void> _openZoneForm({Map<String, dynamic>? existing}) async {
    final campuses = await _campusesFuture;
    if (!mounted) return;

    final nameController = TextEditingController(text: existing?['name'] as String?);
    String areaType = existing?['area_type'] as String? ?? 'on_campus';
    String? campusId = existing?['campus_id'] as String?;
    String riskStatus = existing?['risk_status'] as String? ?? 'safe';
    String coveredBy = existing?['covered_by'] as String? ?? 'nmu';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Create zone' : 'Edit zone'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Zone name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: areaType,
                    decoration: const InputDecoration(labelText: 'Area type'),
                    items: [
                      for (final v in areaTypeOptions)
                        DropdownMenuItem(value: v, child: Text(areaTypeLabel(v))),
                    ],
                    onChanged: (v) => setDialogState(() => areaType = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: campusId,
                    decoration: const InputDecoration(
                      labelText: 'Campus (optional — leave blank for off-campus)',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      for (final c in campuses)
                        DropdownMenuItem(
                          value: c['campus_id'] as String,
                          child: Text(c['name'] as String),
                        ),
                    ],
                    onChanged: (v) => setDialogState(() => campusId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: riskStatus,
                    decoration: const InputDecoration(labelText: 'Risk status'),
                    items: [
                      for (final v in riskStatusOptions)
                        DropdownMenuItem(value: v, child: Text(riskLabel(v))),
                    ],
                    onChanged: (v) => setDialogState(() => riskStatus = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: coveredBy,
                    decoration: const InputDecoration(labelText: 'Covered by'),
                    items: [
                      for (final v in coverageOptions)
                        DropdownMenuItem(value: v, child: Text(coverageLabel(v))),
                    ],
                    onChanged: (v) => setDialogState(() => coveredBy = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                if (existing == null) {
                  await _repository.createZone(
                    name: nameController.text.trim(),
                    areaType: areaType,
                    campusId: campusId,
                    riskStatus: riskStatus,
                    coveredBy: coveredBy,
                  );
                } else {
                  await _repository.updateZone(existing['zone_id'] as String, {
                    'name': nameController.text.trim(),
                    'area_type': areaType,
                    'campus_id': campusId,
                    'risk_status': riskStatus,
                    'covered_by': coveredBy,
                  });
                }
                if (context.mounted) Navigator.of(context).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) _refresh();
  }

  Future<void> _confirmDelete(Map<String, dynamic> zone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete zone?'),
        content: Text(
          'Delete "${zone['name']}"? This fails safely if responders, '
          'alerts, or reports still reference it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteZone(zone['zone_id'] as String);
      _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Can't delete — this zone is still referenced by responders, "
              'alerts, or reports.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _zonesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AdminAsyncError(error: snapshot.error!, onRetry: _refresh);
        }
        final zones = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _openZoneForm(),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Create zone'),
              ),
            ),
            const SizedBox(height: 16),
            for (final zone in zones)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: riskColor(
                      zone['risk_status'] as String,
                    ).withValues(alpha: 0.15),
                    child: Icon(
                      Icons.location_on_outlined,
                      color: riskColor(zone['risk_status'] as String),
                    ),
                  ),
                  title: Text(zone['name'] as String),
                  subtitle: Text(
                    '${areaTypeLabel(zone['area_type'] as String)} · '
                    '${(zone['campuses'] as Map?)?['name'] ?? 'Off campus'} · '
                    '${riskLabel(zone['risk_status'] as String)} risk · '
                    'Covered by ${coverageLabel(zone['covered_by'] as String)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openZoneForm(existing: zone),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(zone),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
