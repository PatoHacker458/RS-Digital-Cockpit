import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Punto de interés (POI) oficial para propietarios de Renault Clio RS 172
class RenaultSportPitMarker {
  final String id;
  final String title;
  final String category; // 'Taller Especialista RS' | 'Pits Oficiales' | 'Gasolinera 98 RON'
  final String technicalNotes;
  final LatLng position;

  const RenaultSportPitMarker({
    required this.id,
    required this.title,
    required this.category,
    required this.technicalNotes,
    required this.position,
  });
}

/// Estado inmutable de Geolocalización Nativa + Trazado de Circuito GPS
class TrackMapTelemetryState {
  final LatLng currentGpsPosition;
  final List<LatLng> routePolylinePoints;
  final List<RenaultSportPitMarker> officialPoiMarkers;
  final RenaultSportPitMarker? selectedPoi;
  final bool usingHardwareGps;
  final int lapCount;
  final double currentLapTimeSec;
  final double? bestLapTimeSec;

  const TrackMapTelemetryState({
    required this.currentGpsPosition,
    required this.routePolylinePoints,
    required this.officialPoiMarkers,
    this.selectedPoi,
    this.usingHardwareGps = false,
    this.lapCount = 1,
    this.currentLapTimeSec = 0.0,
    this.bestLapTimeSec = 84.32,
  });

  TrackMapTelemetryState copyWith({
    LatLng? currentGpsPosition,
    List<LatLng>? routePolylinePoints,
    List<RenaultSportPitMarker>? officialPoiMarkers,
    RenaultSportPitMarker? selectedPoi,
    bool? usingHardwareGps,
    int? lapCount,
    double? currentLapTimeSec,
    double? bestLapTimeSec,
  }) {
    return TrackMapTelemetryState(
      currentGpsPosition: currentGpsPosition ?? this.currentGpsPosition,
      routePolylinePoints: routePolylinePoints ?? this.routePolylinePoints,
      officialPoiMarkers: officialPoiMarkers ?? this.officialPoiMarkers,
      selectedPoi: selectedPoi ?? this.selectedPoi,
      usingHardwareGps: usingHardwareGps ?? this.usingHardwareGps,
      lapCount: lapCount ?? this.lapCount,
      currentLapTimeSec: currentLapTimeSec ?? this.currentLapTimeSec,
      bestLapTimeSec: bestLapTimeSec ?? this.bestLapTimeSec,
    );
  }
}

/// Notifier en Riverpod para Geolocalización Nativa (`geolocator` + `google_maps_flutter`).
/// Cumplimiento estricto: Gestión 100% reactiva en Riverpod.
class TrackMapTelemetryNotifier extends Notifier<TrackMapTelemetryState> {
  static const LatLng _autodromoCenter = LatLng(19.4042, -99.0888); // Autódromo Hnos. Rodríguez CDMX

  static const List<RenaultSportPitMarker> _defaultPois = <RenaultSportPitMarker>[
    RenaultSportPitMarker(
      id: 'pit_dieppe_mx',
      title: 'Taller Especialista Renault Sport "Atelier Dieppe F4R"',
      category: 'Taller Especialista RS',
      technicalNotes:
          'Herramienta oficial de bloqueo de árboles de levas F4R 736 (Mot.1496) y diagnóstico Renault CAN Clip / DDT2000.',
      position: LatLng(19.4068, -99.0915),
    ),
    RenaultSportPitMarker(
      id: 'pit_box_04',
      title: 'Pit Box Oficial Club Clio RS 172/182 Fase 2',
      category: 'Pits Oficiales',
      technicalNotes:
          'Telemetría Wi-Fi, ajuste de presiones Michelin Pilot Sport 3 (2.1 bar frío) y torquímetro Speedline Turini.',
      position: LatLng(19.4042, -99.0888),
    ),
    RenaultSportPitMarker(
      id: 'fuel_98_ron',
      title: 'Estación Alto Octanaje 98 RON (Mapa Sirius 34)',
      category: 'Gasolinera Alto Octanaje',
      technicalNotes:
          'Combustible Premium 98 RON libre de etanol para evitar picado (knock) con avance de 32° en el motor F4R.',
      position: LatLng(19.4018, -99.0856),
    ),
    RenaultSportPitMarker(
      id: 'pit_sagem_electronics',
      title: 'Laboratorio Electrónico ECU Siemens Sirius 34 & K-Line',
      category: 'Taller Especialista RS',
      technicalNotes:
          'Inmovilizador Sirius 34, banqueo de cuadro Sagem y sondas lambda Bosch.',
      position: LatLng(19.4055, -99.0842),
    ),
  ];

  StreamSubscription<Position>? _gpsSubscription;
  Timer? _trackSimulationTimer;
  double _theta = 0.0;

  @override
  TrackMapTelemetryState build() {
    _startGpsOrCircuitSimulation();
    ref.onDispose(() {
      _gpsSubscription?.cancel();
      _trackSimulationTimer?.cancel();
    });
    return TrackMapTelemetryState(
      currentGpsPosition: _autodromoCenter,
      routePolylinePoints: const <LatLng>[_autodromoCenter],
      officialPoiMarkers: _defaultPois,
      selectedPoi: _defaultPois[0],
    );
  }

  Future<void> _startGpsOrCircuitSimulation() async {
    // 1. Intentar adquirir stream GPS nativo de la Pixel Tablet
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          _gpsSubscription = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 3,
            ),
          ).listen((Position pos) {
            final nextLatLng = LatLng(pos.latitude, pos.longitude);
            final updatedRoute = <LatLng>[
              ...state.routePolylinePoints.take(80),
              nextLatLng,
            ];
            state = state.copyWith(
              currentGpsPosition: nextLatLng,
              routePolylinePoints: updatedRoute,
              usingHardwareGps: true,
            );
          });
        }
      }
    } catch (_) {}

    // 2. Generador de trayectoria de circuito para demostración continua en salón de clases
    _trackSimulationTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (state.usingHardwareGps) return;
      _theta += 0.075;
      final nextLapTime = state.currentLapTimeSec + 0.4;
      var laps = state.lapCount;
      var lapClock = nextLapTime;

      if (_theta >= 2 * math.pi) {
        _theta = 0.0;
        laps += 1;
        lapClock = 0.0;
      }

      // Curva paramétrica estilo circuito (recta principal + eses + horquilla Foro Sol)
      final dLat = 0.0028 * math.sin(_theta) + 0.0008 * math.sin(2 * _theta);
      final dLng = 0.0042 * math.cos(_theta) - 0.0009 * math.cos(3 * _theta);
      final nextPos = LatLng(
        _autodromoCenter.latitude + dLat,
        _autodromoCenter.longitude + dLng,
      );

      final updatedPoints = <LatLng>[
        ...state.routePolylinePoints.take(90),
        nextPos,
      ];

      state = state.copyWith(
        currentGpsPosition: nextPos,
        routePolylinePoints: updatedPoints,
        lapCount: laps,
        currentLapTimeSec: double.parse(lapClock.toStringAsFixed(1)),
      );
    });
  }

  void selectPoi(RenaultSportPitMarker marker) {
    state = state.copyWith(selectedPoi: marker);
  }
}

final trackMapTelemetryProvider =
    NotifierProvider<TrackMapTelemetryNotifier, TrackMapTelemetryState>(
  TrackMapTelemetryNotifier.new,
);
