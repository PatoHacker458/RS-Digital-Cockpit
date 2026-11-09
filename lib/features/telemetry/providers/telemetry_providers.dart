import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/obd_telemetry_frame.dart';
import '../services/elm327_service.dart';

enum ObdConnectionMode {
  realElm327Bluetooth,
  trackSimulator,
}

/// Dispositivo Bluetooth emparejado en Android (Adaptador OBD2 ELM327)
class PairedBluetoothObdDevice {
  final String name;
  final String macAddress;

  const PairedBluetoothObdDevice({
    required this.name,
    required this.macAddress,
  });

  bool get looksLikeObdAdapter {
    final upper = name.toUpperCase();
    return upper.contains('OBD') ||
        upper.contains('ELM') ||
        upper.contains('VLINK') ||
        upper.contains('KONNWEI') ||
        upper.contains('VEEPEAK');
  }
}

class ObdAdapterState {
  final ObdConnectionMode mode;
  final List<PairedBluetoothObdDevice> pairedDevices;
  final String? selectedMacAddress;
  final String? selectedDeviceName;
  final bool isConnecting;
  final bool isConnected;
  final String statusText;

  const ObdAdapterState({
    this.mode = ObdConnectionMode.realElm327Bluetooth,
    this.pairedDevices = const <PairedBluetoothObdDevice>[],
    this.selectedMacAddress,
    this.selectedDeviceName,
    this.isConnecting = false,
    this.isConnected = false,
    this.statusText = 'Selecciona tu adaptador OBD2 en ECU',
  });

  ObdAdapterState copyWith({
    ObdConnectionMode? mode,
    List<PairedBluetoothObdDevice>? pairedDevices,
    String? selectedMacAddress,
    String? selectedDeviceName,
    bool? isConnecting,
    bool? isConnected,
    String? statusText,
  }) {
    return ObdAdapterState(
      mode: mode ?? this.mode,
      pairedDevices: pairedDevices ?? this.pairedDevices,
      selectedMacAddress: selectedMacAddress ?? this.selectedMacAddress,
      selectedDeviceName: selectedDeviceName ?? this.selectedDeviceName,
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
      statusText: statusText ?? this.statusText,
    );
  }
}

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

/// Gestión reactiva del Adaptador OBD-II Bluetooth (ELM327) y telemetría KWP2000.
class ObdConnectionModeNotifier extends Notifier<ObdAdapterState> {
  static const MethodChannel _rfcommChannel =
      MethodChannel('com.renaultsport.clio172/rfcomm');
  static const MethodChannel _launcherChannel =
      MethodChannel('com.renaultsport.clio172/launcher');
  static const String _savedMacKey = 'rs_obd_saved_mac';
  static const String _savedNameKey = 'rs_obd_saved_name';

  late final RealElm327BluetoothDataSource _realDataSource;
  late final Clio172TrackSimulatorDataSource _simulatorDataSource;

  @override
  ObdAdapterState build() {
    _realDataSource = RealElm327BluetoothDataSource();
    _simulatorDataSource = Clio172TrackSimulatorDataSource();

    ref.onDispose(() {
      _realDataSource.disconnect();
      _simulatorDataSource.disconnect();
    });

    _loadSavedAdapterAndScan();
    return const ObdAdapterState();
  }

  ObdDataSource get activeDataSource =>
      state.mode == ObdConnectionMode.trackSimulator
          ? _simulatorDataSource
          : _realDataSource;

