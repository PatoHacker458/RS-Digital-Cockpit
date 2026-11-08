import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../sensors/biometric_immobilizer_service.dart';
import '../../telemetry/providers/telemetry_providers.dart';

/// Hoja Modal de Diagnóstico Profundo para la ECU Siemens Sirius 34:
/// - Lectura de códigos de falla DTC mediante Modo `03` de KWP2000 y equivalencia Renault DF (`pyren`/`ddt4all`).
/// - Borrado de averías mediante Modo `04` protegido por Biometría (`local_auth`).
/// - Consola en vivo con las tramas hexadecimales crudas del ELM327 (`ATZ`, `ATSP5`, `ATAT2`, `010C`, etc.).
class DtcDiagnosticSheet extends ConsumerWidget {
  const DtcDiagnosticSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dtcAsync = ref.watch(sirius34DtcProvider);
    final terminalLogsAsync = ref.watch(obdTerminalLogsProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DIAGNÓSTICO ECU SIEMENS SIRIUS 34 (ISO 14230-4 KWP2000)',
                    style: AppTheme.renaultSportHeaderStyle(
                      fontSize: 18,
                      color: primary,
                    ),
                  ),
                  const Text(
                    'Pin 7 Línea K (10.4 kbps) • Base de códigos Renault DDT2000 / PyRen',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => ref.read(sirius34DtcProvider.notifier).scanDtcCodes(),
                    icon: const Icon(Icons.radar_rounded, size: 18),
                    label: const Text('ESCANEAR MODO 03'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final bioOk = await ref
                          .read(biometricImmobilizerProvider.notifier)
                          .authenticateDriver(
                            reason:
                                'Autoriza con tu huella el borrado de DTCs (Modo 04) en la ECU Sirius 34',
                          );
                      if (bioOk) {
                        await ref.read(sirius34DtcProvider.notifier).clearAllDtcCodes();
                      }
                    },
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text('BORRAR DTCs (MODO 04 + HUELLA)'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                // Lista de Códigos de Falla DTC
                Expanded(
                  flex: 5,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: dtcAsync.when(
                        data: (dtcs) {
                          if (dtcs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 48,
                                    color: RenaultSportPalette.oemShiftGreen,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'SIN CÓDIGOS DE FALLA EN SIEMENS SIRIUS 34',
                                    style: AppTheme.renaultSportHeaderStyle(
                                      fontSize: 15,
                                      color: RenaultSportPalette.oemShiftGreen,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView.separated(
                            itemCount: dtcs.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final fault = dtcs[index];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: RenaultSportPalette.revLimiterRed
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: RenaultSportPalette.revLimiterRed,
                                    ),
                                  ),
                                  child: Text(
                                    fault.code,
                                    style: AppTheme.telemetryNumericStyle(
                                      fontSize: 13,
                                      color: RenaultSportPalette.revLimiterRed,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '${fault.renaultDfCode} — ${fault.subsystem}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  fault.description,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error K-Line: $e')),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Monitor de Tramas Hexadecimales ELM327 KWP2000
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090B0E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF28303D)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MONITOR SERIAL ELM327 // KWP2000 10.4 KBPS',
                          style: AppTheme.telemetryNumericStyle(
                            fontSize: 12,
                            color: RenaultSportPalette.oemShiftGreen,
                          ),
                        ),
                        const Divider(color: Colors.white24),
                        Expanded(
                          child: terminalLogsAsync.when(
                            data: (logs) => ListView.builder(
                              itemCount: logs.length,
                              itemBuilder: (_, idx) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  logs[idx],
                                  style: AppTheme.telemetryNumericStyle(
                                    fontSize: 11,
                                    color: const Color(0xFFA7F3D0),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            loading: () => const Center(
                              child: Text('Inicializando bus K-Line...'),
                            ),
                            error: (e, _) => Text('Error serial: $e'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

