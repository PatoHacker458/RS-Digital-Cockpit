import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../cockpit_dashboard/widgets/launcher_dock_widget.dart';
import '../digital_garage_payments/providers/payment_garage_providers.dart';
import 'map_providers.dart';

/// Vista **TRACK** (Mapa 2/3 con filtros simples + ruta azul calculada + Tarjeta Laps GPS 1/3)
/// y **Mini Google Maps** estilo videojuego en **COCKPIT** (`isMiniLiveMap: true`).
class TrackMapScreen extends ConsumerWidget {
  final bool isMiniLiveMap;

  const TrackMapScreen({
    super.key,
    this.isMiniLiveMap = false,
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

  static String _formatClock(double seconds) {
    final totalTenths = (seconds * 10).round();
    final mins = totalTenths ~/ 600;
    final secs = (totalTenths % 600) ~/ 10;
    final tenths = totalTenths % 10;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.$tenths';
  }

  static String _formatRouteSummary(TrackMapTelemetryState mapState) {
    final distMeters = mapState.navigationDistanceMeters;
    if (distMeters == null) return '';
    final distStr = distMeters < 1000
        ? '${distMeters.round()} m'
        : '${(distMeters / 1000.0).toStringAsFixed(1)} km';
    if (mapState.isDirectFallbackRoute || mapState.navigationDurationSec == null) {
      return '$distStr (línea directa)';
    }
    final mins = (mapState.navigationDurationSec! / 60.0).round().clamp(1, 999);
    return 'Ruta: $distStr • ~$mins min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(trackMapTelemetryProvider);
    final mapNotifier = ref.read(trackMapTelemetryProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    // =========================================================================
    // MODO 1: MINI GOOGLE MAPS EN COCKPIT (ESTILO VIDEOJUEGO CENTRADO)
    // =========================================================================
    if (isMiniLiveMap) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: mapState.currentGpsPosition,
                zoom: 17.2,
                bearing: mapState.currentHeading,
                tilt: 35.0,
              ),
              style: isDark ? _darkMapStyleJson : null,
              onMapCreated: mapNotifier.attachMiniMapController,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              scrollGesturesEnabled: false,
              zoomGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              buildingsEnabled: true,
            ),

            // Bolita azul fija en el centro exacto de la tarjeta; el mapa gira y se mueve debajo
            IgnorePointer(
              child: Center(
                child: _CenteredVehicleBeacon(
                  hasFix: mapState.hasRealGpsFix,
                  isMoving: mapState.currentSpeedMps >= 1.2,
                ),
              ),
            ),

            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xDC0F1115),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: primary.withValues(alpha: 0.55)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            size: 14,
                            color: primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              mapState.currentStreetName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: const Color(0xDC0F1115),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => ref
                          .read(cockpitTabProvider.notifier)
                          .selectTab(CockpitSectionTab.trackMapGps),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.open_in_full_rounded,
                          size: 14,
                          color: primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // =========================================================================
    // MODO 2: APARTADO TRACK (MAPA 2/3 CON FILTROS Y RUTA AZUL + LAPS 1/3)
    // =========================================================================
    final markers = <Marker>{
      if (mapState.startFinishPoint != null)
        Marker(
          markerId: const MarkerId('start_finish_flag'),
          position: mapState.startFinishPoint!,
          infoWindow: InfoWindow(
            title: 'PUNTO DE PARTIDA / META',
            snippet: mapState.startStreetName,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      ...mapState.nearbyPlaces.map(
        (place) {
          final isSelected = mapState.selectedPlace?.id == place.id;
          return Marker(
            markerId: MarkerId(place.id),
            position: place.position,
            infoWindow: InfoWindow(
              title: place.name,
              snippet: place.subtitle,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isSelected
                  ? BitmapDescriptor.hueBlue
                  : switch (place.filter) {
                      TrackMapFilter.workshops => BitmapDescriptor.hueOrange,
                      TrackMapFilter.gasStations => BitmapDescriptor.hueYellow,
                      TrackMapFilter.parking => BitmapDescriptor.hueAzure,
                    },
            ),
            onTap: () => mapNotifier.selectNearbyPlace(place),
          );
        },
      ),
    };

    final circles = <Circle>{
      if (mapState.startFinishPoint != null)
        Circle(
          circleId: const CircleId('start_finish_zone'),
          center: mapState.startFinishPoint!,
          radius: 25.0,
          fillColor: RenaultSportPalette.oemShiftGreen.withValues(alpha: 0.22),
          strokeColor: RenaultSportPalette.oemShiftGreen,
          strokeWidth: 2,
        ),
    };

    final polylines = <Polyline>{
      if (mapState.routePolylinePoints.length >= 2)
        Polyline(
          polylineId: const PolylineId('rs_real_lap_trace'),
          points: mapState.routePolylinePoints,
          color: primary,
          width: 5,
        ),
      if (mapState.navigationRoutePoints.length >= 2)
        Polyline(
          polylineId: const PolylineId('rs_poi_navigation_route'),
          points: mapState.navigationRoutePoints,
          color: const Color(0xFF1D8BFF),
          width: 6,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          patterns: mapState.isDirectFallbackRoute
              ? <PatternItem>[PatternItem.dash(18), PatternItem.gap(10)]
              : const <PatternItem>[],
        ),
    };

    final mapCard = Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: mapState.currentGpsPosition,
              zoom: 15.6,
            ),
            style: isDark ? _darkMapStyleJson : null,
            onMapCreated: mapNotifier.attachFullTrackMapController,
            markers: markers,
            circles: circles,
            polylines: polylines,
            myLocationEnabled: mapState.hasRealGpsFix,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: false,
          ),

          // Barra superior de Filtros Simples (Talleres, Gasolineras, Estacionamientos)
          Positioned(
            top: 10,
            left: 10,
            right: 54,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...TrackMapFilter.values.map((filter) {
                    final selected = mapState.activeFilter == filter;
                    final icon = switch (filter) {
                      TrackMapFilter.workshops => Icons.build_rounded,
                      TrackMapFilter.gasStations =>
                        Icons.local_gas_station_rounded,
                      TrackMapFilter.parking => Icons.local_parking_rounded,
                    };
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(
                          icon,
                          size: 16,
                          color: selected ? Colors.black : primary,
                        ),
                        label: Text(
                          filter.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.black : Colors.white,
                          ),
                        ),
                        selected: selected,
                        backgroundColor: const Color(0xE6141820),
                        selectedColor: primary,
                        checkmarkColor: Colors.black,
                        side: BorderSide(
                          color: selected
                              ? primary
                              : Colors.white.withValues(alpha: 0.25),
                        ),
                        onSelected: (_) => mapNotifier.toggleMapFilter(filter),
                      ),
                    );
                  }),
                  if (mapState.isLoadingPlaces)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xE6141820),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (mapState.activeFilter != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE6141820),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: RenaultSportPalette.oemShiftGreen
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        '${mapState.nearbyPlaces.length} encontrados',
                        style: AppTheme.telemetryNumericStyle(
                          fontSize: 10.5,
                          color: RenaultSportPalette.oemShiftGreen,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Botón Centrar GPS
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: const Color(0xE6141820),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: mapNotifier.centerCameraOnCurrentLocation,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(
                    Icons.my_location_rounded,
                    size: 20,
                    color: primary,
                  ),
                ),
              ),
            ),
          ),

          // Tarjeta inferior al tocar un lugar filtrado: muestra distancia, tiempo y ruta azul
          if (mapState.selectedPlace != null)
            Positioned(
              bottom: 12,
              left: 12,
              right: 58,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xEB141820),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1D8BFF)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      color: Color(0xFF1D8BFF),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mapState.selectedPlace!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            mapState.selectedPlace!.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (mapState.isCalculatingRoute)
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 11,
                                  height: 11,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: Color(0xFF60A5FA),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Calculando ruta...',
                                  style: TextStyle(
                                    color: Color(0xFF60A5FA),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          else if (mapState.navigationDistanceMeters != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.directions_car_rounded,
                                  size: 13,
                                  color: Color(0xFF60A5FA),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    _formatRouteSummary(mapState),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.telemetryNumericStyle(
                                      fontSize: 11,
                                      color: const Color(0xFF60A5FA),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Recalcular ruta desde posición actual',
                      onPressed: mapState.isCalculatingRoute
                          ? null
                          : mapNotifier.recalculateRouteToSelectedPlace,
                      icon: const Icon(
                        Icons.alt_route_rounded,
                        color: Color(0xFF60A5FA),
                        size: 19,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Cerrar ruta',
                      onPressed: () => mapNotifier.selectNearbyPlace(null),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    final activePlan = ref.watch(
      digitalGaragePaymentProvider.select((s) => s.activeSubscription),
    );

    final Widget lapsCard = !activePlan.unlocksTrophyProFeatures
        ? Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 34,
                        color: RenaultSportPalette.siriusLiquidYellow,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'CRONÓMETRO DE LAPS GPS',
                        textAlign: TextAlign.center,
                        style: AppTheme.renaultSportHeaderStyle(
                          fontSize: 15,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Establece tu punto de partida, registra vueltas automáticas por GPS y sincronízalas en Firebase activando el Plan 3: RS Trophy Pro.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => ref
                            .read(cockpitTabProvider.notifier)
                            .selectTab(CockpitSectionTab.digitalGarage),
                        icon: const Icon(Icons.workspace_premium_rounded,
                            size: 18),
                        label: const Text('ACTIVAR PLAN 3 EN GARAGE'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : Card(
            child: LayoutBuilder(
              builder: (context, cardConstraints) {
                final isCompactVertical = cardConstraints.maxHeight < 340;
                final headerRow = Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'CRONÓMETRO LAPS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.renaultSportHeaderStyle(
                          fontSize: isCompactVertical ? 14 : 15,
                          color: primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (mapState.isLapSessionActive
                                ? RenaultSportPalette.oemShiftGreen
                                : Colors.grey)
                            .withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        mapState.isLapSessionActive ? 'ACTIVO' : 'EN ESPERA',
                        style: AppTheme.telemetryNumericStyle(
                          fontSize: 10,
                          color: mapState.isLapSessionActive
                              ? RenaultSportPalette.oemShiftGreen
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                );

                final actionButtons = Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: isCompactVertical
                            ? ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              )
                            : null,
                        onPressed:
                            mapNotifier.setStartFinishPointAtCurrentLocation,
                        icon: const Icon(Icons.flag_rounded, size: 17),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            mapState.isLapSessionActive
                                ? 'NUEVO PUNTO PARTIDA'
                                : 'ESTABLECER PUNTO PARTIDA',
                          ),
                        ),
                      ),
                    ),
                    if (mapState.isLapSessionActive) ...[
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        tooltip: 'Detener sesión de vueltas',
                        onPressed: mapNotifier.stopLapSession,
                        icon: const Icon(Icons.stop_rounded, size: 20),
                      ),
                    ],
                  ],
                );

                final clockBox = Container(
                  padding: EdgeInsets.all(isCompactVertical ? 10 : 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: mapState.isLapSessionActive
                          ? RenaultSportPalette.oemShiftGreen
                              .withValues(alpha: 0.5)
                          : Colors.white12,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.signpost_rounded,
                            size: 14,
                            color: RenaultSportPalette.siriusLiquidYellow,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              mapState.startStreetName.isNotEmpty
                                  ? mapState.startStreetName
                                  : mapState.currentStreetName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: RenaultSportPalette.siriusLiquidYellow,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatClock(mapState.currentLapElapsedSec),
                          style: AppTheme.digitalDisplayStyle(
                            fontSize: isCompactVertical ? 28 : 34,
                            color: mapState.isLapSessionActive
                                ? RenaultSportPalette.oemShiftGreen
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        !mapState.isLapSessionActive
                            ? 'Fija el punto de partida para cronometrar automáticamente'
                            : (!mapState.hasLeftStartZone
                                ? 'Aléjate >35m del punto (${mapState.distanceToStartMeters.round()}m)'
                                : 'En vuelta • Al volver al punto (<25m) se registra la Lap'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10.5),
                      ),
                    ],
                  ),
                );

                final lapsSummaryHeader = Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'VUELTAS (${mapState.completedLaps.length})',
                      style: AppTheme.telemetryNumericStyle(
                        fontSize: 11.5,
                        color: primary,
                      ),
                    ),
                    if (mapState.bestLapSec != null)
                      Text(
                        'MEJOR: ${_formatClock(mapState.bestLapSec!)}',
                        style: AppTheme.telemetryNumericStyle(
                          fontSize: 11,
                          color: RenaultSportPalette.oemShiftGreen,
                        ),
                      ),
                  ],
                );

                Widget buildLapTile(TrackLapEntry lap) {
                  final isBest = mapState.bestLapSec != null &&
                      (lap.durationSec - mapState.bestLapSec!).abs() < 0.05;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isBest
                          ? RenaultSportPalette.oemShiftGreen
                              .withValues(alpha: 0.14)
                          : Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isBest
                            ? RenaultSportPalette.oemShiftGreen
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LAP ${lap.lapNumber}',
                          style: AppTheme.renaultSportHeaderStyle(
                            fontSize: 13,
                            color: isBest
                                ? RenaultSportPalette.oemShiftGreen
                                : primary,
                          ),
                        ),
                        Text(
                          lap.formattedTime,
                          style: AppTheme.telemetryNumericStyle(
                            fontSize: 14,
                            color: isBest
                                ? RenaultSportPalette.oemShiftGreen
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (isCompactVertical) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        headerRow,
                        const SizedBox(height: 6),
                        actionButtons,
                        const SizedBox(height: 8),
                        clockBox,
                        if (mapState.firebaseSyncStatus != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.cloud_done_rounded,
                                size: 14,
                                color: RenaultSportPalette.oemShiftGreen,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  mapState.firebaseSyncStatus!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: RenaultSportPalette.oemShiftGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Divider(height: 12),
                        lapsSummaryHeader,
                        const SizedBox(height: 6),
                        if (mapState.completedLaps.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'Aún no se han completado vueltas.\nAl pasar nuevamente por el punto de partida se sumará la Lap y se subirá a Firebase.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: mapState.completedLaps.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, idx) =>
                                buildLapTile(mapState.completedLaps[idx]),
                          ),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      headerRow,
                      const SizedBox(height: 8),
                      actionButtons,
                      const SizedBox(height: 10),
                      clockBox,
                      if (mapState.firebaseSyncStatus != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.cloud_done_rounded,
                              size: 14,
                              color: RenaultSportPalette.oemShiftGreen,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                mapState.firebaseSyncStatus!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: RenaultSportPalette.oemShiftGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 16),
                      lapsSummaryHeader,
                      const SizedBox(height: 6),
                      Expanded(
                        child: mapState.completedLaps.isEmpty
                            ? const Center(
                                child: Text(
                                  'Aún no se han completado vueltas.\nAl pasar nuevamente por el punto de partida se sumará la Lap y se subirá a Firebase.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.white60,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: mapState.completedLaps.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (_, idx) =>
                                    buildLapTile(mapState.completedLaps[idx]),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 740;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: mapCard),
              const SizedBox(width: 10),
              Expanded(flex: 1, child: lapsCard),
            ],
          );
        }

        return Column(
          children: [
            Expanded(flex: 55, child: mapCard),
            const SizedBox(height: 10),
            Expanded(flex: 45, child: lapsCard),
          ],
        );
      },
    );
  }
}

class _CenteredVehicleBeacon extends StatelessWidget {
  final bool hasFix;
  final bool isMoving;

  const _CenteredVehicleBeacon({
    required this.hasFix,
    required this.isMoving,
  });

  @override
  Widget build(BuildContext context) {
    final beaconColor = hasFix
        ? const Color(0xFF2563EB)
        : RenaultSportPalette.sagemAmberOrange;

    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: beaconColor.withValues(alpha: 0.24),
            ),
          ),
          if (isMoving)
            Positioned(
              top: 0,
              child: Icon(
                Icons.arrow_drop_up_rounded,
                size: 20,
                color: beaconColor,
              ),
            ),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: beaconColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
