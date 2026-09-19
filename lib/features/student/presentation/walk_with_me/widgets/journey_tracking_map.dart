import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/location/route_service.dart';
import '../../../../../core/theme/app_theme.dart';

/// Live version of RouteMapView for a monitor watching a "Monitor My
/// Journey" session: the destination and planned route are resolved
/// once, but the walker marker is driven by [currentPosition], which the
/// caller refreshes on every poll (MonitorTrackingScreen) — so this
/// widget just needs to rebuild, not re-fetch anything, as new positions
/// arrive.
class JourneyTrackingMap extends StatefulWidget {
  const JourneyTrackingMap({
    super.key,
    required this.currentPosition,
    required this.destinationQuery,
  });

  final LatLng currentPosition;
  final String destinationQuery;

  @override
  State<JourneyTrackingMap> createState() => _JourneyTrackingMapState();
}

class _JourneyTrackingMapState extends State<JourneyTrackingMap> {
  late Future<_PlannedRoute?> _routeFuture;

  @override
  void initState() {
    super.initState();
    _routeFuture = _planRoute();
  }

  Future<_PlannedRoute?> _planRoute() async {
    final destination = await RouteService.geocode(widget.destinationQuery);
    if (destination == null) return null;
    final path = await RouteService.fetchWalkingRoute(widget.currentPosition, destination);
    return _PlannedRoute(
      destination: destination,
      path: path ?? [widget.currentPosition, destination],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PlannedRoute?>(
      future: _routeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 280,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final route = snapshot.data;
        final destination = route?.destination;
        final bounds = LatLngBounds.fromPoints([
          widget.currentPosition,
          ?destination,
        ]);

        return SizedBox(
          height: 280,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(36),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/'
                      'World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                ),
                if (route != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(points: route.path, strokeWidth: 4, color: AppColors.seed),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.currentPosition,
                      width: 36,
                      height: 36,
                      child: const Icon(
                        Icons.directions_walk,
                        color: AppColors.safe,
                        size: 30,
                      ),
                    ),
                    if (destination != null)
                      Marker(
                        point: destination,
                        width: 34,
                        height: 34,
                        child: const Icon(Icons.flag, color: AppColors.alert, size: 26),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlannedRoute {
  const _PlannedRoute({required this.destination, required this.path});
  final LatLng destination;
  final List<LatLng> path;
}
