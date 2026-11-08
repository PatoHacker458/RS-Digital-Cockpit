import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'onboarding_provider.dart';

/// Secuencia de Onboarding interactiva de 4 pantallas obligatoria por rúbrica:
/// 1) Conexión KWP2000 con el Clio 172 (ECU Siemens Sirius 34 / Pin 7 Línea K)
/// 2) Telemetría y Shift-Light inteligente (5,000 RPM frío vs 6,750/7,250 RPM caliente)
/// 3) Sincronización en la nube con Firebase (Auth, Realtime DB Blackbox, Storage y FCM)
/// 4) Sensores G-Force Nativos y Android 17 Car Launcher Mode (Pixel Tablet)
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  static const List<({String badge, String title, String subtitle, String technicalDetail, IconData icon})>
      _slides = [
    (
      badge: 'PASO 01 / PROTOCOLO K-LINE',
      title: 'CONEXIÓN ISO 14230-4 KWP2000 SIRIUS 34',
      subtitle:
          'Comunicación directa con la ECU Siemens Sirius 34 del motor F4R 736 2.0L 16v mediante adaptador ELM327 original (v1.4b/v1.5/v2.3).',
      technicalDetail:
          'Secuencia Fast Init (ATSP5 + ATAT2) a 10.4 kbps con cola de prioridad de 3 niveles y Simulador de Circuito integrado para evaluación en aula.',
      icon: Icons.settings_input_component_rounded,
    ),
    (
      badge: 'PASO 02 / FIDELIDAD MECÁNICA F4R',
      title: 'TELEMETRÍA 120 FPS & SHIFT-LIGHT INTELIGENTE',
      subtitle:
          'Tacómetro Sagem con CustomPainter + ShaderMask que protege la mecánica del Clio RS 172 cuando el refrigerante está frío.',
      technicalDetail:
          'Si Temp < 75°C: alerta amarilla a 5,000 RPM. Si Temp >= 75°C: testigo verde OEM (palanca de cambios) a 6,750 RPM y corte de inyección a 7,250 RPM.',
      icon: Icons.speed_rounded,
    ),
    (
      badge: 'PASO 03 / ECOSISTEMA FIREBASE',
      title: 'BLACKBOX CLOUD SYNC, AUTH & FCM HUD',
      subtitle:
          ' telemetría en tiempo real en Firebase Realtime Database, avatares en Storage con caché offline y alertas Push en cabina.',
      technicalDetail:
          'Soporta Email (con bloqueo hasta verificar correo), Google y GitHub Auth. Regla estricta: edición de foto habilitada exclusivamente para cuentas Email.',
      icon: Icons.cloud_sync_rounded,
    ),
    (
      badge: 'PASO 04 / PIXEL TABLET ANDROID 17',
      title: 'SENSORES G-FORCE, BIOMETRÍA & CAR LAUNCHER',
      subtitle:
          'Medidor vectorial G-Force con filtro de paso bajo, Inmovilizador por huella digital, Google Maps nativo y Dock de aplicaciones.',
      technicalDetail:
          'Configurado con categorías HOME y DEFAULT en AndroidManifest.xml para operar como Car Launcher nativo en Google Pixel Tablet (2560x1600).',
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RENAULT SPORT // CLIO RS 172 PHASE 2',
                        style: AppTheme.renaultSportHeaderStyle(
                          fontSize: 16,
                          color: primary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: notifier.completeOnboarding,
                        icon: const Icon(Icons.fast_forward_rounded, size: 18),
                        label: const Text('SALTAR A CABINA'),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: primary, width: 1.5),
                                ),
                                child: Icon(slide.icon, size: 42, color: primary),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      slide.badge,
                                      style: AppTheme.telemetryNumericStyle(
                                        fontSize: 12,
                                        color: RenaultSportPalette.siriusLiquidYellow,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      slide.title,
                                      style: AppTheme.renaultSportHeaderStyle(
                                        fontSize: 24,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            slide.subtitle,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 17),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: primary.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.memory_rounded, color: primary, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    slide.technicalDetail,
                                    style: AppTheme.telemetryNumericStyle(
                                      fontSize: 13,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Indicadores de página reactivos en Riverpod
                      Row(
                        children: List<Widget>.generate(_slides.length, (idx) {
                          final active = idx == onboardingState.currentPageIndex;
                          return GestureDetector(
                            onTap: () => notifier.setPageIndex(idx),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              margin: const EdgeInsets.only(right: 8),
                              width: active ? 36 : 12,
                              height: 10,
                              decoration: BoxDecoration(
                                color: active ? primary : Colors.white24,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          );
                        }),
                      ),
                      Row(
                        children: [
                          if (onboardingState.currentPageIndex > 0)
                            OutlinedButton(
                              onPressed: notifier.previousPage,
                              child: const Text('ANTERIOR'),
                            ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: notifier.nextPage,
                            icon: Icon(
                              onboardingState.currentPageIndex == 3
                                  ? Icons.sports_motorsports_rounded
                                  : Icons.arrow_forward_rounded,
                            ),
                            label: Text(
                              onboardingState.currentPageIndex == 3
                                  ? 'INICIAR SISTEMA SIRIUS 34'
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

