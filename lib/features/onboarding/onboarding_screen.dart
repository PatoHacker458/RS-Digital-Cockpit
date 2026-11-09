import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'onboarding_provider.dart';

/// Secuencia de Onboarding limpia y responsiva (4 pasos) para RS Digital Cockpit.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  static const List<({String badge, String title, String subtitle, IconData icon})>
      _slides = [
    (
      badge: '01 // OBD-II KWP2000',
      title: 'CONEXIÓN ECU SIRIUS 34',
      subtitle:
          'Enlace Bluetooth directo con tu adaptador ELM327 para lectura en tiempo real del motor F4R 2.0 16v.',
      icon: Icons.settings_input_component_rounded,
    ),
    (
      badge: '02 // SHIFT-LIGHT OEM',
      title: ' INSTRUMENTACIÓN 120 FPS',
      subtitle:
          'Protección automática en frío (5,000 RPM < 75°C) y testigo verde de cambio óptimo a 6,750 RPM en temperatura operativa.',
      icon: Icons.speed_rounded,
    ),
    (
      badge: '03 // CLOUD TELEMETRY',
      title: 'SINCRONIZACIÓN EN LA NUBE',
      subtitle:
          'Guarda tus sesiones de pista, récords 0-100 km/h, perfil de piloto y alertas de mantenimiento en Firebase.',
      icon: Icons.cloud_sync_rounded,
    ),
    (
      badge: '04 // COCKPIT & LAUNCHER',
      title: 'FUERZAS G, GPS & GARAGE',
      subtitle:
          'Medidor inercial G-Force, mapa de circuito y talleres, desbloqueo por huella y lanzador rápido de cabina.',
      icon: Icons.dashboard_customize_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingState = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final slide = _slides[onboardingState.currentPageIndex];
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'RS DIGITAL COCKPIT',
                          style: AppTheme.renaultSportHeaderStyle(
                            fontSize: 16,
                            color: primary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: notifier.completeOnboarding,
                        child: const Text('SALTAR'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: primary, width: 1.4),
                            ),
                            child: Icon(slide.icon, size: 36, color: primary),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            slide.badge,
                            style: AppTheme.telemetryNumericStyle(
                              fontSize: 12,
                              color: RenaultSportPalette.siriusLiquidYellow,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            slide.title,
                            style: AppTheme.renaultSportHeaderStyle(
                              fontSize: 22,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            slide.subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontSize: 15.5, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List<Widget>.generate(_slides.length, (idx) {
                          final active = idx == onboardingState.currentPageIndex;
                          return GestureDetector(
                            onTap: () => notifier.setPageIndex(idx),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.only(right: 8),
                              width: active ? 32 : 10,
                              height: 9,
                              decoration: BoxDecoration(
                                color: active ? primary : Colors.white24,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          );
                        }),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onboardingState.currentPageIndex > 0) ...[
                            OutlinedButton(
                              onPressed: notifier.previousPage,
                              child: const Text('ATRÁS'),
                            ),
                            const SizedBox(width: 10),
                          ],
                          ElevatedButton.icon(
                            onPressed: notifier.nextPage,
                            icon: Icon(
                              onboardingState.currentPageIndex == 3
                                  ? Icons.sports_motorsports_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                            label: Text(
                              onboardingState.currentPageIndex == 3
                                  ? 'ENTRAR'
                                  : 'SIGUIENTE',
                            ),
                          ),
                        ],
                      ),
                    ],
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
