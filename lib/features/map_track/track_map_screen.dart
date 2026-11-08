import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_theme.dart';
import 'map_providers.dart';

/// Pantalla de Geolocalización 100% Nativa (`google_maps_flutter`, cero WebViews)
/// - Estilo de mapa personalizado (Oscuro Sagem / Claro Daylight Cup).
/// - Posición GPS en vivo del Clio RS 172 y polilínea del recorrido actual.
/// - Marcadores físicos de "Talleres Especialistas Renault Sport & Pits Oficiales"
///   y gasolineras de alto octanaje (98 RON).
class TrackMapScreen extends ConsumerWidget {
  final bool isCompactPreview;

  const TrackMapScreen({
    super.key,
    this.isCompactPreview = false,
  });

  // Estilo JSON Oscuro "Night Stage Sagem" para Google Maps Nativo
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
      // Marcador en vivo del Renault Clio RS 172
      Marker(
        markerId: const MarkerId('clio_rs_172_live'),
        position: mapState.currentGpsPosition,
        infoWindow: const InfoWindow(
          title: 'RENAULT CLIO II RS 172 PHASE 2 (EN VIVO)',
          snippet: 'ECU Siemens Sirius 34 // Telemetría GPS Activa',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
      // Marcadores de Talleres Especialistas Renault Sport, Pits y Gasolineras 98 Octanos
      ...mapState.officialPoiMarkers.map(
        (poi) => Marker(
          markerId: MarkerId(poi.id),
          position: poi.position,
          infoWindow: InfoWindow(
            title: poi.title,
            snippet: '${poi.category} • ${poi.technicalNotes}',
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
        polylineId: const PolylineId('clio_rs_track_trace'),
        points: mapState.routePolylinePoints,
        color: primary,
        width: 5,
      ),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Mapa 100% Nativo de Google Maps SDK
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: mapState.currentGpsPosition,
              zoom: isCompactPreview ? 14.5 : 15.2,
              tilt: 38.0,
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

          // Cabecera flotante con Cronómetro de Vuelta GPS (Lap Timer)
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xD90F1115),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primary.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.satellite_alt_rounded, size: 16, color: primary),
                      const SizedBox(width: 6),
                      Text(
                        'GPS TRACK & PITS RENAULT SPORT',
                        style: AppTheme.renaultSportHeaderStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'LAP ${mapState.lapCount} • ${mapState.currentLapTimeSec.toStringAsFixed(1)}s (BEST ${mapState.bestLapTimeSec}s)',
                    style: AppTheme.telemetryNumericStyle(
                      fontSize: 11,
                      color: RenaultSportPalette.oemShiftGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Panel inferior de Talleres Especialistas Renault Sport & Gasolineras 98 RON
          if (!isCompactPreview && mapState.selectedPoi != null)
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xEB141820),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: RenaultSportPalette.siriusLiquidYellow),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.build_circle_rounded,
                          color: RenaultSportPalette.siriusLiquidYellow,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            mapState.selectedPoi!.title,
                            style: AppTheme.renaultSportHeaderStyle(
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            mapState.selectedPoi!.category,
                            style: AppTheme.telemetryNumericStyle(
                              fontSize: 10,
                              color: primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mapState.selectedPoi!.technicalNotes,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: mapState.officialPoiMarkers.map((poi) {
                          final isSelected = poi.id == mapState.selectedPoi?.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(poi.title, style: const TextStyle(fontSize: 11)),
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

