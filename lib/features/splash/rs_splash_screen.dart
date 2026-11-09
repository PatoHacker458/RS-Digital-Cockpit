import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';

class SplashBootState {
  final double progress;
  final String bootStageText;
  final bool isReady;

  const SplashBootState({
    this.progress = 0.15,
    this.bootStageText = 'INITIALIZING SIEMENS SIRIUS 34 K-LINE...',
    this.isReady = false,
  });

  SplashBootState copyWith({
    double? progress,
    String? bootStageText,
    bool? isReady,
  }) {
    return SplashBootState(
      progress: progress ?? this.progress,
      bootStageText: bootStageText ?? this.bootStageText,
      isReady: isReady ?? this.isReady,
    );
  }
}

class SplashBootNotifier extends Notifier<SplashBootState> {
  Timer? _bootTimer;

  @override
  SplashBootState build() {
    _startSequence();
    ref.onDispose(() => _bootTimer?.cancel());
    return const SplashBootState();
  }

  void _startSequence() {
    var step = 0;
    _bootTimer = Timer.periodic(const Duration(milliseconds: 450), (timer) {
      step++;
      if (step == 1) {
        state = state.copyWith(
          progress: 0.45,
          bootStageText: 'LOADING KWP2000 PROTOCOL & IMU SENSORS...',
        );
      } else if (step == 2) {
        state = state.copyWith(
          progress: 0.80,
          bootStageText: 'SYNCING FIREBASE TELEMETRY CLOUD...',
        );
      } else if (step == 3) {
        state = state.copyWith(
          progress: 1.0,
          bootStageText: 'SYSTEM READY',
        );
      } else {
        timer.cancel();
        state = state.copyWith(isReady: true);
      }
    });
  }
}

final splashBootProvider = NotifierProvider<SplashBootNotifier, SplashBootState>(
  SplashBootNotifier.new,
);

/// Splash Screen oficial de **RS Digital Cockpit** con el emblema vectorial de Renault Sport.
class RsSplashScreen extends ConsumerWidget {
  const RsSplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(splashBootProvider);

    return Scaffold(
      backgroundColor: RenaultSportPalette.nightCarbonBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo vectorial Renault Sport Diamond + Franjas RS
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: _RenaultSportDiamondPainter(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'RENAULT SPORT',
                    textAlign: TextAlign.center,
                    style: AppTheme.renaultSportHeaderStyle(
                      fontSize: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RS DIGITAL COCKPIT',
                    textAlign: TextAlign.center,
                    style: AppTheme.telemetryNumericStyle(
                      fontSize: 15,
                      color: RenaultSportPalette.sagemAmberOrange,
                      letterSpacing: 3.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: boot.progress,
                      minHeight: 6,
                      backgroundColor: RenaultSportPalette.speedlineTuriniAnthracite,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        RenaultSportPalette.siriusLiquidYellow,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    boot.bootStageText,
                    textAlign: TextAlign.center,
                    style: AppTheme.telemetryNumericStyle(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RenaultSportDiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Resplandor ámbar/amarillo de fondo
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.44,
      Paint()
        ..color = RenaultSportPalette.sagemAmberOrange.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Rombo exterior Renault en Liquid Yellow / Plata
    final outerDiamond = Path()
      ..moveTo(cx, cy - 48)
      ..lineTo(cx + 38, cy)
      ..lineTo(cx, cy + 48)
      ..lineTo(cx - 38, cy)
      ..close();

    final gradientPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          RenaultSportPalette.siriusLiquidYellow,
          RenaultSportPalette.sagemAmberOrange,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(outerDiamond, gradientPaint);

    // Rombo interior hueco (efecto cinta geométrica Renault)
    final innerCutout = Path()
      ..moveTo(cx, cy - 24)
      ..lineTo(cx + 18, cy)
      ..lineTo(cx, cy + 24)
      ..lineTo(cx - 18, cy)
      ..close();

    canvas.drawPath(
      innerCutout,
      Paint()..color = RenaultSportPalette.nightCarbonBg,
    );

    // Líneas diagonales de relieve del rombo
    final linePaint = Paint()
      ..color = RenaultSportPalette.nightCarbonBg
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(cx, cy - 48), Offset(cx + 18, cy), linePaint);
    canvas.drawLine(Offset(cx, cy + 48), Offset(cx - 18, cy), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

