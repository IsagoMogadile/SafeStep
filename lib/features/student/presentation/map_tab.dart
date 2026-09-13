import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/location_service.dart';
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
  LatLng? _myLocation;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _zonesFuture = SupabaseService.client
        .from('zones')
        .select('name, area_type, risk_status, covered_by, lat, lng')
        .order('area_type')
        .order('name');
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLocating = true);
    final position = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() => _isLocating = false);
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't get your location — check location permission is allowed",
          ),
        ),
      );
      return;
    }
    final here = LatLng(position.latitude, position.longitude);
    setState(() => _myLocation = here);
    _mapController.move(here, 16);
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
                    // Two dead ends before this one: raw
                    // tile.openstreetmap.org blocks unregistered app
                    // traffic outright, and CartoDB's basemaps.cartocdn.com
                    // (looked free, worked in a one-off curl test) turned
                    // out to require an account/API key for real in-app
                    // use. Esri's World_Street_Map tile service has stayed
                    // genuinely key-free for community/prototype use for
                    // years — verified as a real image response, not an
                    // error page, before wiring it in here.
                    urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/'
                        'World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                  ),
                  MarkerLayer(
                    markers: [
                      if (_myLocation != null)
                        Marker(
                          point: _myLocation!,
                          width: 26,
                          height: 26,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.seed,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'my_location',
            backgroundColor: colorScheme.surface,
            foregroundColor: AppColors.seed,
            onPressed: _isLocating ? null : _goToCurrentLocation,
            child: _isLocating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.my_location),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'qr_scan',
            backgroundColor: AppColors.alert,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QrScanScreen()),
            ),
            child: const Icon(Icons.qr_code_scanner, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
