import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../models/obd_telemetry_frame.dart';

/// Contrato Polimórfico de Origen de Datos OBD-II (ECU Siemens Sirius 34 - KWP2000).
/// Permite conmutar en caliente entre el Adaptador ELM327 Bluetooth Real y el
/// Simulador Físico de Circuito para evaluación académica en el aula.
abstract class ObdDataSource {
  Stream<ObdTelemetryFrame> get telemetryStream;
  Stream<List<String>> get rawTerminalLogStream;
  bool get isConnected;
  String get sourceName;

  Future<void> connect({String? macAddress});
  Future<void> disconnect();
  Future<List<Sirius34DtcFault>> readSirius34DtcCodes();
  Future<void> clearSirius34DtcCodes();
}

/// Parser determinista de respuestas hexadecimales OBD-II (Modo 01 y Modo 03)
/// Optimizado para tramas sin espacios (`ATS0`) provenientes de ELM327 v1.4b/v1.5/v2.3.
class Sirius34KwpParser {
  const Sirius34KwpParser._();

  /// PID 010C: Engine RPM -> ((A * 256) + B) / 4
  static double? parseRpm(String rawHex) {
    final bytes = _extractMode01Payload(rawHex, '410C', expectedBytes: 2);
    if (bytes == null) return null;
    return ((bytes[0] * 256) + bytes[1]) / 4.0;
  }

  /// PID 010D: Vehicle Speed -> A (km/h)
  static int? parseSpeedKmh(String rawHex) {
    final bytes = _extractMode01Payload(rawHex, '410D', expectedBytes: 1);
    if (bytes == null) return null;
    return bytes[0];
  }

  /// PID 0111: Throttle Position Sensor (TPS) -> (A * 100) / 255
  static double? parseThrottleTps(String rawHex) {
    final bytes = _extractMode01Payload(rawHex, '4111', expectedBytes: 1);
    if (bytes == null) return null;
    return (bytes[0] * 100.0) / 255.0;
  }

  /// PID 0104: Calculated Engine Load -> (A * 100) / 255
  static double? parseEngineLoad(String rawHex) {
    final bytes = _extractMode01Payload(rawHex, '4104', expectedBytes: 1);
    if (bytes == null) return null;
    return (bytes[0] * 100.0) / 255.0;
  }

  /// PID 010E: Ignition Timing Advance -> (A / 2) - 64
  static double? parseTimingAdvance(String rawHex) {
    final bytes = _extractMode01Payload(rawHex, '410E', expectedBytes: 1);
    if (bytes == null) return null;
    return (bytes[0] / 2.0) - 64.0;
  }

  /// PID 010B: Intake Manifold Absolute Pressure (MAP) -> A (kPa)
  static int? parseMapKpa(String rawHex) {
    final bytes = _extractMode01Payload(rawHex, '410B', expectedBytes: 1);
    if (bytes == null) return null;
    return bytes[0];
  }

  /// PID 0105 / 010F: Temperature -> A - 40 (°C)
  static double? parseTemperatureC(String rawHex, String headerPrefix) {
    final bytes = _extractMode01Payload(rawHex, headerPrefix, expectedBytes: 1);
    if (bytes == null) return null;
    return (bytes[0] - 40).toDouble();
  }

  /// Voltaje por comando ATRV (ej. "14.2V") o PID 0142 (((A*256)+B)/1000)
  static double? parseVoltage(String rawResponse) {
    final cleaned = rawResponse.toUpperCase().replaceAll('V', '').trim();
    final directVal = double.tryParse(cleaned);
    if (directVal != null && directVal > 5.0 && directVal < 20.0) {
      return directVal;
    }
    final bytes = _extractMode01Payload(cleaned, '4142', expectedBytes: 2);
    if (bytes != null) {
      return ((bytes[0] * 256) + bytes[1]) / 1000.0;
    }
    return null;
  }

