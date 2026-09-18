import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/location/route_service.dart';

const _summerstrandCenter = LatLng(-33.9836, 25.6649);

/// Lets an admin set a zone's coordinates by tapping directly on a map,
/// or by searching an address (Nominatim, the same free geocoder Safe
/// Walks already uses) rather than typing raw latitude/longitude.
class LocationPickerMap extends StatefulWidget {
  const LocationPickerMap({super.key, this.initial, required this.onChanged});

  final LatLng? initial;
  final ValueChanged<LatLng> onChanged;

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  LatLng? _point;
  bool _searching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setPoint(LatLng point) {
    setState(() => _point = point);
    widget.onChanged(point);
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    final result = await RouteService.geocode(query);
    if (!mounted) return;
    setState(() => _searching = false);
    if (result == null) {
      setState(() => _searchError = "Couldn't find that address");
      return;
    }
    _mapController.move(result, 16);
    _setPoint(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search an address',
                  errorText: _searchError,
                  isDense: true,
                ),
                onSubmitted: (_) => _searchAddress(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _searching ? null : _searchAddress,
              icon: _searching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Or tap the map to place the pin directly',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _point ?? _summerstrandCenter,
                initialZoom: _point != null ? 16 : 13,
                onTap: (_, point) => _setPoint(point),
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
        if (_point != null) ...[
          const SizedBox(height: 6),
          Text(
            '${_point!.latitude.toStringAsFixed(5)}, '
            '${_point!.longitude.toStringAsFixed(5)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
