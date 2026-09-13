import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/supabase/supabase_service.dart';
import 'qr_scan_screen.dart';

const _riskColors = {
  'high': AppColors.alert,
  'moderate': AppColors.caution,
  'safe': AppColors.safe,
};

/// Real center of the four NMU Summerstrand campuses — used as the
/// default map view before any zone data loads.
const _summerstrandCenter = LatLng(-33.9836, 25.6649);

/// One continuous campus + Summerstrand map, zones colour-coded by risk
/// (scope.md §5). Uses OpenStreetMap tiles via flutter_map rather than
/// Google Maps — the project's Google Cloud key(s) can't render map
/// tiles without billing enabled, and OSM needs no API key or billing at
/// all, so it's usable immediately.
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  late final Future<List<Map<String, dynamic>>> _zonesFuture;
  final _mapController = MapController();
  Map<String, dynamic>? _selectedZone;

  @override
  void initState() {
    super.initState();
    _zonesFuture = SupabaseService.client
        .from('zones')
        .select('name, area_type, risk_status, covered_by, lat, lng')
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
          final zones = snapshot.data!
              .where((z) => z['lat'] != null && z['lng'] != null)
              .toList();

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _summerstrandCenter,
                  initialZoom: 14,
                  minZoom: 11,
                  maxZoom: 18,
                  onTap: (_, _) => setState(() => _selectedZone = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: [
                      for (final zone in zones)
                        Marker(
                          point: LatLng(
                            (zone['lat'] as num).toDouble(),
                            (zone['lng'] as num).toDouble(),
                          ),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedZone = zone),
                            child: Icon(
                              Icons.location_on,
                              size: 38,
                              color: _riskColors[zone['risk_status'] as String?] ??
                                  colorScheme.outline,
                              shadows: const [
                                Shadow(color: Colors.black45, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _riskColors.entries.map((entry) {
                      return Row(
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
                      );
                    }).toList(),
                  ),
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
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _riskColors[_selectedZone!['risk_status'] as String?] ??
                                  colorScheme.outline,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedZone!['name'] as String? ?? '',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  _coverageLabel(_selectedZone!['covered_by'] as String?),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _selectedZone = null),
                          ),
                        ],
                      ),
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
