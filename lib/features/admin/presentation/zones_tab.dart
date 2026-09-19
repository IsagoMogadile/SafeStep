import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../data/admin_repository.dart';
import '../domain/admin_enums.dart';
import 'widgets/admin_async_error.dart';
import 'widgets/location_picker_map.dart';

const _summerstrandCenter = LatLng(-33.9836, 25.6649);

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
  Map<String, dynamic>? _selectedZone;

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
    LatLng? point;
    final existingLat = existing?['lat'] as num?;
    final existingLng = existing?['lng'] as num?;
    if (existingLat != null && existingLng != null) {
      point = LatLng(existingLat.toDouble(), existingLng.toDouble());
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Create zone' : 'Edit zone'),
          content: SizedBox(
            width: 480,
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
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Zone location',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LocationPickerMap(
                    initial: point,
                    onChanged: (p) => point = p,
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
                    lat: point?.latitude,
                    lng: point?.longitude,
                  );
                } else {
                  await _repository.updateZone(existing['zone_id'] as String, {
                    'name': nameController.text.trim(),
                    'area_type': areaType,
                    'campus_id': campusId,
                    'risk_status': riskStatus,
                    'covered_by': coveredBy,
                    'lat': point?.latitude,
                    'lng': point?.longitude,
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
        // Map-only, and deliberately just danger zones: showing every
        // zone as its own pin got too cluttered to actually interact
        // with — feedback: "too many pins ... just red circles for
        // danger zones, completely remove the zone names, just the map."
        final dangerZones = zones
            .where((z) =>
                z['lat'] != null &&
                z['lng'] != null &&
                z['risk_status'] == 'high')
            .toList();

        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: _summerstrandCenter,
                initialZoom: 13,
                onTap: (_, _) => setState(() => _selectedZone = null),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/'
                      'World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                ),
                CircleLayer(
                  circles: [
                    for (final zone in dangerZones)
                      CircleMarker(
                        point: LatLng(
                          (zone['lat'] as num).toDouble(),
                          (zone['lng'] as num).toDouble(),
                        ),
                        radius: 120,
                        useRadiusInMeter: true,
                        color: AppColors.alert.withValues(alpha: 0.22),
                        borderStrokeWidth: 2,
                        borderColor: AppColors.alert,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final zone in dangerZones)
                      Marker(
                        point: LatLng(
                          (zone['lat'] as num).toDouble(),
                          (zone['lng'] as num).toDouble(),
                        ),
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedZone = zone),
                          child: const Icon(
                            Icons.warning_rounded,
                            size: 28,
                            color: AppColors.alert,
                            shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 16,
              right: 16,
              child: FilledButton.icon(
                onPressed: () => _openZoneForm(),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Create zone'),
              ),
            ),
            if (_selectedZone != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_rounded, color: AppColors.alert),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Covered by ${coverageLabel(_selectedZone!['covered_by'] as String)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit',
                          onPressed: () => _openZoneForm(existing: _selectedZone),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete',
                          onPressed: () => _confirmDelete(_selectedZone!),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
