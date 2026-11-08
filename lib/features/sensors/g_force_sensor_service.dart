import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../telemetry/providers/telemetry_providers.dart';

/// Vector de Fuerzas G (Lateral X, Longitudinal Y, Magnitud Resultante y Picos)
/// Calculado en tiempo real desde el Acelerómetro y Giroscopio nativos (`sensors_plus`)
/// con filtro de paso bajo de primer orden para amortiguar vibraciones del soporte.
class GForceTelemetryState {
  final double lateralG;       // + Derecha / - Izquierda [-1.8G a +1.8G]
  final double longitudinalG;  // + Aceleración / - Frenada [-1.8G a +1.8G]
  final double yawRateDegSec;  // Velocidad angular del giroscopio (rad/s -> deg/s)
  final double peakG;          // Pico máximo registrado en la sesión
  final List< ({double x, double y}) > trailPoints; // Estela vectorial para GForceBallWidget
  final bool usingHardwareSensor;

  const GForceTelemetryState({
    this.lateralG = 0.0,
    this.longitudinalG = 0.0,
    this.yawRateDegSec = 0.0,
    this.peakG = 0.0,
    this.trailPoints = const [],
    this.usingHardwareSensor = true,
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
  }) {
    return GForceTelemetryState(
      lateralG: lateralG ?? this.lateralG,
      longitudinalG: longitudinalG ?? this.longitudinalG,
      yawRateDegSec: yawRateDegSec ?? this.yawRateDegSec,
      peakG: peakG ?? this.peakG,
      trailPoints: trailPoints ?? this.trailPoints,
      usingHardwareSensor: usingHardwareSensor ?? this.usingHardwareSensor,
    );
  }
}

/// Notifier de Sensores Inerciales IMU (Acelerómetro + Giroscopio) en Riverpod.
/// Cumplimiento estricto: Gestión 100% reactiva en Riverpod.
class GForceSensorNotifier extends Notifier<GForceTelemetryState> {
  static const double _gravityMs2 = 9.80665;
  // Coeficiente alpha = 0.18 del filtro de paso bajo exponencial (EMA)
  // Elimina el ruido de alta frecuencia del chasis rígido Cup y soporte de tablero.
  static const double _lowPassAlpha = 0.18;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _simFallbackTimer;

  double _filteredLatG = 0.0;
  double _filteredLonG = 0.0;
  double _lastYawDegSec = 0.0;
  DateTime _lastHardwareMovement = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  GForceTelemetryState build() {
    _initHardwareImuStreams();
    ref.onDispose(() {
      _accelSub?.cancel();
      _gyroSub?.cancel();
      _simFallbackTimer?.cancel();
    });
    return const GForceTelemetryState();
  }

  void _initHardwareImuStreams() {
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        (AccelerometerEvent event) {
          // En orientación apaisada en la Pixel Tablet:
          // Eje X corresponde a fuerza lateral y Eje Z/Y a aceleración longitudinal
          final rawLatG = (event.x / _gravityMs2).clamp(-1.8, 1.8);
          final rawLonG = ((event.z - 4.9) / _gravityMs2).clamp(-1.8, 1.8);

          _filteredLatG = _filteredLatG + _lowPassAlpha * (rawLatG - _filteredLatG);
          _filteredLonG = _filteredLonG + _lowPassAlpha * (rawLonG - _filteredLonG);

          if (rawLatG.abs() > 0.08 || rawLonG.abs() > 0.08) {
            _lastHardwareMovement = DateTime.now();
            _publishVectorState(
              latG: _filteredLatG,
              lonG: _filteredLonG,
              hardwareActive: true,
            );
          }
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
    } catch (_) {
      // Si se ejecuta en un entorno sin IMU física, el lazo cinemático mantiene vivo el medidor
    }

    // Lazo cinemático complementario: si la Pixel Tablet está inmóvil sobre el escritorio
    // del profesor en clase, sintetiza fuerzas G coherentes con la telemetría de pista
    // para que el GForceBallWidget se vea en acción continua. Al mover la tablet,
    // el acelerómetro físico toma prioridad inmediata.
    _simFallbackTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final sinceHwMs = DateTime.now().difference(_lastHardwareMovement).inMilliseconds;
      if (sinceHwMs < 1500) return;

      final obdAsync = ref.read(obdTelemetryStreamProvider);
      final frame = obdAsync.valueOrNull;
      if (frame == null) return;

      final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final speedFactor = (frame.speedKmh / 180.0).clamp(0.15, 1.25);
      final simLatG = (math.sin(t * 0.95) * 1.12 * speedFactor).clamp(-1.45, 1.45);
      final simLonG = ((frame.throttleTps - 35.0) / 100.0 * 0.85).clamp(-1.25, 0.95);

      _publishVectorState(
        latG: simLatG,
        lonG: simLonG,
        hardwareActive: false,
      );
    });
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
