import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../firebase_options.dart';
import '../auth_profile/providers/auth_profile_providers.dart';
import '../cloud_sync_fcm/fcm_notification_service.dart';

/// Filtros simples del mapa en TRACK
enum TrackMapFilter {
  workshops('Talleres', 'taller mecanico'),
  gasStations('Gasolineras', 'gasolinera'),
  parking('Estacionamientos', 'estacionamiento');

  final String label;
  final String searchQuery;

  const TrackMapFilter(
    this.label,
    this.searchQuery,
  );
}

/// Lugar cercano real encontrado por filtro en el mapa
class NearbyMapPlace {
  final String id;
  final String name;
  final String subtitle;
  final TrackMapFilter filter;
  final LatLng position;

  const NearbyMapPlace({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.filter,
    required this.position,
  });
}

/// Registro individual de una vuelta cronometrada por cruce GPS
class TrackLapEntry {
  final int lapNumber;
  final double durationSec;
  final DateTime completedAt;

  const TrackLapEntry({
    required this.lapNumber,
    required this.durationSec,
    required this.completedAt,
  });

  String get formattedTime {
    final totalTenths = (durationSec * 10).round();
    final mins = totalTenths ~/ 600;
    final secs = (totalTenths % 600) ~/ 10;
    final tenths = totalTenths % 10;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.$tenths';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lapNumber': lapNumber,
        'durationSec': double.parse(durationSec.toStringAsFixed(2)),
        'formattedTime': formattedTime,
        'completedAt': completedAt.toIso8601String(),
      };
}

class _OsrmRouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const _OsrmRouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

/// Estado inmutable de Ubicación GPS en Tiempo Real, Filtros Cercanos,
/// Navegación al destino seleccionado y Cronómetro de Laps.
class TrackMapTelemetryState {
  final LatLng currentGpsPosition;
  final bool hasRealGpsFix;
  final double currentHeading;
  final double currentSpeedMps;
  final String currentStreetName;
  final List<LatLng> routePolylinePoints;

  // Filtros de lugares cercanos y ruta calculada
  final TrackMapFilter? activeFilter;
  final bool isLoadingPlaces;
  final List<NearbyMapPlace> nearbyPlaces;
  final NearbyMapPlace? selectedPlace;
  final List<LatLng> navigationRoutePoints;
  final double? navigationDistanceMeters;
  final double? navigationDurationSec;
  final bool isCalculatingRoute;
  final bool isDirectFallbackRoute;

  // Cronómetro funcional de vueltas (Start / Finish GPS)
  final LatLng? startFinishPoint;
  final String startStreetName;
  final bool isLapSessionActive;
  final bool hasLeftStartZone;
  final double distanceToStartMeters;
  final double currentLapElapsedSec;
  final List<TrackLapEntry> completedLaps;
  final String? firebaseSyncStatus;

  const TrackMapTelemetryState({
    required this.currentGpsPosition,
    this.hasRealGpsFix = false,
    this.currentHeading = 0.0,
    this.currentSpeedMps = 0.0,
    this.currentStreetName = 'Buscando señal GPS...',
    this.routePolylinePoints = const <LatLng>[],
    this.activeFilter,
    this.isLoadingPlaces = false,
    this.nearbyPlaces = const <NearbyMapPlace>[],
    this.selectedPlace,
    this.navigationRoutePoints = const <LatLng>[],
    this.navigationDistanceMeters,
    this.navigationDurationSec,
    this.isCalculatingRoute = false,
    this.isDirectFallbackRoute = false,
    this.startFinishPoint,
    this.startStreetName = '',
    this.isLapSessionActive = false,
    this.hasLeftStartZone = false,
    this.distanceToStartMeters = 0.0,
    this.currentLapElapsedSec = 0.0,
    this.completedLaps = const <TrackLapEntry>[],
    this.firebaseSyncStatus,
  });

  double? get bestLapSec {
    if (completedLaps.isEmpty) return null;
    return completedLaps
        .map((e) => e.durationSec)
        .reduce((a, b) => a < b ? a : b);
  }