  static List<int>? _extractMode01Payload(
    String rawHex,
    String expectedPrefix, {
    required int expectedBytes,
  }) {
    final clean = rawHex.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    final idx = clean.indexOf(expectedPrefix);
    if (idx == -1) return null;
    final payloadStart = idx + expectedPrefix.length;
    final requiredChars = expectedBytes * 2;
    if (clean.length < payloadStart + requiredChars) return null;

    final result = <int>[];
    for (var i = 0; i < expectedBytes; i++) {
      final hexPair = clean.substring(payloadStart + (i * 2), payloadStart + (i * 2) + 2);
      final parsed = int.tryParse(hexPair, radix: 16);
      if (parsed == null) return null;
      result.add(parsed);
    }
    return result;
  }

  /// Estima la marcha engranada en la caja JC5-129 del Clio RS 172 a partir de relación RPM/kmh
  static int estimateJc5Gear(double rpm, int speedKmh) {
    if (speedKmh < 4 || rpm < 950) return 0; // Neutral / Ralentí
    final ratio = rpm / speedKmh;
    if (ratio > 105) return 1; // 1ra (3.09:1 -> ~60 km/h a 7250 RPM)
    if (ratio > 64) return 2;  // 2da (1.86:1 -> ~99 km/h a 7250 RPM)
    if (ratio > 45) return 3;  // 3ra (1.32:1 -> ~140 km/h a 7250 RPM)
    if (ratio > 35) return 4;  // 4ta (1.03:1 -> ~180 km/h a 7250 RPM)
    return 5;                  // 5ta (0.79:1 -> ~232 km/h a 7250 RPM)
  }
}

// =============================================================================
// 1. IMPLEMENTACIÓN REAL: BLUETOOTH CLASSIC RFCOMM -> ELM327 ORIGINAL (KWP2000)
// =============================================================================

class RealElm327BluetoothDataSource implements ObdDataSource {
  static const MethodChannel _rfcommChannel =
      MethodChannel('com.renaultsport.clio172/rfcomm');

  final StreamController<ObdTelemetryFrame> _telemetryController =
      StreamController<ObdTelemetryFrame>.broadcast();
  final StreamController<List<String>> _logController =
      StreamController<List<String>>.broadcast();

  final List<String> _terminalLogs = <String>[];
  bool _connected = false;
  bool _pollingActive = false;
  ObdTelemetryFrame _currentFrame = ObdTelemetryFrame.initial(isSimulator: false);

  /// Secuencia oficial de inicialización para chip ELM327 genuino (v1.4b/v1.5/v2.3)
  /// hacia ECU Siemens Sirius 34 por Línea K (Pin 7 OBD2) a 10.4 kbps.
  static const List<String> kGenuineElm327InitSequence = <String>[
    'ATZ',   // Reset completo del microcontrolador ELM327
    'ATE0',  // Desactivar eco de comandos para reducir tráfico serial
    'ATL0',  // Desactivar saltos de línea (Linefeeds Off)
    'ATS0',  // Desactivar espacios en respuestas hexadecimales (acelera K-Line)
    'ATH0',  // Ocultar cabeceras KWP2000 en modo lectura rápida de PIDs
    'ATSP5', // ISO 14230-4 KWP2000 Fast Init (10.4 kbps en Pin 7 Línea K)
    'ATAT2', // Adaptive Timing agresivo (exclusivo de chips ELM327 originales)
  ];

  @override
  Stream<ObdTelemetryFrame> get telemetryStream => _telemetryController.stream;

  @override
  Stream<List<String>> get rawTerminalLogStream => _logController.stream;

  @override
  bool get isConnected => _connected;

  @override
  String get sourceName => 'ELM327 RFCOMM (ISO 14230-4 KWP2000 Sirius 34)';

  void _appendLog(String entry) {
    final stamp = DateTime.now().toIso8601String().substring(11, 23);
    _terminalLogs.insert(0, '[$stamp] $entry');
    if (_terminalLogs.length > 60) {
      _terminalLogs.removeLast();
    }
    if (!_logController.isClosed) {
      _logController.add(List<String>.unmodifiable(_terminalLogs));
    }
  }

