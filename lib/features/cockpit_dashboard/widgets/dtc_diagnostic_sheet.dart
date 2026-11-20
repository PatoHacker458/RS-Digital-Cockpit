import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../digital_garage_payments/providers/payment_garage_providers.dart';
import '../../sensors/biometric_immobilizer_service.dart';
import '../../telemetry/providers/telemetry_providers.dart';
import 'launcher_dock_widget.dart';

/// Apartado **ECU**:
/// 1) Switch Maestro ON/OFF para activar o apagar el Bluetooth OBD2 (evitando interferencia con audio).
/// 2) Selector de Adaptador OBD-II Bluetooth (ELM327).
/// 3) Diagnóstico y borrado de códigos de falla DTC (Modo 03 / Modo 04 Sirius 34) sin bloqueo de inmovilizador.
/// 4) Monitor serial de tramas K-Line (10.4 kbps).
class DtcDiagnosticSheet extends ConsumerWidget {
  const DtcDiagnosticSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adapterState = ref.watch(obdConnectionModeProvider);
    final obdNotifier = ref.read(obdConnectionModeProvider.notifier);
    final dtcAsync = ref.watch(sirius34DtcProvider);
    final terminalLogsAsync = ref.watch(obdTerminalLogsProvider);
    final activePlan = ref.watch(
      digitalGaragePaymentProvider.select((s) => s.activeSubscription),
    );
    final hasDtcProAccess = activePlan.unlocksTrophyProFeatures;
    final primary = Theme.of(context).colorScheme.primary;
    final isSimulator = adapterState.mode == ObdConnectionMode.trackSimulator;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Tarjeta Maestra de Control ECU Bluetooth (ON / OFF) + Selector ELM327
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado con Switch Maestro ON/OFF
                      Row(
                        children: [
                          Icon(
                            !adapterState.ecuEnabled
                                ? Icons.bluetooth_disabled_rounded
                                : (adapterState.isConnected
                                    ? Icons.bluetooth_connected_rounded
                                    : Icons.bluetooth_searching_rounded),
                            color: !adapterState.ecuEnabled
                                ? Colors.grey
                                : (adapterState.isConnected
                                    ? RenaultSportPalette.oemShiftGreen
                                    : primary),
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CONEXIÓN ECU OBD2 (ELM327)',
                                  style: AppTheme.renaultSportHeaderStyle(
                                    fontSize: 16,
                                    color: adapterState.ecuEnabled
                                        ? primary
                                        : Colors.grey,
                                  ),
                                ),
                                Text(
                                  adapterState.statusText,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (adapterState.ecuEnabled
                                      ? RenaultSportPalette.oemShiftGreen
                                      : Colors.grey)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: adapterState.ecuEnabled
                                    ? RenaultSportPalette.oemShiftGreen
                                    : Colors.grey,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  adapterState.ecuEnabled ? 'ECU ON' : 'ECU OFF',
                                  style: AppTheme.telemetryNumericStyle(
                                    fontSize: 11.5,
                                    color: adapterState.ecuEnabled
                                        ? RenaultSportPalette.oemShiftGreen
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Switch(
                                  value: adapterState.ecuEnabled,
                                  activeThumbColor:
                                      RenaultSportPalette.oemShiftGreen,
                                  onChanged: (val) =>
                                      obdNotifier.setEcuEnabled(val),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (!adapterState.ecuEnabled) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.headphones_rounded, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Módulo ECU Bluetooth apagado. El socket OBD2 está desconectado para evitar cualquier interferencia mientras escuchas música por Bluetooth.',
                                  style: TextStyle(fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: obdNotifier.scanPairedBluetoothDevices,
                              icon:
                                  const Icon(Icons.refresh_rounded, size: 17),
                              label: const Text('BUSCAR VINCULADOS'),
                            ),
                            OutlinedButton.icon(
                              onPressed: obdNotifier.openSystemBluetoothSettings,
                              icon: const Icon(
                                Icons.settings_bluetooth_rounded,
                                size: 17,
                              ),
                              label: const Text('EMPAREJAR NUEVO'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (adapterState.pairedDevices.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No se encontraron adaptadores Bluetooth vinculados. Toca "Emparejar Nuevo" (PIN: 1234 o 0000) y luego presiona "Buscar Vinculados".',
                                    style: TextStyle(fontSize: 12.5),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: adapterState.pairedDevices.map((device) {
                              final isSelected = device.macAddress ==
                                      adapterState.selectedMacAddress &&
                                  !isSimulator;
                              return InkWell(
                                onTap: () =>
                                    obdNotifier.connectToBluetoothAdapter(
                                  macAddress: device.macAddress,
                                  deviceName: device.name,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 265,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? RenaultSportPalette.oemShiftGreen
                                            .withValues(alpha: 0.14)
                                        : Colors.black12,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? RenaultSportPalette.oemShiftGreen
                                          : (device.looksLikeObdAdapter
                                              ? primary
                                              : Colors.white12),
                                      width: isSelected ? 1.8 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        device.looksLikeObdAdapter
                                            ? Icons
                                                .directions_car_filled_rounded
                                            : Icons.bluetooth_rounded,
                                        color: isSelected
                                            ? RenaultSportPalette.oemShiftGreen
                                            : primary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              device.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              device.macAddress,
                                              style:
                                                  AppTheme.telemetryNumericStyle(
                                                fontSize: 11,
                                                color: Colors.white60,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected &&
                                          adapterState.isConnected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color:
                                              RenaultSportPalette.oemShiftGreen,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                        const Divider(height: 24),

                        // Switch opcional de Simulador F4R
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Simulador de Telemetría F4R (Pruebas sin auto)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          value: isSimulator,
                          onChanged: (val) => obdNotifier.setConnectionMode(
                            val
                                ? ObdConnectionMode.trackSimulator
                                : ObdConnectionMode.realElm327Bluetooth,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 2. Diagnóstico DTC Sirius 34 + Monitor K-Line
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 780;
                  final dtcCard = Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'CÓDIGOS DE FALLA DTC (SIRIUS 34)',
                                style: AppTheme.renaultSportHeaderStyle(
                                  fontSize: 15,
                                  color: primary,
                                ),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: adapterState.ecuEnabled &&
                                            hasDtcProAccess
                                        ? () => ref
                                            .read(sirius34DtcProvider.notifier)
                                            .scanDtcCodes()
                                        : null,
                                    icon: const Icon(Icons.radar_rounded,
                                        size: 16),
                                    label: const Text('LEER DTC'),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: adapterState.ecuEnabled &&
                                            hasDtcProAccess
                                        ? () async {
                                            final bioOk = await ref
                                                .read(
                                                  biometricImmobilizerProvider
                                                      .notifier,
                                                )
                                                .authenticateDriver(
                                                  reason:
                                                      'Autoriza con tu huella borrar los códigos DTC de la ECU',
                                                );
                                            if (bioOk) {
                                              await ref
                                                  .read(
                                                    sirius34DtcProvider
                                                        .notifier,
                                                  )
                                                  .clearAllDtcCodes();
                                            }
                                          }
                                        : null,
                                    icon: const Icon(
                                      Icons.fingerprint_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('BORRAR DTC'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (!hasDtcProAccess)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.lock_outline_rounded,
                                      size: 36,
                                      color: RenaultSportPalette
                                          .siriusLiquidYellow,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Lectura y borrado biométrico DTC disponibles en Plan 3: RS Trophy Pro',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12.5),
                                    ),
                                    const SizedBox(height: 10),
                                    OutlinedButton.icon(
                                      onPressed: () => ref
                                          .read(cockpitTabProvider.notifier)
                                          .selectTab(
                                            CockpitSectionTab.digitalGarage,
                                          ),
                                      icon: const Icon(
                                        Icons.workspace_premium_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('ACTIVAR EN GARAGE'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            dtcAsync.when(
                            data: (dtcs) {
                              if (dtcs.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 28),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 40,
                                          color:
                                              RenaultSportPalette.oemShiftGreen,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'ECU sin códigos de falla registrados',
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return Column(
                                children: dtcs.map((fault) {
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: RenaultSportPalette.revLimiterRed
                                            .withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color:
                                              RenaultSportPalette.revLimiterRed,
                                        ),
                                      ),
                                      child: Text(
                                        fault.code,
                                        style: AppTheme.telemetryNumericStyle(
                                          fontSize: 12,
                                          color:
                                              RenaultSportPalette.revLimiterRed,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      '${fault.renaultDfCode} • ${fault.subsystem}',
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
                                }).toList(),
                              );
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (e, _) => Text('Error K-Line: $e'),
                          ),
                        ],
                      ),
                    ),
                  );

                  final serialMonitor = Container(
                    height: 260,
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
                          'MONITOR SERIAL KWP2000 (10.4 KBPS)',
                          style: AppTheme.telemetryNumericStyle(
                            fontSize: 11.5,
                            color: RenaultSportPalette.oemShiftGreen,
                          ),
                        ),
                        const Divider(color: Colors.white24),
                        Expanded(
                          child: terminalLogsAsync.when(
                            data: (logs) => logs.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Esperando tramas del adaptador OBD2...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
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
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: dtcCard),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: serialMonitor),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      dtcCard,
                      const SizedBox(height: 14),
                      serialMonitor,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
