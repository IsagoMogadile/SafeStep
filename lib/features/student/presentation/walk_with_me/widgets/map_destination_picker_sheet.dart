import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/location/location_service.dart';
import '../../../../../core/location/route_service.dart';

const _summerstrandCenter = LatLng(-33.9836, 25.6649);

/// A point picked on the map, resolved back to a human-readable address —
/// callers that only need text (e.g. a destination field) can read [label]
/// alone; callers that also need real coordinates (e.g. a start location
/// used to compute a meeting-point midpoint) get both.
class PickedLocation {
  const PickedLocation({required this.label, required this.point});
  final String label;
  final LatLng point;
}

/// Bottom sheet letting a student tap a point on the map to set a Safe
/// Walks location, instead of only typing a free-text address — mirrors
/// the admin zone picker's tap-to-place-a-pin pattern. Resolves the tap
/// back to an address via reverse geocoding so it drops straight into
/// whichever free-text field the caller reads, while also handing back
/// the raw coordinates for callers that need them.
class MapDestinationPickerSheet extends StatefulWidget {
  const MapDestinationPickerSheet({super.key, this.title = 'Choose a destination'});

  final String title;

  @override
  State<MapDestinationPickerSheet> createState() => _MapDestinationPickerSheetState();
}

class _MapDestinationPickerSheetState extends State<MapDestinationPickerSheet> {
  final _mapController = MapController();
  LatLng? _center;
  LatLng? _point;
  String? _label;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialCenter();
  }

  Future<void> _loadInitialCenter() async {
    final position = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _center = position != null
          ? LatLng(position.latitude, position.longitude)
          : _summerstrandCenter;
    });
  }

  Future<void> _selectPoint(LatLng point) async {
    setState(() {
      _point = point;
      _resolving = true;
      _label = null;
    });
    final label = await RouteService.reverseGeocode(point);
    if (!mounted) return;
    setState(() {
      _resolving = false;
      _label = label ??
          '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Tap the map to place a pin',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _center == null
                      ? const Center(child: CircularProgressIndicator())
                      : FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _center!,
                            initialZoom: 15,
                            onTap: (_, point) => _selectPoint(point),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://server.arcgisonline.com/ArcGIS/rest/services/'
                                  'World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                            ),
                            if (_point != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _point!,
                                    width: 36,
                                    height: 36,
                                    child: const Icon(
                                      Icons.location_on,
                                      size: 36,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (_resolving)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else if (_label != null)
                Text(_label!, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: (_point == null || _resolving)
                    ? null
                    : () => Navigator.of(context).pop(
                        PickedLocation(label: _label!, point: _point!),
                      ),
                child: const Text('Use this location'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Opens [MapDestinationPickerSheet] and returns the picked location, or
/// null if the sheet was dismissed without a selection.
Future<PickedLocation?> pickDestinationOnMap(
  BuildContext context, {
  String title = 'Choose a destination',
}) {
  return showModalBottomSheet<PickedLocation>(
    context: context,
    isScrollControlled: true,
    builder: (_) => MapDestinationPickerSheet(title: title),
  );
}