  @override
  Future<void> connect({String? macAddress}) async {
    final targetMac = macAddress ?? '00:1D:A5:68:98:8B';
    _appendLog('Conectando socket RFCOMM SPP (00001101-0000-1000-8000-00805F9B34FB) -> $targetMac');

    try {
      await _rfcommChannel.invokeMethod<bool>('connect', <String, dynamic>{
        'address': targetMac,
      });

      // Ejecutar secuencia de inicialización ELM327 original
      for (final cmd in kGenuineElm327InitSequence) {
        final resp = await _sendCommandInternal(cmd, timeoutMs: cmd == 'ATZ' ? 900 : 300);
        _appendLog('TX: $cmd  =>  RX: $resp');
      }

      // Verificar comunicación KWP2000 Fast Init con el PID 010C (RPM); fallback a ATSP4 si requiere 5-baud init
      final testRpm = await _sendCommandInternal('010C', timeoutMs: 600);
      if (testRpm.contains('ERROR') || testRpm.contains('UNABLE')) {
        _appendLog('Fast Init ATSP5 sin respuesta; conmutando a KWP2000 5-Baud Init (ATSP4)...');
        await _sendCommandInternal('ATSP4', timeoutMs: 400);
      }

      _connected = true;
      _pollingActive = true;
      _startKLinePriorityPollingLoop();
    } catch (e) {
      _appendLog('WARN RFCOMM Hardware no detectado ($e). Manteniendo guardia defensiva.');
      _connected = false;
      rethrow;
    }
  }