  TrackMapTelemetryState copyWith({
    LatLng? currentGpsPosition,
    bool? hasRealGpsFix,
    double? currentHeading,
    double? currentSpeedMps,
    String? currentStreetName,
    List<LatLng>? routePolylinePoints,
    TrackMapFilter? activeFilter,
    bool clearFilter = false,
    bool? isLoadingPlaces,
    List<NearbyMapPlace>? nearbyPlaces,
    NearbyMapPlace? selectedPlace,
    bool clearSelectedPlace = false,
    List<LatLng>? navigationRoutePoints,
    double? navigationDistanceMeters,
    double? navigationDurationSec,
    bool? isCalculatingRoute,
    bool? isDirectFallbackRoute,
    bool clearNavigationRoute = false,
    LatLng? startFinishPoint,
    bool clearStartFinishPoint = false,
    String? startStreetName,
    bool? isLapSessionActive,
    bool? hasLeftStartZone,
    double? distanceToStartMeters,
    double? currentLapElapsedSec,
    List<TrackLapEntry>? completedLaps,
    String? firebaseSyncStatus,
    bool clearFirebaseSyncStatus = false,
  }) {
    return TrackMapTelemetryState(
      currentGpsPosition: currentGpsPosition ?? this.currentGpsPosition,
      hasRealGpsFix: hasRealGpsFix ?? this.hasRealGpsFix,
      currentHeading: currentHeading ?? this.currentHeading,
      currentSpeedMps: currentSpeedMps ?? this.currentSpeedMps,
      currentStreetName: currentStreetName ?? this.currentStreetName,
      routePolylinePoints: routePolylinePoints ?? this.routePolylinePoints,
      activeFilter: clearFilter ? null : (activeFilter ?? this.activeFilter),
      isLoadingPlaces: isLoadingPlaces ?? this.isLoadingPlaces,
      nearbyPlaces: nearbyPlaces ?? this.nearbyPlaces,
      selectedPlace: clearSelectedPlace
          ? null
          : (selectedPlace ?? this.selectedPlace),
      navigationRoutePoints: clearNavigationRoute
          ? const <LatLng>[]
          : (navigationRoutePoints ?? this.navigationRoutePoints),
      navigationDistanceMeters: clearNavigationRoute
          ? null
          : (navigationDistanceMeters ?? this.navigationDistanceMeters),
      navigationDurationSec: clearNavigationRoute
          ? null
          : (navigationDurationSec ?? this.navigationDurationSec),
      isCalculatingRoute: clearNavigationRoute
          ? false
          : (isCalculatingRoute ?? this.isCalculatingRoute),
      isDirectFallbackRoute: clearNavigationRoute
          ? false
          : (isDirectFallbackRoute ?? this.isDirectFallbackRoute),
      startFinishPoint: clearStartFinishPoint
          ? null
          : (startFinishPoint ?? this.startFinishPoint),
      startStreetName: startStreetName ?? this.startStreetName,
      isLapSessionActive: isLapSessionActive ?? this.isLapSessionActive,
      hasLeftStartZone: hasLeftStartZone ?? this.hasLeftStartZone,
      distanceToStartMeters:
          distanceToStartMeters ?? this.distanceToStartMeters,
      currentLapElapsedSec: currentLapElapsedSec ?? this.currentLapElapsedSec,
      completedLaps: completedLaps ?? this.completedLaps,
      firebaseSyncStatus: clearFirebaseSyncStatus
          ? null
          : (firebaseSyncStatus ?? this.firebaseSyncStatus),
    );
  }
}

/// Notifier 100% Riverpod para GPS Real fluido (estilo videojuego), Lugares Cercanos,
/// Ruta Calculada (OSRM) y Cronómetro Automático de Laps con sincronización a Firebase.
class TrackMapTelemetryNotifier extends Notifier<TrackMapTelemetryState> {
  static const MethodChannel _launcherChannel =
      MethodChannel('com.renaultsport.clio172/launcher');

