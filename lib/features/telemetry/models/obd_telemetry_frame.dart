/// Estado del testigo de cambio (Shift-Light OEM Sagem + Barra LED F1)
enum ShiftLightStage {
  off,
  coldProtectionWarning, // < 75°C y RPM >= 5,000 (Zona Amarilla de protección mecánica F4R)
  optimalGreenShift,     // >= 75°C y RPM >= 6,750 (Testigo Verde OEM Palanca de Cambios)
  fuelCutLimiterFlash,   // >= 75°C y RPM >= 7,250 (Corte de inyección Sirius 34 - Parpadeo Rojo/Azul)
}

/// Código de Falla (DTC) diagnosticado en la ECU Siemens Sirius 34 (Modo 03 / KWP2000)
class Sirius34DtcFault {
  final String code;
  final String renaultDfCode;
  final String description;
  final String subsystem;
  final DateTime detectedAt;

  const Sirius34DtcFault({
    required this.code,
    required this.renaultDfCode,
    required this.description,
    required this.subsystem,
    required this.detectedAt,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'renaultDfCode': renaultDfCode,
        'description': description,
        'subsystem': subsystem,
        'detectedAt': detectedAt.toIso8601String(),
      };
}

/// Trama inmutable de telemetría en tiempo real del Renault Clio RS 172 (F4R 736)
class ObdTelemetryFrame {
  /// Prioridad Alta (~100-150 ms)
  final double rpm;          // PID 010C: ((A*256)+B)/4  [0 - 8000 RPM]
  final int speedKmh;        // PID 010D: A              [0 - 255 km/h]
  final double throttleTps;  // PID 0111: (A*100)/255    [0.0 - 100.0 %]

  /// Prioridad Media (~1000 ms)
  final double engineLoad;   // PID 0104: (A*100)/255    [0.0 - 100.0 %]
  final double timingAdvance;// PID 010E: (A/2)-64       [-64.0 a +63.5 deg]
  final int intakeMapKpa;    // PID 010B: A              [10 - 105 kPa]

  /// Prioridad Baja (~4000 ms)
  final double coolantTempC; // PID 0105: A-40           [-40 a 130 °C]
  final double intakeAirTempC;// PID 010F: A-40          [-40 a 100 °C]
  final double batteryVolts; // PID 0142 / ATRV          [11.0 a 15.0 V]

  /// Estado mecánico calculado específico del motor F4R 736 y caja JC5 129
  final int estimatedGear;   // 0=N, 1..5 (Relaciones caja JC5-129 del Clio 172)
  final bool vvtDephaserActive; // Solenoide decalador árbol de levas (>5150 RPM, temp>=75°C, carga>50%)
  final int kLineHz;         // Tasa de refresco real alcanzada en la Línea K (10.4 kbps)
  final String activeProtocol; // ISO 14230-4 KWP (fast init, 10.4 kbaud)
  final bool isSimulator;
  final DateTime timestamp;

  const ObdTelemetryFrame({
    required this.rpm,
    required this.speedKmh,
    required this.throttleTps,
    required this.engineLoad,
    required this.timingAdvance,
    required this.intakeMapKpa,
    required this.coolantTempC,
    required this.intakeAirTempC,
    required this.batteryVolts,
    required this.estimatedGear,
    required this.vvtDephaserActive,
    required this.kLineHz,
    required this.activeProtocol,
    required this.isSimulator,
    required this.timestamp,
  });

  factory ObdTelemetryFrame.initial({bool isSimulator = true}) {
    if (!isSimulator) {
      return ObdTelemetryFrame(
        rpm: 0.0,
        speedKmh: 0,
        throttleTps: 0.0,
        engineLoad: 0.0,
        timingAdvance: 0.0,
        intakeMapKpa: 0,
        coolantTempC: 0.0,
        intakeAirTempC: 0.0,
        batteryVolts: 0.0,
        estimatedGear: 0,
        vvtDephaserActive: false,
        kLineHz: 0,
        activeProtocol: 'ISO 14230-4 KWP2000',
        isSimulator: false,
        timestamp: DateTime.now(),
      );
    }
    return ObdTelemetryFrame(
      rpm: 850.0,
      speedKmh: 0,
      throttleTps: 4.2,
      engineLoad: 18.5,
      timingAdvance: 8.5,
      intakeMapKpa: 34,
      coolantTempC: 66.0,
      intakeAirTempC: 24.0,
      batteryVolts: 14.1,
      estimatedGear: 0,
      vvtDephaserActive: false,
      kLineHz: 8,
      activeProtocol: 'ISO 14230-4 KWP2000 (Fast Init 10.4 kbps)',
      isSimulator: true,
      timestamp: DateTime.now(),
    );
  }

  /// Indica si el motor F4R 736 aún se encuentra en mapa de protección en frío (< 75°C)
  bool get isEngineCold => coolantTempC < 75.0;

  /// Límite recomendado dinámico de RPM según temperatura del refrigerante (`0105`)
  double get dynamicRedlineRpm => isEngineCold ? 5000.0 : 6750.0;

  /// Corte de inyección de la ECU Siemens Sirius 34
  double get fuelCutRpm => isEngineCold ? 5800.0 : 7250.0;

  /// Lógica fiel al Clio RS 172 Fase 2:
  /// - Si < 75°C: alerta amarilla de protección en frío a las 5,000 RPM.
  /// - Si >= 75°C: testigo verde OEM (palanca de cambios) a las 6,750 RPM y
  ///   parpadeo rojo de corte de inyección a las 7,250 RPM.
  ShiftLightStage get shiftLightStage {
    if (isEngineCold) {
      if (rpm >= 5000.0) {
        return ShiftLightStage.coldProtectionWarning;
      }
      return ShiftLightStage.off;
    } else {
      if (rpm >= 7250.0) {
        return ShiftLightStage.fuelCutLimiterFlash;
      }
      if (rpm >= 6750.0) {
        return ShiftLightStage.optimalGreenShift;
      }
      return ShiftLightStage.off;
    }
  }

  ObdTelemetryFrame copyWith({
    double? rpm,
    int? speedKmh,
    double? throttleTps,
    double? engineLoad,
    double? timingAdvance,
    int? intakeMapKpa,
    double? coolantTempC,
    double? intakeAirTempC,
    double? batteryVolts,
    int? estimatedGear,
    bool? vvtDephaserActive,
    int? kLineHz,
    String? activeProtocol,
    bool? isSimulator,
    DateTime? timestamp,
  }) {
    return ObdTelemetryFrame(
      rpm: rpm ?? this.rpm,
      speedKmh: speedKmh ?? this.speedKmh,
      throttleTps: throttleTps ?? this.throttleTps,
      engineLoad: engineLoad ?? this.engineLoad,
      timingAdvance: timingAdvance ?? this.timingAdvance,
      intakeMapKpa: intakeMapKpa ?? this.intakeMapKpa,
      coolantTempC: coolantTempC ?? this.coolantTempC,
      intakeAirTempC: intakeAirTempC ?? this.intakeAirTempC,
      batteryVolts: batteryVolts ?? this.batteryVolts,
      estimatedGear: estimatedGear ?? this.estimatedGear,
      vvtDephaserActive: vvtDephaserActive ?? this.vvtDephaserActive,
      kLineHz: kLineHz ?? this.kLineHz,
      activeProtocol: activeProtocol ?? this.activeProtocol,
      isSimulator: isSimulator ?? this.isSimulator,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