  Future<void> _loadSavedAdapterAndScan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMac = prefs.getString(_savedMacKey);
      final savedName = prefs.getString(_savedNameKey);
      if (savedMac != null) {
        state = state.copyWith(
          selectedMacAddress: savedMac,
          selectedDeviceName: savedName ?? 'ELM327 OBD-II',
        );
      }
      await scanPairedBluetoothDevices();
      if (savedMac != null) {
        await connectToBluetoothAdapter(
          macAddress: savedMac,
          deviceName: savedName ?? 'ELM327 OBD-II',
        );
      }
    } catch (_) {}
  }

  /// Obtiene la lista de adaptadores Bluetooth vinculados en Android
  Future<void> scanPairedBluetoothDevices() async {
    try {
      final rawList =
          await _rfcommChannel.invokeMethod<List<dynamic>>('getPairedDevices');
      if (rawList == null) return;

      final devices = rawList.map((item) {
        final map = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
        return PairedBluetoothObdDevice(
          name: (map['name'] as String?) ?? 'Dispositivo Bluetooth',
          macAddress: (map['address'] as String?) ?? '',
        );
      }).where((d) => d.macAddress.isNotEmpty).toList();

      // Ordenar poniendo primero los que contienen OBD / ELM327 en el nombre
      devices.sort((a, b) {
        if (a.looksLikeObdAdapter && !b.looksLikeObdAdapter) return -1;
        if (!a.looksLikeObdAdapter && b.looksLikeObdAdapter) return 1;
        return a.name.compareTo(b.name);
      });

      state = state.copyWith(
        pairedDevices: devices,
        statusText: devices.isEmpty
            ? 'Vincula tu ELM327 en Ajustes Bluetooth'
            : '${devices.length} dispositivos Bluetooth detectados',
      );
    } catch (_) {
      state = state.copyWith(
        statusText: 'Activa el permiso de Bluetooth para buscar adaptadores',
      );
    }
  }

  /// Abre los Ajustes nativos de Bluetooth de Android para vincular un nuevo ELM327
  Future<void> openSystemBluetoothSettings() async {
    try {
      await _launcherChannel.invokeMethod<bool>('openBluetoothSettings');
    } catch (_) {}
  }

  /// Conecta por socket RFCOMM a un adaptador OBD-II seleccionado por el usuario
  Future<void> connectToBluetoothAdapter({
    required String macAddress,
    required String deviceName,
  }) async {
    await _simulatorDataSource.disconnect();
    state = state.copyWith(
      mode: ObdConnectionMode.realElm327Bluetooth,
      selectedMacAddress: macAddress,
      selectedDeviceName: deviceName,
      isConnecting: true,
      isConnected: false,
      statusText: 'Conectando a $deviceName ($macAddress)...',
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedMacKey, macAddress);
      await prefs.setString(_savedNameKey, deviceName);

      await _realDataSource.connect(macAddress: macAddress);
      state = state.copyWith(
        isConnecting: false,
        isConnected: true,
        statusText: 'Conectado a $deviceName (KWP2000 10.4 kbps)',
      );
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
        statusText: 'No se pudo conectar a $deviceName. Verifica que el auto esté en contacto.',
      );
    }
  }

  /// Permite activar o desactivar manualmente el Simulador cuando no se está en el auto
  Future<void> setConnectionMode(ObdConnectionMode nextMode) async {
    if (nextMode == ObdConnectionMode.trackSimulator) {
      await _realDataSource.disconnect();
      await _simulatorDataSource.connect();
      state = state.copyWith(
        mode: ObdConnectionMode.trackSimulator,
        isConnecting: false,
        isConnected: true,
        statusText: 'Simulador F4R Activo',
      );
    } else {
      await _simulatorDataSource.disconnect();
      state = state.copyWith(
        mode: ObdConnectionMode.realElm327Bluetooth,
        isConnecting: false,
        isConnected: _realDataSource.isConnected,
        statusText: state.selectedDeviceName != null
            ? 'Listo para conectar a ${state.selectedDeviceName}'
            : 'Selecciona tu adaptador OBD2 en la pestaña ECU',
      );
      if (state.selectedMacAddress != null) {
        await connectToBluetoothAdapter(
          macAddress: state.selectedMacAddress!,
          deviceName: state.selectedDeviceName ?? 'ELM327',
        );
      }
    }
  }

  void toggleSimulatorEngineWarmth() {
    _simulatorDataSource.toggleColdWarmEngineDemo();
  }
}

final obdConnectionModeProvider =
    NotifierProvider<ObdConnectionModeNotifier, ObdAdapterState>(
  ObdConnectionModeNotifier.new,
);

final obdTelemetryStreamProvider =
    StreamProvider<ObdTelemetryFrame>((ref) async* {
  final mode = ref.watch(obdConnectionModeProvider.select((s) => s.mode));
  ref.watch(obdConnectionModeProvider.select((s) => s.isConnected));
  final notifier = ref.read(obdConnectionModeProvider.notifier);
  final dataSource = notifier.activeDataSource;

  if (mode == ObdConnectionMode.trackSimulator && !dataSource.isConnected) {
    await dataSource.connect();
  }

  // Emitir el último cuadro conocido inmediatamente para evitar esperas en la UI
  yield dataSource.currentFrame.copyWith(
    isSimulator: mode == ObdConnectionMode.trackSimulator,
  );

  await for (final frame in dataSource.telemetryStream) {
    ref.read(telemetrySessionStatsProvider.notifier).recordFrame(frame);
    yield frame.copyWith(
      isSimulator: mode == ObdConnectionMode.trackSimulator,
    );
  }
});

final obdTerminalLogsProvider = StreamProvider<List<String>>((ref) async* {
  ref.watch(obdConnectionModeProvider.select((s) => s.mode));
  ref.watch(obdConnectionModeProvider.select((s) => s.isConnected));
  final dataSource =
      ref.read(obdConnectionModeProvider.notifier).activeDataSource;
  yield dataSource.currentLogs;
  yield* dataSource.rawTerminalLogStream;
});

class TelemetrySessionStatsNotifier extends Notifier<TelemetrySessionStats> {
  DateTime? _sprintStartTimestamp;

  @override
  TelemetrySessionStats build() => const TelemetrySessionStats();

  void recordFrame(ObdTelemetryFrame frame) {
    var bestSprint = state.bestZeroToHundredSec;
    if (frame.speedKmh <= 3 && frame.throttleTps > 40) {
      _sprintStartTimestamp = frame.timestamp;
    } else if (frame.speedKmh >= 100 && _sprintStartTimestamp != null) {
      final elapsedSec =
          frame.timestamp.difference(_sprintStartTimestamp!).inMilliseconds /
              1000.0;
      if (elapsedSec > 3.5 && elapsedSec < 25.0) {
        if (bestSprint == null || elapsedSec < bestSprint) {
          bestSprint = double.parse(elapsedSec.toStringAsFixed(2));
        }
      }
      _sprintStartTimestamp = null;
    }

    state = state.copyWith(
      peakRpm: frame.rpm > state.peakRpm ? frame.rpm : state.peakRpm,
      maxSpeedKmh:
          frame.speedKmh > state.maxSpeedKmh ? frame.speedKmh : state.maxSpeedKmh,
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

class Sirius34DtcNotifier extends AsyncNotifier<List<Sirius34DtcFault>> {
  @override
  Future<List<Sirius34DtcFault>> build() async {
    final mode = ref.watch(obdConnectionModeProvider.select((s) => s.mode));
    if (mode == ObdConnectionMode.trackSimulator) {
      final ds = ref.read(obdConnectionModeProvider.notifier).activeDataSource;
      return ds.readSirius34DtcCodes();
    }
    return const <Sirius34DtcFault>[];
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
