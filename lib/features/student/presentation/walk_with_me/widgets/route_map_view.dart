import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/location/route_service.dart';
import '../../../../../core/theme/app_theme.dart';

/// Real route between a start point and a free-text destination — geocoded
/// via OpenStreetMap Nominatim, routed via OSRM, rendered on an OSM map
/// (scope.md §5: Walk With Me "the app plans a route"). Falls back to a
/// straight line if the routing service is unreachable, and to a
/// destination-not-found message if geocoding fails outright.
class RouteMapView extends StatefulWidget {
  const RouteMapView({
    super.key,
    required this.origin,
    this.destinationQuery,
    this.destinationPoint,
    this.destinationIcon = Icons.flag,
  }) : assert(
         (destinationQuery == null) != (destinationPoint == null),
         'Provide exactly one of destinationQuery or destinationPoint',
       );

  final LatLng origin;

  /// Free-text destination to geocode — used for the real journey
  /// destination.
  final String? destinationQuery;

  /// Already-known destination coordinates — used for the computed
  /// meeting point, which has no address to geocode.
  final LatLng? destinationPoint;
  final IconData destinationIcon;

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  late Future<_PlannedRoute?> _routeFuture;

  @override
  void initState() {
    super.initState();
    _routeFuture = _planRoute();
  }

  Future<_PlannedRoute?> _planRoute() async {
    final destination =
        widget.destinationPoint ?? await RouteService.geocode(widget.destinationQuery!);
    if (destination == null) return null;
    final path = await RouteService.fetchWalkingRoute(widget.origin, destination);
    return _PlannedRoute(destination: destination, path: path ?? [widget.origin, destination]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PlannedRoute?>(
      future: _routeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final route = snapshot.data;
        if (route == null) {
          return SizedBox(
            height: 220,
            child: Center(
              child: Text(
                "Couldn't find \"${widget.destinationQuery ?? 'the meeting point'}\" on the map.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          );
        }

        final bounds = LatLngBounds.fromPoints(route.path);
        return SizedBox(
          height: 220,
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
                PolylineLayer(
                  polylines: [
                    Polyline(points: route.path, strokeWidth: 4, color: AppColors.seed),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.origin,
                      width: 34,
                      height: 34,
                      child: const Icon(Icons.trip_origin, color: AppColors.safe, size: 26),
                    ),
                    Marker(
                      point: route.destination,
                      width: 34,
                      height: 34,
                      child: Icon(widget.destinationIcon, color: AppColors.alert, size: 26),
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
