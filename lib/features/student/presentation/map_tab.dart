import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/supabase/supabase_service.dart';
import 'qr_scan_screen.dart';

const _riskColors = {
  'high': AppColors.alert,
  'moderate': AppColors.caution,
  'safe': AppColors.safe,
};

/// One continuous campus + Summerstrand list, zones colour-coded by risk
/// (scope.md §5). This reads the real `zones` table; a pin-based Google
/// Maps view (using `zones.lat`/`lng`) is a separate follow-up task that
/// needs platform config (API key in AndroidManifest/Info.plist).
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  late final Future<List<Map<String, dynamic>>> _zonesFuture;

  @override
  void initState() {
    super.initState();
    _zonesFuture = SupabaseService.client
        .from('zones')
        .select('name, area_type, risk_status, covered_by')
        .order('area_type')
        .order('name');
  }

  String _coverageLabel(String? coveredBy) {
    return switch (coveredBy) {
      'nmu' => 'NMU Campus Security',
      'security_company' => 'Security Company',
      'both' => 'NMU + Security Company',
      _ => 'Unassigned',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _zonesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final zones = snapshot.data!;
          final onCampus = zones.where((z) => z['area_type'] == 'on_campus').toList();
          final offCampus = zones.where((z) => z['area_type'] == 'off_campus').toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              Row(
                children: _riskColors.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: entry.value,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.key[0].toUpperCase() + entry.key.substring(1),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('On Campus', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...onCampus.map((zone) => _ZoneTile(zone: zone, label: _coverageLabel)),
              const SizedBox(height: 20),
              Text(
                'Off Campus — Summerstrand',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...offCampus.map((zone) => _ZoneTile(zone: zone, label: _coverageLabel)),
              if (zones.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No zones configured yet',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.alert,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QrScanScreen()),
        ),
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
    );
  }
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({required this.zone, required this.label});

  final Map<String, dynamic> zone;
  final String Function(String?) label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _riskColors[zone['risk_status'] as String?] ?? colorScheme.outline;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        title: Text(zone['name'] as String? ?? ''),
        subtitle: Text(label(zone['covered_by'] as String?)),
      ),
    );
  }
}
