import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../models/obd_telemetry_frame.dart';

/// Tacómetro Radial Sagem 0-8000 RPM (`CustomPainter` + `ShaderMask`)
/// 100% responsivo (sin desbordamientos en tablet ni teléfono).
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final showLedBar = availableHeight > 180;
        final dialAreaHeight =
            showLedBar ? math.max(120.0, availableHeight - 38.0) : availableHeight;
        final size = math.min(constraints.maxWidth, dialAreaHeight);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showLedBar) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: _ProgressiveShiftLightBar(
                  rpm: frame.rpm,
                  isEngineCold: frame.isEngineCold,
                  stage: frame.shiftLightStage,
                  flashPhase: flashPhase,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Expanded(
              child: Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
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
                      Positioned(
                        bottom: size * 0.11,
                        width: size * 0.68,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _CenterDigitalClusterReadout(
                            frame: frame,
                            skin: skin,
                            isDark: isDark,
                            flashPhase: flashPhase,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stage == ShiftLightStage.fuelCutLimiterFlash && flashPhase
              ? RenaultSportPalette.revLimiterRed
              : const Color(0xFF282E38),
          width: 1.2,
        ),
      ),
      child: Row(
        children: List<Widget>.generate(totalLeds, (index) {
          final isLit = index < activeLeds;
          Color ledColor;
          if (stage == ShiftLightStage.fuelCutLimiterFlash) {
            ledColor = flashPhase
                ? RenaultSportPalette.revLimiterRed
                : const Color(0xFF00AAFF);
          } else if (index < 6) {
            ledColor = RenaultSportPalette.oemShiftGreen;
          } else if (index < 11) {
            ledColor = RenaultSportPalette.siriusLiquidYellow;
          } else {
            ledColor = RenaultSportPalette.revLimiterRed;
          }

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.8),
              decoration: BoxDecoration(
                color: isLit ? ledColor : const Color(0xFF1E222A),
                borderRadius: BorderRadius.circular(2.5),
                boxShadow: isLit
                    ? <BoxShadow>[
                        BoxShadow(
                          color: ledColor.withValues(alpha: 0.75),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
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
    final radius = (math.min(size.width, size.height) / 2) - 3;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
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
    final radius = (math.min(size.width, size.height) / 2) - 8;

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

    final baseTrackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.butt
      ..color = isDark ? const Color(0xFF252A34) : const Color(0xFFCBD5E1);
    canvas.drawArc(arcRect, _startAngle, _sweepAngle, false, baseTrackPaint);

    if (isEngineCold) {
      final coldWarnStart = _rpmToAngle(5000.0);
      final coldWarnSweep = _rpmToAngle(6000.0) - coldWarnStart;
      canvas.drawArc(
        arcRect,
        coldWarnStart,
        coldWarnSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12.0
          ..color = RenaultSportPalette.coldEngineAmber,
      );

      final coldRedStart = _rpmToAngle(6000.0);
      final coldRedSweep = _rpmToAngle(8000.0) - coldRedStart;
      canvas.drawArc(
        arcRect,
        coldRedStart,
        coldRedSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12.0
          ..color = RenaultSportPalette.revLimiterRed,
      );
    } else {
      final vvtStart = _rpmToAngle(5150.0);
      final vvtSweep = _rpmToAngle(6750.0) - vvtStart;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.78),
        vvtStart,
        vvtSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0
          ..color = skin.primaryDialColor.withValues(alpha: 0.45),
      );

      final greenShiftStart = _rpmToAngle(6750.0);
      final greenShiftSweep = _rpmToAngle(7250.0) - greenShiftStart;
      canvas.drawArc(
        arcRect,
        greenShiftStart,
        greenShiftSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12.0
          ..color = RenaultSportPalette.oemShiftGreen,
      );

      final warmRedStart = _rpmToAngle(7250.0);
      final warmRedSweep = _rpmToAngle(8000.0) - warmRedStart;
      canvas.drawArc(
        arcRect,
        warmRedStart,
        warmRedSweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12.0
          ..color = RenaultSportPalette.revLimiterRed,
      );
    }

    final activeSweep = _rpmToAngle(rpm) - _startAngle;
    final activeArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
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

    for (var i = 0; i <= 32; i++) {
      final tickRpm = i * 250.0;
      final angle = _rpmToAngle(tickRpm);
      final isMajor = i % 4 == 0;
      final isHalf = i % 2 == 0 && !isMajor;

      final outerR = radius * 0.84;
      final innerR = outerR - (isMajor ? 14.0 : (isHalf ? 9.0 : 5.0));

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

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = isMajor ? 2.8 : 1.4
          ..color = isRedZoneTick
              ? RenaultSportPalette.revLimiterRed
              : (isDark ? const Color(0xFFF3F4F6) : const Color(0xFF0F172A)),
      );

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

    _drawOemGearshiftLightIcon(
      canvas: canvas,
      center: Offset(center.dx + radius * 0.36, center.dy + radius * 0.16),
      stage: shiftStage,
      flashPhase: flashPhase,
    );

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

    canvas.drawLine(
      tail.translate(2, 4),
      tip.translate(2, 4),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawLine(
      tail,
      tip,
      Paint()
        ..color = shiftStage == ShiftLightStage.optimalGreenShift
            ? RenaultSportPalette.oemShiftGreen
            : skin.needleColor
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(center, radius * 0.085, Paint()..color = const Color(0xFF262B35));
    canvas.drawCircle(center, radius * 0.04, Paint()..color = skin.primaryDialColor);
  }

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
        18,
        Paint()
          ..color = iconColor.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    final paint = Paint()
      ..color = iconColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(center.dx, center.dy - 7), 4.0, Paint()..color = iconColor);
    canvas.drawLine(Offset(center.dx, center.dy - 3), Offset(center.dx - 3, center.dy + 8), paint);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 9), width: 16, height: 7),
      0,
      math.pi,
      false,
      paint,
    );

    final arrowPath = Path()
      ..moveTo(center.dx + 8, center.dy + 3)
      ..lineTo(center.dx + 8, center.dy - 8)
      ..moveTo(center.dx + 5, center.dy - 5)
      ..lineTo(center.dx + 8, center.dy - 8)
      ..lineTo(center.dx + 11, center.dy - 5);
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: frame.isEngineCold
                ? RenaultSportPalette.coldEngineAmber.withValues(alpha: 0.18)
                : frame.vvtDephaserActive
                    ? RenaultSportPalette.oemShiftGreen.withValues(alpha: 0.20)
                    : Colors.black26,
            borderRadius: BorderRadius.circular(6),
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
                ? 'COLD <75°C (5K MAX)'
                : frame.vvtDephaserActive
                    ? 'VVT ON'
                    : 'WARM MAP',
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
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: skin.primaryDialColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: skin.primaryDialColor, width: 1.4),
              ),
              child: Text(
                gearText,
                style: AppTheme.digitalDisplayStyle(
                  fontSize: 26,
                  color: skin.primaryDialColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${frame.speedKmh}',
              style: AppTheme.digitalDisplayStyle(
                fontSize: 34,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'KM/H',
              style: AppTheme.telemetryNumericStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
        Text(
          '${frame.rpm.round()} RPM',
          style: AppTheme.telemetryNumericStyle(
            fontSize: 16,
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
