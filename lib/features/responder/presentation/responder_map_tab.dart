import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../data/responder_repository.dart';

const _summerstrandCenter = LatLng(-33.9836, 25.6649);

/// Shows a responder's assigned coverage zone (so they know where to
/// patrol) and every currently open alert they've been notified about,
/// with its real location — scope.md §6 alert detail already showed a
/// single alert's map; this is the "where should I be right now" view
/// across all of them at once.
class ResponderMapTab extends StatefulWidget {
  const ResponderMapTab({
    super.key,
    required this.responderId,
    this.zoneName,
    this.zoneLat,
    this.zoneLng,
  });

  final String responderId;
  final String? zoneName;
  final double? zoneLat;
  final double? zoneLng;

  @override
  State<ResponderMapTab> createState() => _ResponderMapTabState();
}

class _ResponderMapTabState extends State<ResponderMapTab> {
  final _repository = ResponderRepository();
  late Future<List<Map<String, dynamic>>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _alertsFuture = _repository.fetchOpenAlerts(widget.responderId);
  }

  void _refresh() {
    setState(() => _alertsFuture = _repository.fetchOpenAlerts(widget.responderId));
  }

  @override
  Widget build(BuildContext context) {
    final zonePoint = (widget.zoneLat != null && widget.zoneLng != null)
        ? LatLng(widget.zoneLat!, widget.zoneLng!)
        : null;

    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _alertsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final alertPoints = snapshot.data!
              .map((row) => row['alerts'] as Map<String, dynamic>)
              .where((a) => a['lat'] != null && a['lng'] != null)
              .toList();

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: zonePoint ?? _summerstrandCenter,
                  initialZoom: zonePoint != null ? 15 : 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/'
                        'World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                  ),
                  if (zonePoint != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: zonePoint,
                          radius: 250,
                          useRadiusInMeter: true,
                          color: AppColors.seed.withValues(alpha: 0.15),
                          borderStrokeWidth: 2,
                          borderColor: AppColors.seed,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (zonePoint != null)
                        Marker(
                          point: zonePoint,
                          width: 30,
                          height: 30,
                          child: const Icon(
                            Icons.shield_outlined,
                            color: AppColors.seed,
                            size: 28,
                          ),
                        ),
                      for (final alert in alertPoints)
                        Marker(
                          point: LatLng(
                            (alert['lat'] as num).toDouble(),
                            (alert['lng'] as num).toDouble(),
                          ),
                          width: 42,
                          height: 42,
                          child: const Icon(
                            Icons.campaign,
                            color: AppColors.alert,
                            size: 38,
                            shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
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
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 16, color: AppColors.seed),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.zoneName != null
                              ? 'Your zone: ${widget.zoneName}'
                              : 'No coverage zone assigned',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const Icon(Icons.campaign, size: 16, color: AppColors.alert),
                      const SizedBox(width: 6),
                      Text(
                        '${alertPoints.length} active',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refresh,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
