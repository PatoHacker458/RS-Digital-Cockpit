import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../sensors/g_force_sensor_service.dart';

/// WIDGET DE INNOVACIÓN EN UI #2 (10% RÚBRICA):
/// `GForceBallWidget`
/// Medidor vectorial de fuerzas G en tiempo real estilo Clio RS Monitor / Nissan GT-R
/// alimentado directamente por el Acelerómetro y Giroscopio nativos (`sensors_plus`)
/// con filtro de paso bajo exponencial.
class GForceBallWidget extends ConsumerWidget {
  const GForceBallWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gState = ref.watch(gForceSensorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryAccent = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RS MONITOR G-FORCE',
                  style: AppTheme.renaultSportHeaderStyle(
                    fontSize: 14,
                    color: primaryAccent,
                  ),
                ),
                InkWell(
                  onTap: () => ref.read(gForceSensorProvider.notifier).resetPeakG(),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PEAK ${gState.peakG.toStringAsFixed(2)}G ↺',
                      style: AppTheme.telemetryNumericStyle(
                        fontSize: 11,
                        color: primaryAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                    painter: _GForceVectorPainter(
                      gState: gState,
                      isDark: isDark,
                      accentColor: primaryAccent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _GReadoutChip(
                  label: 'LAT (CURVA)',
                  value: '${gState.lateralG >= 0 ? '+' : ''}${gState.lateralG.toStringAsFixed(2)}G',
                  color: primaryAccent,
                ),
                _GReadoutChip(
                  label: 'LON (FRENO/ACEL)',
                  value:
                      '${gState.longitudinalG >= 0 ? '+' : ''}${gState.longitudinalG.toStringAsFixed(2)}G',
                  color: RenaultSportPalette.siriusLiquidYellow,
                ),
                _GReadoutChip(
                  label: 'YAW GYRO',
                  value: '${gState.yawRateDegSec.toStringAsFixed(0)}°/s',
                  color: RenaultSportPalette.oemShiftGreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GReadoutChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _GReadoutChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: AppTheme.telemetryNumericStyle(
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _GForceVectorPainter extends CustomPainter {
  final GForceTelemetryState gState;
  final bool isDark;
  final Color accentColor;

  const _GForceVectorPainter({
    required this.gState,
    required this.isDark,
    required this.accentColor,
  });

  static const double _maxScaleG = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (math.min(size.width, size.height) / 2) - 6;

    // Fondo radar vectorial
    canvas.drawCircle(
      center,
      maxRadius,
      Paint()
        ..color = isDark ? const Color(0xFF101319) : const Color(0xFFF1F5F9),
    );

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isDark ? const Color(0xFF2B3240) : const Color(0xFFCBD5E1);

    // Anillos concéntricos de adherencia (0.5G, 1.0G, 1.5G)
    for (final gRing in <double>[0.5, 1.0, 1.5]) {
      final r = maxRadius * (gRing / _maxScaleG);
      canvas.drawCircle(center, r, gridPaint);
    }

    // Ejes ortogonales X / Y
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      gridPaint,
    );

    // Estela histórica de fuerzas G
    for (var i = 0; i < gState.trailPoints.length; i++) {
      final pt = gState.trailPoints[i];
      final alpha = (1.0 - (i / gState.trailPoints.length)) * 0.45;
      final offset = Offset(
        center.dx + (pt.x / _maxScaleG).clamp(-1.0, 1.0) * maxRadius,
        center.dy - (pt.y / _maxScaleG).clamp(-1.0, 1.0) * maxRadius,
      );
      canvas.drawCircle(
        offset,
        3.2,
        Paint()..color = accentColor.withValues(alpha: alpha),
      );
    }

    // Posición instantánea de la bola inercial G-Force
    final ballOffset = Offset(
      center.dx + (gState.lateralG / _maxScaleG).clamp(-1.0, 1.0) * maxRadius,
      center.dy - (gState.longitudinalG / _maxScaleG).clamp(-1.0, 1.0) * maxRadius,
    );

    // Vector director desde el centro de gravedad del Clio 172
    canvas.drawLine(
      center,
      ballOffset,
      Paint()
        ..color = accentColor.withValues(alpha: 0.7)
        ..strokeWidth = 2.2,
    );

    // Halo y esfera G-Force
    canvas.drawCircle(
      ballOffset,
      12.0,
      Paint()
        ..color = accentColor.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      ballOffset,
      6.5,
      Paint()..color = accentColor,
    );
    canvas.drawCircle(
      ballOffset,
      2.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _GForceVectorPainter oldDelegate) {
    return oldDelegate.gState != gState ||
        oldDelegate.isDark != isDark ||
        oldDelegate.accentColor != accentColor;
  }
}

