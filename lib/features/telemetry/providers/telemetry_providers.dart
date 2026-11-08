import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/obd_telemetry_frame.dart';
import '../services/elm327_service.dart';

/// Enumeración para el switch en caliente en el Dashboard:
/// Simulador Físico de Circuito vs Adaptador Real ELM327 Bluetooth Classic.
enum ObdConnectionMode {
  trackSimulator,
  realElm327Bluetooth,
}

/// Estadísticas acumuladas de la sesión de telemetría ("Blackbox Live")
class TelemetrySessionStats {
  final double peakRpm;
  final int maxSpeedKmh;
  final double maxCoolantTempC;
  final double? bestZeroToHundredSec;
  final int totalSamples;

  const TelemetrySessionStats({
    this.peakRpm = 850.0,
    this.maxSpeedKmh = 0,
    this.maxCoolantTempC = 65.0,
    this.bestZeroToHundredSec,
    this.totalSamples = 0,
  });

  TelemetrySessionStats copyWith({
    double? peakRpm,
    int? maxSpeedKmh,
    double? maxCoolantTempC,
    double? bestZeroToHundredSec,
    int? totalSamples,
  }) {
    return TelemetrySessionStats(
      peakRpm: peakRpm ?? this.peakRpm,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      maxCoolantTempC: maxCoolantTempC ?? this.maxCoolantTempC,
      bestZeroToHundredSec: bestZeroToHundredSec ?? this.bestZeroToHundredSec,
      totalSamples: totalSamples ?? this.totalSamples,
    );
  }
}

/// Controlador Polimórfico en Riverpod que gestiona el origen de datos OBD-II
/// Cumplimiento estricto: Gestión 100% reactiva en Riverpod.
class ObdConnectionModeNotifier extends Notifier<ObdConnectionMode> {
  late final RealElm327BluetoothDataSource _realDataSource;
  late final Clio172TrackSimulatorDataSource _simulatorDataSource;

  @override
  ObdConnectionMode build() {
    _realDataSource = RealElm327BluetoothDataSource();
    _simulatorDataSource = Clio172TrackSimulatorDataSource();
    // Inicia por defecto en el Simulador de Pista para que funcione al instante en clase
    _simulatorDataSource.connect();
    ref.onDispose(() {
      _realDataSource.disconnect();
      _simulatorDataSource.disconnect();
    });
    return ObdConnectionMode.trackSimulator;
  }

  ObdDataSource get activeDataSource => state == ObdConnectionMode.trackSimulator
      ? _simulatorDataSource
      : _realDataSource;

  /// Intercambia en caliente entre el Simulador de Pista y el ELM327 Bluetooth Real
  Future<void> setConnectionMode(ObdConnectionMode nextMode, {String? macAddress}) async {
    if (state == nextMode) return;
    await activeDataSource.disconnect();
    state = nextMode;
    try {
      await activeDataSource.connect(macAddress: macAddress);
    } catch (_) {
      // Si el hardware Bluetooth no está emparejado en el aula, vuelve de forma segura al simulador
      state = ObdConnectionMode.trackSimulator;
      await _simulatorDataSource.connect();
    }
  }

  /// Alterna en vivo la temperatura del motor en el simulador (<75°C frío vs >=75°C caliente)
  void toggleSimulatorEngineWarmth() {
    _simulatorDataSource.toggleColdWarmEngineDemo();
  }
}

final obdConnectionModeProvider =
    NotifierProvider<ObdConnectionModeNotifier, ObdConnectionMode>(
  ObdConnectionModeNotifier.new,
);

/// StreamProvider reactivo con la trama actual de telemetría de la ECU Sirius 34
final obdTelemetryStreamProvider = StreamProvider<ObdTelemetryFrame>((ref) {
  final mode = ref.watch(obdConnectionModeProvider);
  final notifier = ref.read(obdConnectionModeProvider.notifier);
  final dataSource = notifier.activeDataSource;

  // Asegura conexión activa
  if (!dataSource.isConnected) {
    dataSource.connect();
  }

  return dataSource.telemetryStream.map((frame) {
    ref.read(telemetrySessionStatsProvider.notifier).recordFrame(frame);
    return frame.copyWith(isSimulator: mode == ObdConnectionMode.trackSimulator);
  });
});

/// StreamProvider de los logs crudos KWP2000 / ELM327 para inspección técnica
final obdTerminalLogsProvider = StreamProvider<List<String>>((ref) {
  ref.watch(obdConnectionModeProvider);
  final dataSource = ref.read(obdConnectionModeProvider.notifier).activeDataSource;
  return dataSource.rawTerminalLogStream;
});

/// Notifier para las estadísticas máximas de la sesión ("Blackbox Live") y 0-100 km/h
class TelemetrySessionStatsNotifier extends Notifier<TelemetrySessionStats> {
  DateTime? _sprintStartTimestamp;

  @override
  TelemetrySessionStats build() => const TelemetrySessionStats();

  void recordFrame(ObdTelemetryFrame frame) {
    // Cálculo automático del 0-100 km/h
    var bestSprint = state.bestZeroToHundredSec;
    if (frame.speedKmh <= 3 && frame.throttleTps > 40) {
      _sprintStartTimestamp = frame.timestamp;
    } else if (frame.speedKmh >= 100 && _sprintStartTimestamp != null) {
      final elapsedSec =
          frame.timestamp.difference(_sprintStartTimestamp!).inMilliseconds / 1000.0;
      if (elapsedSec > 3.5 && elapsedSec < 25.0) {
        if (bestSprint == null || elapsedSec < bestSprint) {
          bestSprint = double.parse(elapsedSec.toStringAsFixed(2));
        }
      }
      _sprintStartTimestamp = null;
    }

    state = state.copyWith(
      peakRpm: frame.rpm > state.peakRpm ? frame.rpm : state.peakRpm,
      maxSpeedKmh: frame.speedKmh > state.maxSpeedKmh ? frame.speedKmh : state.maxSpeedKmh,
      maxCoolantTempC: frame.coolantTempC > state.maxCoolantTempC
          ? frame.coolantTempC
          : state.maxCoolantTempC,
      bestZeroToHundredSec: bestSprint,
      totalSamples: state.totalSamples + 1,
    );
  }

  void resetSessionStats() {
    _sprintStartTimestamp = null;
    state = const TelemetrySessionStats();
  }
}

final telemetrySessionStatsProvider =
    NotifierProvider<TelemetrySessionStatsNotifier, TelemetrySessionStats>(
  TelemetrySessionStatsNotifier.new,
);

/// Notifier para diagnóstico de códigos de falla DTC (Modo 03 / Modo 04) en Sirius 34
class Sirius34DtcNotifier extends AsyncNotifier<List<Sirius34DtcFault>> {
  @override
  Future<List<Sirius34DtcFault>> build() async {
    ref.watch(obdConnectionModeProvider);
    final ds = ref.read(obdConnectionModeProvider.notifier).activeDataSource;
    return ds.readSirius34DtcCodes();
  }

  Future<void> scanDtcCodes() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final ds = ref.read(obdConnectionModeProvider.notifier).activeDataSource;
      return ds.readSirius34DtcCodes();
    });
  }

  Future<void> clearAllDtcCodes() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final ds = ref.read(obdConnectionModeProvider.notifier).activeDataSource;
      await ds.clearSirius34DtcCodes();
      return <Sirius34DtcFault>[];
    });
  }
}

final sirius34DtcProvider =
    AsyncNotifierProvider<Sirius34DtcNotifier, List<Sirius34DtcFault>>(
  Sirius34DtcNotifier.new,
);
