import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_theme.dart';
import 'map_providers.dart';

/// Apartado **TRACK**:
/// Mapa nativo Google Maps (`google_maps_flutter`) con telemetría GPS y talleres RS.
class TrackMapScreen extends ConsumerWidget {
  final bool isCompactPreview;

  const TrackMapScreen({
    super.key,
    this.isCompactPreview = false,
  });

  static const String _darkMapStyleJson = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#141820"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#9ca5b3"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#141820"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#28303d"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#ff6b00"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0b0e14"}]}
]
''';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(trackMapTelemetryProvider);
    final mapNotifier = ref.read(trackMapTelemetryProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('clio_rs_live'),
        position: mapState.currentGpsPosition,
        infoWindow: const InfoWindow(
          title: 'CLIO RS 172 (GPS)',
          snippet: 'Posición actual',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
      ...mapState.officialPoiMarkers.map(
        (poi) => Marker(
          markerId: MarkerId(poi.id),
          position: poi.position,
          infoWindow: InfoWindow(
            title: poi.title,
            snippet: poi.category,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            poi.category.contains('Gasolinera')
                ? BitmapDescriptor.hueYellow
                : BitmapDescriptor.hueAzure,
          ),
          onTap: () => mapNotifier.selectPoi(poi),
        ),
      ),
    };

    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('rs_track_trace'),
        points: mapState.routePolylinePoints,
        color: primary,
        width: 5,
      ),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: mapState.currentGpsPosition,
              zoom: isCompactPreview ? 14.3 : 15.2,
              tilt: 35.0,
            ),
            style: isDark ? _darkMapStyleJson : null,
            markers: markers,
            polylines: polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: !isCompactPreview,
            compassEnabled: true,
            mapToolbarEnabled: false,
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xD90F1115),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primary.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.satellite_alt_rounded,
                          size: 15,
                          color: primary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'GPS TRACK',
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.renaultSportHeaderStyle(
                              fontSize: 11.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'LAP ${mapState.lapCount} • ${mapState.currentLapTimeSec.toStringAsFixed(1)}s',
                    style: AppTheme.telemetryNumericStyle(
                      fontSize: 11,
                      color: RenaultSportPalette.oemShiftGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isCompactPreview && mapState.selectedPoi != null)
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xEB141820),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: RenaultSportPalette.siriusLiquidYellow),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: RenaultSportPalette.siriusLiquidYellow,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            mapState.selectedPoi!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.renaultSportHeaderStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mapState.selectedPoi!.technicalNotes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: mapState.officialPoiMarkers.map((poi) {
                          final isSelected = poi.id == mapState.selectedPoi?.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                poi.category,
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: isSelected,
                              onSelected: (_) => mapNotifier.selectPoi(poi),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