  // Umbrales geofence del punto de partida/meta
  static const double _leaveZoneRadiusMeters = 35.0;
  static const double _crossFinishRadiusMeters = 25.0;
  static const double _minLapDurationSec = 8.0;

  StreamSubscription<Position>? _gpsSubscription;
  bool _isStartingGps = false;
  Timer? _lapStopwatchTimer;
  DateTime? _currentLapStartedAt;
  DateTime _lastGeocodeAt = DateTime.fromMillisecondsSinceEpoch(0);
  LatLng? _previousGpsForOdometer;
  String? _activeFirebaseSessionKey;

  GoogleMapController? _miniMapController;
  GoogleMapController? _fullTrackMapController;

  @override
  TrackMapTelemetryState build() {
    _startRealGpsStream();
    ref.onDispose(() {
      _gpsSubscription?.cancel();
      _gpsSubscription = null;
      _lapStopwatchTimer?.cancel();
    });
    return const TrackMapTelemetryState(
      currentGpsPosition: LatLng(20.6597, -103.3496),
    );
  }

  void ensureGpsTrackingActive() {
    if (_gpsSubscription == null && !_isStartingGps) {
      _startRealGpsStream();
    }
  }

  void attachMiniMapController(GoogleMapController controller) {
    _miniMapController = controller;
    ensureGpsTrackingActive();
    if (state.hasRealGpsFix) {
      _followMiniMapCamera(
        state.currentGpsPosition,
        bearing: state.currentHeading,
        instant: true,
      );
    }
  }

  void attachFullTrackMapController(GoogleMapController controller) {
    _fullTrackMapController = controller;
    ensureGpsTrackingActive();
    if (state.hasRealGpsFix) {
      _animateMapTo(_fullTrackMapController, state.currentGpsPosition,
          zoom: 15.6);
    }
  }

  void centerCameraOnCurrentLocation() {
    _followMiniMapCamera(
      state.currentGpsPosition,
      bearing: state.currentHeading,
    );
    _animateMapTo(_fullTrackMapController, state.currentGpsPosition,
        zoom: 15.8);
  }

  void _followMiniMapCamera(
    LatLng target, {
    double bearing = 0.0,
    bool instant = false,
  }) {
    final controller = _miniMapController;
    if (controller == null) return;
    try {
      final cam = CameraPosition(
        target: target,
        zoom: 17.2,
        bearing: bearing,
        tilt: 35.0,
      );
      if (instant) {
        controller.moveCamera(CameraUpdate.newCameraPosition(cam));
      } else {
        controller.animateCamera(CameraUpdate.newCameraPosition(cam));
      }
    } catch (_) {}
  }

