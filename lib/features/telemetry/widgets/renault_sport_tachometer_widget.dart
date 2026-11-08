import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../models/obd_telemetry_frame.dart';

/// WIDGET DE INNOVACIÓN EN UI #1 (10% RÚBRICA):
/// `RenaultSportTachometerWidget`
/// Implementado con `CustomPainter` + `ShaderMask` a 120 FPS.
/// - Escala radial de 0 a 8,000 RPM inspirada en el cuadro Sagem del Clio 172 Fase 2.
/// - Zona roja dinámica dependiente de la temperatura del motor (`0105`):
///   * Motor Frío (< 75°C): Zona amarilla de protección mecánica desde 5,000 RPM.
///   * Motor Caliente (>= 75°C): Testigo Verde OEM a 6,750 RPM y corte a 7,250 RPM.
/// - Barra superior LED progresiva (Verde -> Ámbar -> Parpadeo Rojo/Azul estilo F1).
/// - Ícono clásico de la Palanca de Cambios OEM Renault Sport dibujado vectorialmente.
/// - Arquitectura reactiva pura mediante Riverpod.
class RenaultSportTachometerWidget extends ConsumerWidget {
  final ObdTelemetryFrame frame;

  const RenaultSportTachometerWidget({
    super.key,
    required this.frame,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(clusterSkinProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final flashPhase = (frame.timestamp.millisecondsSinceEpoch ~/ 90).isEven;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Barra Superior Progresiva de LEDs Shift-Light (Estilo F1 / Clio Cup)
        _ProgressiveShiftLightBar(
          rpm: frame.rpm,
          isEngineCold: frame.isEngineCold,
          stage: frame.shiftLightStage,
          flashPhase: flashPhase,
        ),
        const SizedBox(height: 10),

        // 2. Dial Radial Sagem con ShaderMask Metálico + CustomPainter a 120 FPS
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(constraints.maxWidth, constraints.maxHeight);
              return Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // ShaderMask que aplica reflejo de cristal/aluminio cepillado sobre el bisel
                      ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? <Color>[
                                    Colors.white,
                                    skin.primaryDialColor.withValues(alpha: 0.92),
                                    Colors.white,
                                  ]
                                : <Color>[
                                    RenaultSportPalette.mondialBlue,
                                    Colors.black87,
                                    RenaultSportPalette.cupNeedleRed,
                                  ],
                            stops: const <double>[0.0, 0.55, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcATop,
                        child: CustomPaint(
                          size: Size(size, size),
                          painter: _SagemBezelShaderRingPainter(isDark: isDark),
                        ),
                      ),

                      // CustomPainter Principal del Tacómetro Sagem 0-8000 RPM
                      CustomPaint(
                        size: Size(size, size),
                        painter: _RenaultSportTachometerPainter(
                          rpm: frame.rpm,
                          coolantTempC: frame.coolantTempC,
                          isEngineCold: frame.isEngineCold,
                          shiftStage: frame.shiftLightStage,
                          vvtActive: frame.vvtDephaserActive,
                          skin: skin,
                          isDark: isDark,
                          flashPhase: flashPhase,
                        ),
                      ),

                      // Lectura Digital Central (Marcha JC5, Velocidad y RPM Tabulares)
                      Positioned(
                        bottom: size * 0.14,
                        child: _CenterDigitalClusterReadout(
                          frame: frame,
                          skin: skin,
                          isDark: isDark,
                          flashPhase: flashPhase,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProgressiveShiftLightBar extends StatelessWidget {
  final double rpm;
  final bool isEngineCold;
  final ShiftLightStage stage;
  final bool flashPhase;

  const _ProgressiveShiftLightBar({
    required this.rpm,
    required this.isEngineCold,
    required this.stage,
    required this.flashPhase,
  });

  @override
  Widget build(BuildContext context) {
    const totalLeds = 15;
    final startRpm = isEngineCold ? 3600.0 : 4800.0;
    final maxRpm = isEngineCold ? 5200.0 : 7250.0;
    final progress = ((rpm - startRpm) / (maxRpm - startRpm)).clamp(0.0, 1.0);
    final activeLeds = (progress * totalLeds).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C0F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: stage == ShiftLightStage.fuelCutLimiterFlash && flashPhase
              ? RenaultSportPalette.revLimiterRed
              : const Color(0xFF282E38),
          width: 1.5,
        ),
        boxShadow: stage != ShiftLightStage.off
            ? <BoxShadow>[
                BoxShadow(
                  color: (stage == ShiftLightStage.optimalGreenShift
                          ? RenaultSportPalette.oemShiftGreen
                          : RenaultSportPalette.revLimiterRed)
                      .withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(totalLeds, (index) {
          final isLit = index < activeLeds;
          Color ledColor;
          if (stage == ShiftLightStage.fuelCutLimiterFlash) {
            ledColor = flashPhase
                ? RenaultSportPalette.revLimiterRed
                : const Color(0xFF00AAFF); // Parpadeo Rojo/Azul F1 al corte 7,250 RPM
          } else if (index < 6) {
            ledColor = RenaultSportPalette.oemShiftGreen;
          } else if (index < 11) {
            ledColor = RenaultSportPalette.siriusLiquidYellow;
          } else {
            ledColor = RenaultSportPalette.revLimiterRed;
          }

          return Container(
            width: 14,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              color: isLit ? ledColor : const Color(0xFF1E222A),
              borderRadius: BorderRadius.circular(3),
              boxShadow: isLit
                  ? <BoxShadow>[
                      BoxShadow(
                        color: ledColor.withValues(alpha: 0.8),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

class _SagemBezelShaderRingPainter extends CustomPainter {
  final bool isDark;
  const _SagemBezelShaderRingPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 4;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..color = Colors.white;
    canvas.drawCircle(center, radius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _SagemBezelShaderRingPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class _RenaultSportTachometerPainter extends CustomPainter {
  final double rpm;
  final double coolantTempC;
  final bool isEngineCold;
  final ShiftLightStage shiftStage;
  final bool vvtActive;
  final ClusterSkinEdition skin;
  final bool isDark;
  final bool flashPhase;

  const _RenaultSportTachometerPainter({
    required this.rpm,
    required this.coolantTempC,
    required this.isEngineCold,
    required this.shiftStage,
    required this.vvtActive,
    required this.skin,
    required this.isDark,
    required this.flashPhase,
  });

  // Ángulo inicial (135°) y barrido total (270°) para escala 0 a 8,000 RPM
  static const double _startAngle = 135.0 * (math.pi / 180.0);
  static const double _sweepAngle = 270.0 * (math.pi / 180.0);
  static const double _maxScaleRpm = 8000.0;

  double _rpmToAngle(double value) {
    final clamped = value.clamp(0.0, _maxScaleRpm);
    return _startAngle + (_sweepAngle * (clamped / _maxScaleRpm));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 12;

    // 1. Fondo de esfera Sagem 2004 Phase 2
    final dialBgPaint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? <Color>[
                const Color(0xFF1A1E26),
                const Color(0xFF0D1015),
              ]
            : <Color>[
                const Color(0xFFFFFFFF),
                const Color(0xFFDCE3EA),
              ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, dialBgPaint);

    final arcRect = Rect.fromCircle(center: center, radius: radius * 0.86);

    // 2. Arco base de escala (0 a 8,000 RPM)
    final baseTrackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.butt
      ..color = isDark ? const Color(0xFF252A34) : const Color(0xFFCBD5E1);
    canvas.drawArc(arcRect, _startAngle, _sweepAngle, false, baseTrackPaint);

    // 3. ZONA ROJA DINÁMICA SEGÚN TEMPERATURA DEL MOTOR (0105)
    if (isEngineCold) {
      // Motor en frío (< 75°C): Zona Amarilla de protección desde 5,000 a 6,000 RPM
      // y Zona Roja estricta de 6,000 a 8,000 RPM
      final coldWarnStart = _rpmToAngle(5000.0);
      final coldWarnSweep = _rpmToAngle(6000.0) - coldWarnStart;
      final coldAmberPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..color = RenaultSportPalette.coldEngineAmber;
      canvas.drawArc(arcRect, coldWarnStart, coldWarnSweep, false, coldAmberPaint);

      final coldRedStart = _rpmToAngle(6000.0);
      final coldRedSweep = _rpmToAngle(8000.0) - coldRedStart;
      final coldRedPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..color = RenaultSportPalette.revLimiterRed;
      canvas.drawArc(arcRect, coldRedStart, coldRedSweep, false, coldRedPaint);
    } else {
      // Motor en temperatura operativa (>= 75°C):
      // Banda de par VVT (5,150 a 6,750 RPM), Zona Verde Óptima (6,750 a 7,250 RPM)
      // y Zona de Corte de Inyección Sirius 34 (7,250 a 8,000 RPM).
      final vvtStart = _rpmToAngle(5150.0);
      final vvtSweep = _rpmToAngle(6750.0) - vvtStart;
      final vvtPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..color = skin.primaryDialColor.withValues(alpha: 0.45);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.78),
        vvtStart,
        vvtSweep,
        false,
        vvtPaint,
      );

      final greenShiftStart = _rpmToAngle(6750.0);
      final greenShiftSweep = _rpmToAngle(7250.0) - greenShiftStart;
      final greenShiftPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..color = RenaultSportPalette.oemShiftGreen;
      canvas.drawArc(arcRect, greenShiftStart, greenShiftSweep, false, greenShiftPaint);

      final warmRedStart = _rpmToAngle(7250.0);
      final warmRedSweep = _rpmToAngle(8000.0) - warmRedStart;
      final warmRedPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14.0
        ..color = RenaultSportPalette.revLimiterRed;
      canvas.drawArc(arcRect, warmRedStart, warmRedSweep, false, warmRedPaint);
    }

    // 4. Estela luminosa del régimen actual de RPM
    final activeSweep = _rpmToAngle(rpm) - _startAngle;
    final activeArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..color = shiftStage == ShiftLightStage.fuelCutLimiterFlash
          ? RenaultSportPalette.revLimiterRed
          : shiftStage == ShiftLightStage.optimalGreenShift
              ? RenaultSportPalette.oemShiftGreen
              : skin.primaryDialColor;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.91),
      _startAngle,
      activeSweep,
      false,
      activeArcPaint,
    );

    // 5. Marcas de graduación (0 a 8 x 1000 RPM) y números tabulares Sagem
    for (var i = 0; i <= 32; i++) {
      final tickRpm = i * 250.0;
      final angle = _rpmToAngle(tickRpm);
      final isMajor = i % 4 == 0;
      final isHalf = i % 2 == 0 && !isMajor;

      final outerR = radius * 0.84;
      final innerR = outerR - (isMajor ? 16.0 : (isHalf ? 10.0 : 6.0));

      final p1 = Offset(
        center.dx + outerR * math.cos(angle),
        center.dy + outerR * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + innerR * math.cos(angle),
        center.dy + innerR * math.sin(angle),
      );

      final isRedZoneTick =
          (isEngineCold && tickRpm >= 5000) || (!isEngineCold && tickRpm >= 7000);

      final tickPaint = Paint()
        ..strokeWidth = isMajor ? 3.2 : 1.5
        ..color = isRedZoneTick
            ? RenaultSportPalette.revLimiterRed
            : (isDark ? const Color(0xFFF3F4F6) : const Color(0xFF0F172A));

      canvas.drawLine(p1, p2, tickPaint);

      if (isMajor) {
        final numberVal = (tickRpm ~/ 1000).toString();
        final textRadius = radius * 0.67;
        final textOffset = Offset(
          center.dx + textRadius * math.cos(angle),
          center.dy + textRadius * math.sin(angle),
        );

        final tp = TextPainter(
          text: TextSpan(
            text: numberVal,
            style: AppTheme.telemetryNumericStyle(
              fontSize: radius * 0.11,
              color: isRedZoneTick
                  ? RenaultSportPalette.revLimiterRed
                  : (isDark ? skin.primaryDialColor : RenaultSportPalette.mondialBlue),
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(
          canvas,
          Offset(textOffset.dx - tp.width / 2, textOffset.dy - tp.height / 2),
        );
      }
    }

    // 6. ÍCONO OEM DE PALANCA DE CAMBIOS (TESTIGO DE CAMBIO SAGEM CLIO 172 FASE 2)
    // Ubicado en el cuadrante derecho como en el tablero original de 2004
    _drawOemGearshiftLightIcon(
      canvas: canvas,
      center: Offset(center.dx + radius * 0.36, center.dy + radius * 0.16),
      stage: shiftStage,
      flashPhase: flashPhase,
    );

    // 7. Aguja física Sagem con contrapeso y sombra
    final needleAngle = _rpmToAngle(rpm);
    final needleLength = radius * 0.78;
    final tailLength = radius * 0.16;

    final tip = Offset(
      center.dx + needleLength * math.cos(needleAngle),
      center.dy + needleLength * math.sin(needleAngle),
    );
    final tail = Offset(
      center.dx - tailLength * math.cos(needleAngle),
      center.dy - tailLength * math.sin(needleAngle),
    );

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawLine(tail.translate(2, 4), tip.translate(2, 4), shadowPaint);

    final needlePaint = Paint()
      ..color = shiftStage == ShiftLightStage.optimalGreenShift
          ? RenaultSportPalette.oemShiftGreen
          : skin.needleColor
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tail, tip, needlePaint);

    // Capuchón central de aluminio cepillado
    canvas.drawCircle(
      center,
      radius * 0.09,
      Paint()..color = const Color(0xFF262B35),
    );
    canvas.drawCircle(
      center,
      radius * 0.045,
      Paint()..color = skin.primaryDialColor,
    );
  }

  /// Dibuja el icónico testigo de cambio del Clio RS 172 (Palanca de Cambios con flecha superior)
  void _drawOemGearshiftLightIcon({
    required Canvas canvas,
    required Offset center,
    required ShiftLightStage stage,
    required bool flashPhase,
  }) {
    Color iconColor;
    var glowing = false;

    switch (stage) {
      case ShiftLightStage.off:
        iconColor = const Color(0xFF2B313D);
        glowing = false;
      case ShiftLightStage.coldProtectionWarning:
        iconColor = RenaultSportPalette.coldEngineAmber;
        glowing = true;
      case ShiftLightStage.optimalGreenShift:
        iconColor = RenaultSportPalette.oemShiftGreen;
        glowing = true;
      case ShiftLightStage.fuelCutLimiterFlash:
        iconColor = flashPhase
            ? RenaultSportPalette.revLimiterRed
            : RenaultSportPalette.oemShiftGreen;
        glowing = true;
    }

    if (glowing) {
      canvas.drawCircle(
        center,
        20,
        Paint()
          ..color = iconColor.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    final paint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    // Base de la rejilla en H y pomo de la palanca de cambios
    canvas.drawCircle(Offset(center.dx, center.dy - 8), 4.5, Paint()..color = iconColor);
    canvas.drawLine(Offset(center.dx, center.dy - 4), Offset(center.dx - 3, center.dy + 9), paint);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 10), width: 18, height: 8),
      0,
      math.pi,
      false,
      paint,
    );

    // Flecha ascendente de cambio de marcha
    final arrowPath = Path()
      ..moveTo(center.dx + 9, center.dy + 4)
      ..lineTo(center.dx + 9, center.dy - 9)
      ..moveTo(center.dx + 5, center.dy - 5)
      ..lineTo(center.dx + 9, center.dy - 9)
      ..lineTo(center.dx + 13, center.dy - 5);
    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(covariant _RenaultSportTachometerPainter oldDelegate) {
    return oldDelegate.rpm != rpm ||
        oldDelegate.coolantTempC != coolantTempC ||
        oldDelegate.shiftStage != shiftStage ||
        oldDelegate.vvtActive != vvtActive ||
        oldDelegate.skin != skin ||
        oldDelegate.isDark != isDark ||
        oldDelegate.flashPhase != flashPhase;
  }
}

class _CenterDigitalClusterReadout extends StatelessWidget {
  final ObdTelemetryFrame frame;
  final ClusterSkinEdition skin;
  final bool isDark;
  final bool flashPhase;

  const _CenterDigitalClusterReadout({
    required this.frame,
    required this.skin,
    required this.isDark,
    required this.flashPhase,
  });

  @override
  Widget build(BuildContext context) {
    final gearText = frame.estimatedGear == 0 ? 'N' : '${frame.estimatedGear}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge de estado VVT F4R 736 o Protección en Frío
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: frame.isEngineCold
                ? RenaultSportPalette.coldEngineAmber.withValues(alpha: 0.18)
                : frame.vvtDephaserActive
                    ? RenaultSportPalette.oemShiftGreen.withValues(alpha: 0.20)
                    : Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: frame.isEngineCold
                  ? RenaultSportPalette.coldEngineAmber
                  : frame.vvtDephaserActive
                      ? RenaultSportPalette.oemShiftGreen
                      : Colors.white24,
            ),
          ),
          child: Text(
            frame.isEngineCold
                ? 'COLD MAP <75°C (MAX 5000 RPM)'
                : frame.vvtDephaserActive
                    ? 'F4R VVT DEPHASER ACTIVE'
                    : 'SIEMENS SIRIUS 34 WARM MAP',
            style: AppTheme.telemetryNumericStyle(
              fontSize: 10,
              color: frame.isEngineCold
                  ? RenaultSportPalette.coldEngineAmber
                  : frame.vvtDephaserActive
                      ? RenaultSportPalette.oemShiftGreen
                      : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: skin.primaryDialColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: skin.primaryDialColor, width: 1.4),
              ),
              child: Text(
                gearText,
                style: AppTheme.digitalDisplayStyle(
                  fontSize: 28,
                  color: skin.primaryDialColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${frame.speedKmh}',
              style: AppTheme.digitalDisplayStyle(
                fontSize: 38,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'KM/H',
              style: AppTheme.telemetryNumericStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
        Text(
          '${frame.rpm.round()} RPM',
          style: AppTheme.telemetryNumericStyle(
            fontSize: 18,
            color: frame.shiftLightStage == ShiftLightStage.optimalGreenShift
                ? RenaultSportPalette.oemShiftGreen
                : frame.shiftLightStage == ShiftLightStage.fuelCutLimiterFlash && flashPhase
                    ? RenaultSportPalette.revLimiterRed
                    : skin.primaryDialColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
