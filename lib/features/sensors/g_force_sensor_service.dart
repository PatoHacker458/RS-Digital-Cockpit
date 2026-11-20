import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../telemetry/providers/telemetry_providers.dart';

/// Vector de Fuerzas G (Lateral X, Longitudinal Y, Magnitud Resultante y Picos)
/// con calibración de punto cero en el ángulo actual del soporte en el auto.
class GForceTelemetryState {
  final double lateralG;
  final double longitudinalG;
  final double yawRateDegSec;
  final double peakG;
  final List<({double x, double y})> trailPoints;
  final bool usingHardwareSensor;
  final bool isCalibrated;

  const GForceTelemetryState({
    this.lateralG = 0.0,
    this.longitudinalG = 0.0,
    this.yawRateDegSec = 0.0,
    this.peakG = 0.0,
    this.trailPoints = const [],
    this.usingHardwareSensor = true,
    this.isCalibrated = false,
  });

  double get resultantG =>
      math.sqrt((lateralG * lateralG) + (longitudinalG * longitudinalG));

  GForceTelemetryState copyWith({
    double? lateralG,
    double? longitudinalG,
    double? yawRateDegSec,
    double? peakG,
    List<({double x, double y})>? trailPoints,
    bool? usingHardwareSensor,
    bool? isCalibrated,
  }) {
    return GForceTelemetryState(
      lateralG: lateralG ?? this.lateralG,
      longitudinalG: longitudinalG ?? this.longitudinalG,
      yawRateDegSec: yawRateDegSec ?? this.yawRateDegSec,
      peakG: peakG ?? this.peakG,
      trailPoints: trailPoints ?? this.trailPoints,
      usingHardwareSensor: usingHardwareSensor ?? this.usingHardwareSensor,
      isCalibrated: isCalibrated ?? this.isCalibrated,
    );
  }
}

/// Notifier de Sensores Inerciales IMU (Acelerómetro + Giroscopio) con Calibración de Cero.
class GForceSensorNotifier extends Notifier<GForceTelemetryState> {
  static const double _gravityMs2 = 9.80665;
  static const double _lowPassAlpha = 0.20;
  static const String _prefLatZeroKey = 'rs_gforce_zero_lat';
  static const String _prefLonZeroKey = 'rs_gforce_zero_lon';

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _simFallbackTimer;

  double _lastRawLatG = 0.0;
  double _lastRawLonG = 0.0;
  double _zeroOffsetLatG = 0.0;
  double _zeroOffsetLonG = 0.0;
  double _filteredLatG = 0.0;
  double _filteredLonG = 0.0;
  double _lastYawDegSec = 0.0;
  bool _hasHardwareEvents = false;

  @override
  GForceTelemetryState build() {
    _loadSavedCalibration();
    _initHardwareImuStreams();
    ref.onDispose(() {
      _accelSub?.cancel();
      _gyroSub?.cancel();
      _simFallbackTimer?.cancel();
    });
    return const GForceTelemetryState();
  }

  Future<void> _loadSavedCalibration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLat = prefs.getDouble(_prefLatZeroKey);
      final savedLon = prefs.getDouble(_prefLonZeroKey);
      if (savedLat != null && savedLon != null) {
        _zeroOffsetLatG = savedLat;
        _zeroOffsetLonG = savedLon;
        state = state.copyWith(isCalibrated: true);
      }
    } catch (_) {}
  }

  void _initHardwareImuStreams() {
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (AccelerometerEvent event) {
          _hasHardwareEvents = true;
          _lastRawLatG = event.x / _gravityMs2;
          _lastRawLonG = event.z / _gravityMs2;

          final calibratedLat = (_lastRawLatG - _zeroOffsetLatG).clamp(-1.8, 1.8);
          final calibratedLon = (_lastRawLonG - _zeroOffsetLonG).clamp(-1.8, 1.8);

          _filteredLatG =
              _filteredLatG + _lowPassAlpha * (calibratedLat - _filteredLatG);
          _filteredLonG =
              _filteredLonG + _lowPassAlpha * (calibratedLon - _filteredLonG);

          final deadzoneLat = _filteredLatG.abs() < 0.02 ? 0.0 : _filteredLatG;
          final deadzoneLon = _filteredLonG.abs() < 0.02 ? 0.0 : _filteredLonG;

          _publishVectorState(
            latG: deadzoneLat,
            lonG: deadzoneLon,
            hardwareActive: true,
          );
        },
        onError: (_) {},
      );

      _gyroSub = gyroscopeEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (GyroscopeEvent event) {
          _lastYawDegSec = event.z * (180.0 / math.pi);
        },
        onError: (_) {},
      );
    } catch (_) {}

    // Solo sintetiza fuerzas G cuando el usuario activa el Modo Simulador (o en emulador sin acelerómetro)
    _simFallbackTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      final adapterState = ref.read(obdConnectionModeProvider);
      if (adapterState.mode != ObdConnectionMode.trackSimulator &&
          _hasHardwareEvents) {
        return;
      }

      final obdAsync = ref.read(obdTelemetryStreamProvider);
      final frame = obdAsync.valueOrNull;
      if (frame == null || !frame.isSimulator) return;

      final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final speedFactor = (frame.speedKmh / 180.0).clamp(0.15, 1.25);
      final simLatG =
          (math.sin(t * 0.95) * 1.12 * speedFactor).clamp(-1.45, 1.45);
      final simLonG =
          ((frame.throttleTps - 35.0) / 100.0 * 0.85).clamp(-1.25, 0.95);

      _publishVectorState(
        latG: simLatG,
        lonG: simLonG,
        hardwareActive: false,
      );
    });
  }

  /// Establece el punto cero (0.00 G, 0.00 G) en la lectura actual del acelerómetro
  Future<void> calibrateZeroAtCurrentReading() async {
    _zeroOffsetLatG = _lastRawLatG;
    _zeroOffsetLonG = _lastRawLonG;
    _filteredLatG = 0.0;
    _filteredLonG = 0.0;

    state = state.copyWith(
      lateralG: 0.0,
      longitudinalG: 0.0,
      peakG: 0.0,
      trailPoints: const [],
      isCalibrated: true,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefLatZeroKey, _zeroOffsetLatG);
      await prefs.setDouble(_prefLonZeroKey, _zeroOffsetLonG);
    } catch (_) {}
  }

  void _publishVectorState({
    required double latG,
    required double lonG,
    required bool hardwareActive,
  }) {
    final mag = math.sqrt((latG * latG) + (lonG * lonG));
    final nextPeak = mag > state.peakG ? mag : state.peakG;
    final updatedTrail = <({double x, double y})>[
      (x: latG, y: lonG),
      ...state.trailPoints.take(18),
    ];

    state = state.copyWith(
      lateralG: double.parse(latG.toStringAsFixed(2)),
      longitudinalG: double.parse(lonG.toStringAsFixed(2)),
      yawRateDegSec: double.parse(_lastYawDegSec.toStringAsFixed(1)),
      peakG: double.parse(nextPeak.toStringAsFixed(2)),
      trailPoints: updatedTrail,
      usingHardwareSensor: hardwareActive,
    );
  }

  void resetPeakG() {
    state = state.copyWith(peakG: 0.0, trailPoints: const []);
  }
}

final gForceSensorProvider =
    NotifierProvider<GForceSensorNotifier, GForceTelemetryState>(
  GForceSensorNotifier.new,
);