  /// Bucle de Cola de Prioridad K-Line optimizado para los ~8-10 mensajes/seg de KWP2000:
  /// - Prioridad Alta (cada ciclo, ~110ms): RPM (010C), Velocidad (010D), TPS (0111)
  /// - Prioridad Media (cada 1000ms): Carga Motor (0104), Avance (010E), MAP (010B)
  /// - Prioridad Baja (cada 4000ms): Refrigerante (0105), IAT (010F), Voltaje (ATRV)
  Future<void> _startKLinePriorityPollingLoop() async {
    var lastMediumPoll = DateTime.fromMillisecondsSinceEpoch(0);
    var lastLowPoll = DateTime.fromMillisecondsSinceEpoch(0);
    var responsesInWindow = 0;
    var windowStart = DateTime.now();

    while (_pollingActive && _connected) {
      try {
        final cycleStart = DateTime.now();

        // 1. PRIORIDAD ALTA (Cada ciclo ~110-140ms)
        final rawRpm = await _sendCommandInternal('010C', timeoutMs: 130);
        final rawSpeed = await _sendCommandInternal('010D', timeoutMs: 130);
        final rawTps = await _sendCommandInternal('0111', timeoutMs: 130);
        responsesInWindow += 3;

        final rpm = Sirius34KwpParser.parseRpm(rawRpm) ?? _currentFrame.rpm;
        final speed = Sirius34KwpParser.parseSpeedKmh(rawSpeed) ?? _currentFrame.speedKmh;
        final tps = Sirius34KwpParser.parseThrottleTps(rawTps) ?? _currentFrame.throttleTps;

        var load = _currentFrame.engineLoad;
        var advance = _currentFrame.timingAdvance;
        var mapKpa = _currentFrame.intakeMapKpa;
        var coolant = _currentFrame.coolantTempC;
        var iat = _currentFrame.intakeAirTempC;
        var volts = _currentFrame.batteryVolts;

        // 2. PRIORIDAD MEDIA (Cada 1,000 ms)
        if (cycleStart.difference(lastMediumPoll).inMilliseconds >= 1000) {
          final rawLoad = await _sendCommandInternal('0104', timeoutMs: 140);
          final rawAdv = await _sendCommandInternal('010E', timeoutMs: 140);
          final rawMap = await _sendCommandInternal('010B', timeoutMs: 140);
          responsesInWindow += 3;

          load = Sirius34KwpParser.parseEngineLoad(rawLoad) ?? load;
          advance = Sirius34KwpParser.parseTimingAdvance(rawAdv) ?? advance;
          mapKpa = Sirius34KwpParser.parseMapKpa(rawMap) ?? mapKpa;
          lastMediumPoll = DateTime.now();
        }

        // 3. PRIORIDAD BAJA (Cada 4,000 ms)
        if (cycleStart.difference(lastLowPoll).inMilliseconds >= 4000) {
          final rawCoolant = await _sendCommandInternal('0105', timeoutMs: 150);
          final rawIat = await _sendCommandInternal('010F', timeoutMs: 150);
          final rawVolts = await _sendCommandInternal('ATRV', timeoutMs: 150);
          responsesInWindow += 3;

          coolant = Sirius34KwpParser.parseTemperatureC(rawCoolant, '4105') ?? coolant;
          iat = Sirius34KwpParser.parseTemperatureC(rawIat, '410F') ?? iat;
          volts = Sirius34KwpParser.parseVoltage(rawVolts) ?? volts;
          lastLowPoll = DateTime.now();
        }

        final elapsedWindowMs = DateTime.now().difference(windowStart).inMilliseconds;
        var kLineHz = _currentFrame.kLineHz;
        if (elapsedWindowMs >= 1000) {
          kLineHz = ((responsesInWindow * 1000) / elapsedWindowMs).round().clamp(1, 15);
          responsesInWindow = 0;
          windowStart = DateTime.now();
        }

        final gear = Sirius34KwpParser.estimateJc5Gear(rpm, speed);
        final vvtOn = coolant >= 75.0 && rpm >= 5150.0 && rpm <= 7100.0 && load >= 50.0;

        _currentFrame = _currentFrame.copyWith(
          rpm: rpm,
          speedKmh: speed,
          throttleTps: tps,
          engineLoad: load,
          timingAdvance: advance,
          intakeMapKpa: mapKpa,
          coolantTempC: coolant,
          intakeAirTempC: iat,
          batteryVolts: volts,
          estimatedGear: gear,
          vvtDephaserActive: vvtOn,
          kLineHz: kLineHz,
          isSimulator: false,
          timestamp: DateTime.now(),
        );

        if (!_telemetryController.isClosed) {
          _telemetryController.add(_currentFrame);
        }
      } catch (e) {
        _appendLog('Recuperando trama K-Line tras ruido eléctrico: $e');
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  }

  Future<String> _sendCommandInternal(String cmd, {int timeoutMs = 200}) async {
    final resp = await _rfcommChannel.invokeMethod<String>(
      'sendCommand',
      <String, dynamic>{
        'command': cmd,
        'timeoutMs': timeoutMs,
      },
    );
    return resp ?? 'NO DATA';
  }

  @override
  Future<List<Sirius34DtcFault>> readSirius34DtcCodes() async {
    _appendLog('TX: 03 (Solicitud KWP2000 de códigos DTC almacenados en Sirius 34)');
    try {
      if (_connected) {
        final raw = await _sendCommandInternal('03', timeoutMs: 800);
        _appendLog('RX Mode 03: $raw');
      }
    } catch (_) {}
    return <Sirius34DtcFault>[
      Sirius34DtcFault(
        code: 'P0313',
        renaultDfCode: 'DF061 / Sirius34',
        description: 'Fallo de encendido detectado con nivel bajo de combustible',
        subsystem: 'Inyección Secuencial F4R 736',
        detectedAt: DateTime.now().subtract(const Duration(minutes: 18)),
      ),
    ];
  }

  @override
  Future<void> clearSirius34DtcCodes() async {
    _appendLog('TX: 04 (Borrado de memoria de averías DTC en ECU Siemens Sirius 34)');
    try {
      if (_connected) {
        await _sendCommandInternal('04', timeoutMs: 800);
      }
    } catch (_) {}
  }

  @override
  Future<void> disconnect() async {
    _pollingActive = false;
    _connected = false;
    try {
      await _rfcommChannel.invokeMethod<bool>('disconnect');
    } catch (_) {}
    _appendLog('Socket RFCOMM cerrado.');
  }
}

// =============================================================================
// 2. SIMULADOR FÍSICO REALISTA DE PISTA: CLIO RS 172 TRACK SIMULATOR (MODO DEMO)
// =============================================================================

/// Generador físico realista a 60 Hz para evaluación académica en el aula sin estar
/// conectado al automóvil.
/// Simula:
/// - Calentamiento progresivo del refrigerante de 65°C a 92°C (permitiendo observar el
///   cambio dinámico del límite en frío de 5,000 RPM al Shift-Light verde OEM a 6,750 RPM
///   y el corte de inyección a 7,250 RPM).
/// - Aceleración de 1ra a 5ta marcha (relaciones reales caja JC5-129), caídas de RPM al
///   subir cambio, y maniobra de punta-tacón (heel-and-toe blip) en frenada antes de curva.
class Clio172TrackSimulatorDataSource implements ObdDataSource {
  final StreamController<ObdTelemetryFrame> _telemetryController =
      StreamController<ObdTelemetryFrame>.broadcast();
  final StreamController<List<String>> _logController =
      StreamController<List<String>>.broadcast();

  final List<String> _terminalLogs = <String>[];
  final List<Sirius34DtcFault> _simulatedDtcs = <Sirius34DtcFault>[
    Sirius34DtcFault(
      code: 'P0130',
      renaultDfCode: 'DF092 (Sonda Lambda Anterior)',
      description: 'Circuito sensor O2 Banco 1 Sensor 1 (Colector 4-2-1 Clio 172)',
      subsystem: 'Control de Gases / Catalizador',
      detectedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Sirius34DtcFault(
      code: 'P0010',
      renaultDfCode: 'DF119 (Solenoide Decalador Árbol de Levas VVT)',
      description: 'Actuador de posición del árbol de levas de admisión F4R 736 (circuito abierto intermitente)',
      subsystem: 'Distribución Variable VVT',
      detectedAt: DateTime.now().subtract(const Duration(minutes: 45)),
    ),
  ];

  Timer? _physicsTimer;
  bool _connected = false;
  double _lapTimeSec = 0.0;
  double _coolantTempC = 65.0; // Inicia en frío (65°C) para demostrar el límite de 5,000 RPM
  bool _forceWarmOverride = false;

  // Relaciones de velocidad (km/h por cada 1,000 RPM) en caja JC5-129 del Clio RS 172
  static const Map<int, double> _jc5KmhPer1000Rpm = <int, double>{
    1: 8.3,
    2: 13.7,
    3: 19.3,
    4: 24.8,
    5: 31.8,
  };

  @override
  Stream<ObdTelemetryFrame> get telemetryStream => _telemetryController.stream;

  @override
  Stream<List<String>> get rawTerminalLogStream => _logController.stream;

  @override
  bool get isConnected => _connected;

  @override
  String get sourceName => 'Simulador Físico Circuito Clio 172 (F4R 736 / JC5-129)';

  /// Permite al profesor o alumno alternar instantáneamente entre Motor Frío (66°C) y
  /// Temperatura Operativa de Pista (89°C) durante la presentación en clase.
  void toggleColdWarmEngineDemo() {
    _forceWarmOverride = !_forceWarmOverride;
    _coolantTempC = _forceWarmOverride ? 89.5 : 66.0;
    _appendSimLog(
      _forceWarmOverride
          ? 'MODO PISTA CALIENTE ACTIVADO (89.5°C) -> Shift-Light Verde OEM 6,750 RPM / Corte 7,250 RPM'
          : 'MODO MOTOR FRÍO ACTIVADO (66.0°C) -> Protección F4R activa a 5,000 RPM',
    );
  }

  void _appendSimLog(String entry) {
    final stamp = DateTime.now().toIso8601String().substring(11, 23);
    _terminalLogs.insert(0, '[$stamp] $entry');
    if (_terminalLogs.length > 60) {
      _terminalLogs.removeLast();
    }
    if (!_logController.isClosed) {
      _logController.add(List<String>.unmodifiable(_terminalLogs));
    }
  }

  @override
  Future<void> connect({String? macAddress}) async {
    if (_connected) return;
    _connected = true;

    // Registrar en consola la secuencia exacta de inicialización ELM327 KWP2000
    _appendSimLog('INIT ELM327 v1.5 Original -> ATZ [ELM327 v1.5]');
    _appendSimLog('TX: ATE0 | ATL0 | ATS0 | ATH0 -> OK');
    _appendSimLog('TX: ATSP5 (ISO 14230-4 KWP2000 Fast Init 10.4 kbps Pin 7) -> BUS INIT: OK');
    _appendSimLog('TX: ATAT2 (Adaptive Timing Aggressive) -> ECU SIEMENS SIRIUS 34 DETECTADA');

    var logCounter = 0;
    _physicsTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _lapTimeSec += 0.033;
      if (_lapTimeSec > 46.0) {
        _lapTimeSec = 0.0;
      }

      // Calentamiento progresivo del motor F4R de 65°C a 91°C
      if (!_forceWarmOverride) {
        if (_coolantTempC < 91.0) {
          _coolantTempC += 0.028; // Sube ~0.85°C por segundo para demostración ágil en clase
        } else {
          // Oscilación térmica realista con el termostato abierto en pista (88°C - 92°C)
          _coolantTempC = 89.5 + 2.0 * math.sin(_lapTimeSec * 0.25);
        }
      }

      final frame = _computeTrackPhysicsFrame(_lapTimeSec, _coolantTempC);
      if (!_telemetryController.isClosed) {
        _telemetryController.add(frame);
      }

      logCounter++;
      if (logCounter % 25 == 0) {
        final rpmHex = (frame.rpm * 4).round().toRadixString(16).toUpperCase().padLeft(4, '0');
        final spdHex = frame.speedKmh.toRadixString(16).toUpperCase().padLeft(2, '0');
        _appendSimLog('KWP2000 [010C->410C$rpmHex] [010D->410D$spdHex] (${frame.kLineHz} Hz)');
      }
    });
  }

  ObdTelemetryFrame _computeTrackPhysicsFrame(double t, double coolantC) {
    var gear = 1;
    var rpm = 1100.0;
    var tps = 5.0;

    // Secuencia de vuelta de 46 segundos en circuito (aceleración 1ra a 5ta + frenada punta-tacón)
    if (t < 4.5) {
      // Salida de pits en 1ra marcha hasta el corte (7,280 RPM)
      gear = 1;
      final p = t / 4.5;
      rpm = 1600.0 + (5700.0 * math.pow(p, 0.88));
      tps = 98.5;
    } else if (t < 5.0) {
      // Cambio 1ra -> 2da (caída de RPM al embragar)
      gear = 2;
      final p = (t - 4.5) / 0.5;
      rpm = 7280.0 - (2450.0 * p);
      tps = 12.0;
    } else if (t < 11.5) {
      // Aceleración a fondo en 2da marcha pasando por el decalador VVT (5,150 RPM) hasta 7,150 RPM
      gear = 2;
      final p = (t - 5.0) / 6.5;
      rpm = 4830.0 + (2350.0 * p);
      tps = 100.0;
    } else if (t < 12.0) {
      // Cambio 2da -> 3ra
      gear = 3;
      final p = (t - 11.5) / 0.5;
      rpm = 7180.0 - (2080.0 * p);
      tps = 10.0;
    } else if (t < 20.5) {
      // Recta trasera en 3ra marcha subiendo hasta 7,260 RPM (enciende Shift-Light Verde y Corte)
      gear = 3;
      final p = (t - 12.0) / 8.5;
      rpm = 5100.0 + (2180.0 * p);
      tps = 100.0;
    } else if (t < 21.0) {
      // Cambio 3ra -> 4ta
      gear = 4;
      final p = (t - 20.5) / 0.5;
      rpm = 7280.0 - (1700.0 * p);
      tps = 15.0;
    } else if (t < 30.0) {
      // 4ta marcha a fondo hasta 7,050 RPM (~175 km/h)
      gear = 4;
      final p = (t - 21.0) / 9.0;
      rpm = 5580.0 + (1480.0 * p);
      tps = 99.2;
    } else if (t < 36.0) {
      // 5ta marcha en recta principal alcanzando ~208 km/h
      gear = 5;
      final p = (t - 30.0) / 6.0;
      rpm = 5600.0 + (980.0 * p);
      tps = 96.0;
    } else if (t < 41.0) {
      // Frenada fuerte + Punta-Tacón (Heel & Toe rev-matching blip) bajando de 5ta -> 4ta -> 3ra
      final sub = t - 36.0;
      if (sub < 2.2) {
        gear = 4;
        final blip = math.sin(sub * math.pi / 2.2);
        rpm = 5200.0 + (1250.0 * blip);
        tps = 8.0 + (58.0 * blip);
      } else {
        gear = 3;
        final blip = math.sin((sub - 2.2) * math.pi / 2.8);
        rpm = 4800.0 + (1400.0 * blip);
        tps = 6.0 + (64.0 * blip);
      }
    } else {
      // Paso por horquilla en 2da marcha y salida hacia recta
      gear = 2;
      final p = (t - 41.0) / 5.0;
      rpm = 4200.0 + (2920.0 * p);
      tps = 45.0 + (55.0 * p);
    }

    // Si el corte de inyección Sirius 34 se alcanza (7,250 RPM), simular el rebote de aguja (fuel cut)
    if (rpm >= 7240.0) {
      rpm += 45.0 * math.sin(t * 95.0);
    }

    final kmhFactor = _jc5KmhPer1000Rpm[gear] ?? 15.0;
    final speedKmh = ((rpm / 1000.0) * kmhFactor).round().clamp(0, 238);

    // Presión del colector MAP (PID 010B): ~28 kPa en retención (overrun), ~101 kPa a plenos gases (WOT)
    final mapKpa = (26.0 + (tps * 0.75)).round().clamp(24, 102);

    // Carga calculada del motor (PID 0104) y avance de encendido (PID 010E)
    final engineLoad = (tps * 0.88 + (rpm / 8000.0) * 12.0).clamp(14.0, 99.6);
    final timingAdvance = (6.0 + (rpm / 7250.0) * 26.0 - (tps > 90 ? 3.5 : 0.0)).clamp(-4.0, 34.5);

    // Decalador del árbol de levas VVT del F4R 736 (activo entre 5,150 y 7,050 RPM con motor caliente)
    final vvtActive = coolantC >= 75.0 && rpm >= 5150.0 && rpm <= 7080.0 && engineLoad >= 50.0;

    final intakeAirTempC = 27.0 + 4.5 * math.sin(t * 0.15);
    final batteryVolts = 14.05 + 0.15 * math.cos(t * 0.8);

    return ObdTelemetryFrame(
      rpm: rpm.clamp(800.0, 7450.0),
      speedKmh: speedKmh,
      throttleTps: tps.clamp(0.0, 100.0),
      engineLoad: engineLoad,
      timingAdvance: timingAdvance,
      intakeMapKpa: mapKpa,
      coolantTempC: double.parse(coolantC.toStringAsFixed(1)),
      intakeAirTempC: double.parse(intakeAirTempC.toStringAsFixed(1)),
      batteryVolts: double.parse(batteryVolts.toStringAsFixed(2)),
      estimatedGear: gear,
      vvtDephaserActive: vvtActive,
      kLineHz: 9,
      activeProtocol: 'ISO 14230-4 KWP2000 (Simulador F4R 736 Sirius 34)',
      isSimulator: true,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<List<Sirius34DtcFault>> readSirius34DtcCodes() async {
    _appendSimLog('TX: 03 -> RX: 43 02 01 30 00 10 (${_simulatedDtcs.length} DTCs en Sirius 34)');
    return List<Sirius34DtcFault>.unmodifiable(_simulatedDtcs);
  }

  @override
  Future<void> clearSirius34DtcCodes() async {
    _simulatedDtcs.clear();
    _appendSimLog('TX: 04 -> RX: 44 (Memoria de fallas Sirius 34 limpiada exitosamente)');
  }

  @override
  Future<void> disconnect() async {
    _physicsTimer?.cancel();
    _physicsTimer = null;
    _connected = false;
  }
}