  void _animateMapTo(
    GoogleMapController? controller,
    LatLng target, {
    double zoom = 15.8,
  }) {
    if (controller == null) return;
    try {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: zoom),
        ),
      );
    } catch (_) {}
  }

  Future<void> _startRealGpsStream() async {
    if (_isStartingGps) return;
    _isStartingGps = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(currentStreetName: 'Activa el GPS del dispositivo');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        state =
            state.copyWith(currentStreetName: 'Permiso de ubicación denegado');
        return;
      }

      // 1. Obtener posición inmediata conocida o actual para centrar al instante
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _handleNewGpsPosition(lastKnown, isInitialFix: true);
      }

      try {
        final currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 6));
        _handleNewGpsPosition(currentPos, isInitialFix: !state.hasRealGpsFix);
      } catch (_) {}

      // 2. Suscribirse al stream GPS de alta frecuencia (~400 ms en Android)
      final LocationSettings streamSettings = Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 0,
              intervalDuration: const Duration(milliseconds: 400),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 1,
            );

      await _gpsSubscription?.cancel();
      _gpsSubscription = Geolocator.getPositionStream(
        locationSettings: streamSettings,
      ).listen(
        (Position pos) {
          _handleNewGpsPosition(pos, isInitialFix: !state.hasRealGpsFix);
        },
        onError: (_) {
          _gpsSubscription = null;
        },
        onDone: () {
          _gpsSubscription = null;
        },
      );
    } catch (_) {
      state = state.copyWith(currentStreetName: 'GPS no disponible');
    } finally {
      _isStartingGps = false;
    }
  }

  void _handleNewGpsPosition(Position pos, {bool isInitialFix = false}) {
    final nextLatLng = LatLng(pos.latitude, pos.longitude);
    final nextSpeedMps =
        (!pos.speed.isNaN && pos.speed >= 0.0) ? pos.speed : 0.0;
    final hasValidHeading =
        !pos.heading.isNaN && pos.heading >= 0.0 && nextSpeedMps >= 1.2;
    final nextHeading = hasValidHeading ? pos.heading : state.currentHeading;

    // 1. Integrar distancia GPS real al odómetro automático de mantenimiento
    if (_previousGpsForOdometer != null) {
      final meters = Geolocator.distanceBetween(
        _previousGpsForOdometer!.latitude,
        _previousGpsForOdometer!.longitude,
        nextLatLng.latitude,
        nextLatLng.longitude,
      );
      if (meters >= 3.0 && meters <= 350.0) {
        ref
            .read(fcmTopicsProvider.notifier)
            .addDrivenDistanceKm(meters / 1000.0);
      }
    }
    _previousGpsForOdometer = nextLatLng;

    // 2. Actualizar trazado de ruta SOLO si el desplazamiento >= 2m durante una sesión de laps
    var updatedRoute = state.routePolylinePoints;
    if (state.isLapSessionActive) {
      final shouldAppend = updatedRoute.isEmpty ||
          Geolocator.distanceBetween(
                updatedRoute.last.latitude,
                updatedRoute.last.longitude,
                nextLatLng.latitude,
                nextLatLng.longitude,
              ) >=
              2.0;
      if (shouldAppend) {
        updatedRoute = <LatLng>[
          ...state.routePolylinePoints.take(300),
          nextLatLng,
        ];
      }
    }

    // 3. Lógica de detección automática de cruce por el Punto de Partida (Laps)
    var hasLeftZone = state.hasLeftStartZone;
    var distToStart = state.distanceToStartMeters;
    var completedLaps = state.completedLaps;
    var lapElapsed = state.currentLapElapsedSec;
    var lapJustCompleted = false;

    if (state.isLapSessionActive && state.startFinishPoint != null) {
      distToStart = Geolocator.distanceBetween(
        state.startFinishPoint!.latitude,
        state.startFinishPoint!.longitude,
        nextLatLng.latitude,
        nextLatLng.longitude,
      );

      if (!hasLeftZone && distToStart >= _leaveZoneRadiusMeters) {
        hasLeftZone = true;
      } else if (hasLeftZone &&
          distToStart <= _crossFinishRadiusMeters &&
          lapElapsed >= _minLapDurationSec) {
        // ¡CRUCE POR EL PUNTO DE PARTIDA DETECTADO -> SUMAR LAP!
        final finishedLap = TrackLapEntry(
          lapNumber: completedLaps.length + 1,
          durationSec: lapElapsed,
          completedAt: DateTime.now(),
        );
        completedLaps = <TrackLapEntry>[finishedLap, ...completedLaps];
        _currentLapStartedAt = DateTime.now();
        lapElapsed = 0.0;
        hasLeftZone = false;
        lapJustCompleted = true;
      }
    }

    state = state.copyWith(
      currentGpsPosition: nextLatLng,
      hasRealGpsFix: true,
      currentHeading: nextHeading,
      currentSpeedMps: nextSpeedMps,
      routePolylinePoints: updatedRoute,
      hasLeftStartZone: hasLeftZone,
      distanceToStartMeters: distToStart,
      completedLaps: completedLaps,
      currentLapElapsedSec: lapElapsed,
    );

    // Centrar y orientar el minimapa SIEMPRE en tiempo real (tipo videojuego)
    _followMiniMapCamera(
      nextLatLng,
      bearing: nextHeading,
      instant: isInitialFix,
    );
    if (isInitialFix) {
      _animateMapTo(_fullTrackMapController, nextLatLng, zoom: 15.6);
    }

    // Actualizar nombre de la calle actual cada 15s (o al primer fix)
    if (isInitialFix ||
        DateTime.now().difference(_lastGeocodeAt).inSeconds >= 15) {
      _lastGeocodeAt = DateTime.now();
      _refreshCurrentStreetName(nextLatLng);
    }

    // Subir automáticamente a Firebase cuando se completa una vuelta
    if (lapJustCompleted) {
      uploadCurrentLapSessionToFirebase();
    }
  }

  Future<String> _resolveStreetName(LatLng point) async {
    try {
      final nativeName = await _launcherChannel.invokeMethod<String>(
        'reverseGeocode',
        <String, dynamic>{
          'lat': point.latitude,
          'lng': point.longitude,
        },
      );
      if (nativeName != null &&
          nativeName.trim().isNotEmpty &&
          nativeName != 'Circuito GPS') {
        return nativeName.trim();
      }
    } catch (_) {}

    // Fallback: OpenStreetMap Nominatim reverse geocoding
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=17&addressdetails=1',
      );
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'RSDigitalCockpit/2.0');
      final resp = await req.close().timeout(const Duration(seconds: 4));
      final body = await resp.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final address = decoded['address'] as Map<String, dynamic>?;
      final road = (address?['road'] as String?) ??
          (address?['pedestrian'] as String?) ??
          (address?['suburb'] as String?) ??
          (decoded['name'] as String?);
      if (road != null && road.trim().isNotEmpty) {
        return road.trim();
      }
    } catch (_) {
    } finally {
      client.close(force: true);
    }

    return 'Calle ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
  }

  Future<void> _refreshCurrentStreetName(LatLng point) async {
    final street = await _resolveStreetName(point);
    state = state.copyWith(currentStreetName: street);
  }

  /// Activa o desactiva un filtro simple del mapa (Talleres, Gasolineras, Estacionamientos)
  /// buscando lugares REALES alrededor de la ubicación GPS actual con Nominatim + Photon.
  Future<void> toggleMapFilter(TrackMapFilter filter) async {
    if (state.activeFilter == filter) {
      state = state.copyWith(
        clearFilter: true,
        nearbyPlaces: const <NearbyMapPlace>[],
        clearSelectedPlace: true,
        clearNavigationRoute: true,
        isLoadingPlaces: false,
      );
      return;
    }

    state = state.copyWith(
      activeFilter: filter,
      isLoadingPlaces: true,
      nearbyPlaces: const <NearbyMapPlace>[],
      clearSelectedPlace: true,
      clearNavigationRoute: true,
    );

    final pos = state.currentGpsPosition;
    var found = await _fetchFromNominatimViewbox(pos, filter);
    if (found.length < 4) {
      final photonPlaces = await _fetchFromPhotonNearby(pos, filter);
      final existingKeys = found.map((e) => e.id).toSet();
      for (final p in photonPlaces) {
        if (existingKeys.add(p.id)) {
          found = <NearbyMapPlace>[...found, p];
        }
      }
    }

    if (state.activeFilter != filter) return;
    state = state.copyWith(
      isLoadingPlaces: false,
      nearbyPlaces: found,
    );

    if (found.isNotEmpty) {
      _fitCameraToPlaces(pos, found);
    }
  }

  void _fitCameraToPlaces(LatLng center, List<NearbyMapPlace> places) {
    final points = <LatLng>[
      center,
      ...places.take(8).map((p) => p.position),
    ];
    _fitCameraToPoints(points, padding: 56);
  }

  void _fitCameraToPoints(List<LatLng> points, {double padding = 72}) {
    final controller = _fullTrackMapController;
    if (controller == null || points.isEmpty) return;
    try {
      var minLat = points.first.latitude;
      var maxLat = points.first.latitude;
      var minLng = points.first.longitude;
      var maxLng = points.first.longitude;

      for (final p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      if ((maxLat - minLat).abs() < 0.0015 &&
          (maxLng - minLng).abs() < 0.0015) {
        _animateMapTo(
          controller,
          LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
          zoom: 15.5,
        );
        return;
      }

      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          padding,
        ),
      );
    } catch (_) {
      _animateMapTo(controller, points.first, zoom: 13.8);
    }
  }

  /// Búsqueda acotada por bounding box (~8 km) en OpenStreetMap Nominatim
  Future<List<NearbyMapPlace>> _fetchFromNominatimViewbox(
    LatLng center,
    TrackMapFilter filter,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);
    try {
      const delta = 0.075;
      final left = center.longitude - delta;
      final right = center.longitude + delta;
      final top = center.latitude + delta;
      final bottom = center.latitude - delta;

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json&addressdetails=1&limit=15&bounded=1'
        '&q=${Uri.encodeQueryComponent(filter.searchQuery)}'
        '&viewbox=$left,$top,$right,$bottom',
      );
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'RSDigitalCockpit/2.0 (Android)');
      req.headers.set('Accept', 'application/json');
      final resp = await req.close().timeout(const Duration(seconds: 6));
      final body = await resp.transform(utf8.decoder).join();

      final list = jsonDecode(body) as List<dynamic>;
      final places = <NearbyMapPlace>[];
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final lat = double.tryParse(m['lat']?.toString() ?? '');
        final lon = double.tryParse(m['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;

        final displayName = (m['display_name'] as String?) ?? filter.label;
        final parts = displayName.split(',').map((s) => s.trim()).toList();
        final title = ((m['name'] as String?)?.trim().isNotEmpty ?? false)
            ? (m['name'] as String).trim()
            : (parts.isNotEmpty ? parts.first : filter.label);
        final subtitle =
            parts.length > 1 ? parts.skip(1).take(2).join(', ') : filter.label;

        places.add(
          NearbyMapPlace(
            id: 'nom_${m['place_id'] ?? '${lat}_$lon'}',
            name: title,
            subtitle: subtitle,
            filter: filter,
            position: LatLng(lat, lon),
          ),
        );
      }
      return places;
    } catch (_) {
      return const <NearbyMapPlace>[];
    } finally {
      client.close(force: true);
    }
  }

  /// Respaldo ultrarrápido con Photon Komoot filtrado por distancia real <= 12 km
  Future<List<NearbyMapPlace>> _fetchFromPhotonNearby(
    LatLng center,
    TrackMapFilter filter,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);
    try {
      final uri = Uri.parse(
        'https://photon.komoot.io/api/'
        '?q=${Uri.encodeQueryComponent(filter.searchQuery)}'
        '&lat=${center.latitude}&lon=${center.longitude}&limit=15',
      );
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'RSDigitalCockpit/2.0 (Android)');
      final resp = await req.close().timeout(const Duration(seconds: 6));
      final body = await resp.transform(utf8.decoder).join();

      final json = jsonDecode(body) as Map<String, dynamic>;
      final features = json['features'] as List<dynamic>? ?? const <dynamic>[];
      final places = <NearbyMapPlace>[];

      for (final f in features) {
        final m = f as Map<String, dynamic>;
        final geom = m['geometry'] as Map<String, dynamic>?;
        final coords = geom?['coordinates'] as List<dynamic>?;
        if (coords == null || coords.length < 2) continue;

        final lon = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        final distMeters = Geolocator.distanceBetween(
          center.latitude,
          center.longitude,
          lat,
          lon,
        );
        if (distMeters > 12000.0) continue;

        final props =
            m['properties'] as Map<String, dynamic>? ?? const <String, dynamic>{};
        final name = (props['name'] as String?) ?? filter.label;
        final street = (props['street'] as String?) ??
            (props['district'] as String?) ??
            (props['city'] as String?) ??
            '${(distMeters / 1000.0).toStringAsFixed(1)} km';

        places.add(
          NearbyMapPlace(
            id: 'ph_${props['osm_id'] ?? '${lat}_$lon'}',
            name: name,
            subtitle: '$street • ${(distMeters / 1000.0).toStringAsFixed(1)} km',
            filter: filter,
            position: LatLng(lat, lon),
          ),
        );
      }
      return places;
    } catch (_) {
      return const <NearbyMapPlace>[];
    } finally {
      client.close(force: true);
    }
  }

  /// Selecciona un lugar cercano y traza automáticamente la ruta en coche (línea azul)
  void selectNearbyPlace(NearbyMapPlace? place) {
    if (place == null) {
      state = state.copyWith(
        clearSelectedPlace: true,
        clearNavigationRoute: true,
      );
      return;
    }

    state = state.copyWith(
      selectedPlace: place,
      clearNavigationRoute: true,
      isCalculatingRoute: true,
    );
    _calculateDrivingRouteToPlace(place);
  }

  Future<void> recalculateRouteToSelectedPlace() async {
    final place = state.selectedPlace;
    if (place == null) return;
    state = state.copyWith(
      isCalculatingRoute: true,
      isDirectFallbackRoute: false,
    );
    await _calculateDrivingRouteToPlace(place);
  }

  Future<void> _calculateDrivingRouteToPlace(NearbyMapPlace place) async {
    final origin = state.currentGpsPosition;
    final dest = place.position;

    var routeResult = await _queryOsrmRoute(
      baseUrl: 'https://router.project-osrm.org/route/v1/driving',
      origin: origin,
      destination: dest,
    );
    routeResult ??= await _queryOsrmRoute(
      baseUrl: 'https://routing.openstreetmap.de/routed-car/route/v1/driving',
      origin: origin,
      destination: dest,
    );

    if (state.selectedPlace?.id != place.id) return;

    if (routeResult != null && routeResult.points.length >= 2) {
      state = state.copyWith(
        navigationRoutePoints: routeResult.points,
        navigationDistanceMeters: routeResult.distanceMeters,
        navigationDurationSec: routeResult.durationSeconds,
        isCalculatingRoute: false,
        isDirectFallbackRoute: false,
      );
      _fitCameraToPoints(routeResult.points, padding: 72);
      return;
    }

    // Fallback elegante si no hay red hacia OSRM: línea directa discontinua
    final straightDist = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      dest.latitude,
      dest.longitude,
    );
    final fallbackPoints = <LatLng>[origin, dest];
    state = state.copyWith(
      navigationRoutePoints: fallbackPoints,
      navigationDistanceMeters: straightDist,
      navigationDurationSec: null,
      isCalculatingRoute: false,
      isDirectFallbackRoute: true,
    );
    _fitCameraToPoints(fallbackPoints, padding: 72);
  }

  Future<_OsrmRouteResult?> _queryOsrmRoute({
    required String baseUrl,
    required LatLng origin,
    required LatLng destination,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);
    try {
      final uri = Uri.parse(
        '$baseUrl/${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'RSDigitalCockpit/2.0 (Android)');
      req.headers.set('Accept', 'application/json');
      final resp = await req.close().timeout(const Duration(seconds: 7));
      if (resp.statusCode != 200) return null;
      final body = await resp.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final first = routes.first;
      if (first is! Map) return null;
      final geometry = first['geometry'];
      if (geometry is! Map) return null;
      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2) return null;

      final points = <LatLng>[];
      for (final pt in coords) {
        if (pt is List && pt.length >= 2) {
          final lon = (pt[0] as num).toDouble();
          final lat = (pt[1] as num).toDouble();
          points.add(LatLng(lat, lon));
        }
      }
      if (points.length < 2) return null;

      return _OsrmRouteResult(
        points: points,
        distanceMeters: (first['distance'] as num?)?.toDouble() ?? 0.0,
        durationSeconds: (first['duration'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Establece el Punto de Partida / Meta en la ubicación GPS actual,
  /// resuelve el nombre de la calle para el registro de Firebase e inicia el cronómetro.
  Future<void> setStartFinishPointAtCurrentLocation() async {
    final startPos = state.currentGpsPosition;
    _lapStopwatchTimer?.cancel();

    final now = DateTime.now();
    _currentLapStartedAt = now;

    final street = await _resolveStreetName(startPos);
    final sanitizedStreet = street
        .replaceAll(RegExp(r'[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ\s_-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    _activeFirebaseSessionKey =
        '${sanitizedStreet.isEmpty ? 'Circuito_GPS' : sanitizedStreet}_$stamp';

    state = state.copyWith(
      startFinishPoint: startPos,
      startStreetName: street,
      isLapSessionActive: true,
      hasLeftStartZone: false,
      distanceToStartMeters: 0.0,
      currentLapElapsedSec: 0.0,
      completedLaps: const <TrackLapEntry>[],
      routePolylinePoints: <LatLng>[startPos],
      firebaseSyncStatus: 'Punto fijado en $street',
    );

    _animateMapTo(_fullTrackMapController, startPos, zoom: 16.0);

    _lapStopwatchTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!state.isLapSessionActive || _currentLapStartedAt == null) return;
      final elapsed =
          DateTime.now().difference(_currentLapStartedAt!).inMilliseconds /
              1000.0;
      state = state.copyWith(currentLapElapsedSec: elapsed);
    });
  }

  /// Detiene el cronómetro actual (sube las vueltas registradas si hubo al menos una)
  Future<void> stopLapSession() async {
    _lapStopwatchTimer?.cancel();
    _lapStopwatchTimer = null;
    if (state.completedLaps.isNotEmpty) {
      await uploadCurrentLapSessionToFirebase();
    }
    state = state.copyWith(
      isLapSessionActive: false,
    );
  }

  /// Sube a Firebase Realtime Database el registro de laps nombrado con la calle de partida
  Future<void> uploadCurrentLapSessionToFirebase() async {
    if (state.startFinishPoint == null || state.completedLaps.isEmpty) return;

    final pilot = ref.read(pilotAuthProvider);
    final uid = pilot?.uid ?? 'anonymous-rs172';
    final streetName = state.startStreetName.isNotEmpty
        ? state.startStreetName
        : state.currentStreetName;
    final key = _activeFirebaseSessionKey ??
        'Circuito_${DateTime.now().millisecondsSinceEpoch}';

    final orderedLaps = state.completedLaps.reversed.toList();
    final payload = <String, dynamic>{
      'recordName': streetName,
      'streetName': streetName,
      'startLat': state.startFinishPoint!.latitude,
      'startLng': state.startFinishPoint!.longitude,
      'totalLaps': orderedLaps.length,
      'bestLapSec': state.bestLapSec,
      'laps': orderedLaps.map((l) => l.toJson()).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    try {
      if (Firebase.apps.isNotEmpty) {
        final db = FirebaseDatabase.instanceFor(
          app: Firebase.app(),
          databaseURL: DefaultFirebaseOptions.android.databaseURL,
        );
        await db
            .ref('track_lap_sessions/$uid/$key')
            .set(payload)
            .timeout(const Duration(seconds: 6));
        state = state.copyWith(
          firebaseSyncStatus:
              'Sincronizado en Firebase ("$streetName" • ${orderedLaps.length} laps)',
        );
      } else {
        state = state.copyWith(
          firebaseSyncStatus: 'Guardado localmente (Firebase no inicializado)',
        );
      }
    } catch (_) {
      state = state.copyWith(
        firebaseSyncStatus: 'Guardado localmente (pendiente de red)',
      );
    }
  }
}

final trackMapTelemetryProvider =
    NotifierProvider<TrackMapTelemetryNotifier, TrackMapTelemetryState>(
  TrackMapTelemetryNotifier.new,
);
