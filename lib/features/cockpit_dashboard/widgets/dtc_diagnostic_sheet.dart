import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../digital_garage_payments/providers/payment_garage_providers.dart';
import '../../sensors/biometric_immobilizer_service.dart';
import '../../telemetry/providers/telemetry_providers.dart';
import 'launcher_dock_widget.dart';

/// Apartado **ECU**:
/// 1) Switch Maestro ON/OFF para activar o apagar el Bluetooth OBD2 (evitando interferencia con audio).
/// 2) Selector desplegable en modal de Adaptador OBD-II Bluetooth (ELM327) estilo Blackbox Cloud.
/// 3) Diagnóstico y borrado de códigos de falla DTC (Modo 03 / Modo 04 Sirius 34) sin bloqueo de inmovilizador.
/// 4) Monitor serial de tramas K-Line (10.4 kbps).
class DtcDiagnosticSheet extends ConsumerWidget {
  const DtcDiagnosticSheet({super.key});

  void _openBluetoothDevicesSheet(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(obdConnectionModeProvider.notifier);
    if (ref.read(obdConnectionModeProvider).pairedDevices.isEmpty) {
      notifier.scanPairedBluetoothDevices();
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _BluetoothDevicesModalSheet(),
    );
  }

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
    final hasSelectedDevice =
        adapterState.selectedDeviceName != null && !isSimulator;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Tarjeta Maestra de Control ECU Bluetooth (ON / OFF) + Selector ELM327 desplegable
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
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
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
                                    fontSize: 11,
                                    color: adapterState.ecuEnabled
                                        ? RenaultSportPalette.oemShiftGreen
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Switch(
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
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
                        const SizedBox(height: 14),

                        // Selector desplegable compacto de dispositivo Bluetooth (abre modal)
                        InkWell(
                          onTap: () => _openBluetoothDevicesSheet(context, ref),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: adapterState.isConnected && !isSimulator
                                  ? RenaultSportPalette.oemShiftGreen
                                      .withValues(alpha: 0.12)
                                  : Colors.black12,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: adapterState.isConnected && !isSimulator
                                    ? RenaultSportPalette.oemShiftGreen
                                    : primary.withValues(alpha: 0.5),
                                width: 1.3,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  hasSelectedDevice
                                      ? Icons.directions_car_filled_rounded
                                      : Icons.bluetooth_searching_rounded,
                                  color: adapterState.isConnected && !isSimulator
                                      ? RenaultSportPalette.oemShiftGreen
                                      : primary,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hasSelectedDevice
                                            ? adapterState.selectedDeviceName!
                                            : 'Seleccionar adaptador OBD2 Bluetooth',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      Text(
                                        hasSelectedDevice &&
                                                adapterState
                                                        .selectedMacAddress !=
                                                    null
                                            ? '${adapterState.selectedMacAddress} • ${adapterState.pairedDevices.length} vinculados'
                                            : '${adapterState.pairedDevices.length} dispositivos Bluetooth vinculados',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.telemetryNumericStyle(
                                          fontSize: 11,
                                          color: Colors.white60,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (adapterState.isConnecting)
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: primary,
                                    ),
                                  )
                                else if (adapterState.isConnected && !isSimulator)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: RenaultSportPalette.oemShiftGreen
                                          .withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'OK',
                                      style: AppTheme.telemetryNumericStyle(
                                        fontSize: 10.5,
                                        color:
                                            RenaultSportPalette.oemShiftGreen,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: primary.withValues(alpha: 0.55),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        hasSelectedDevice
                                            ? 'CAMBIAR'
                                            : 'ELEGIR',
                                        style: AppTheme.telemetryNumericStyle(
                                          fontSize: 11,
                                          color: primary,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Divider(height: 22),

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
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: RenaultSportPalette
                                                .revLimiterRed,
                                          ),
                                        ),
                                        child: Text(
                                          fault.code,
                                          style: AppTheme.telemetryNumericStyle(
                                            fontSize: 12,
                                            color: RenaultSportPalette
                                                .revLimiterRed,
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
                                child:
                                    Center(child: CircularProgressIndicator()),
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

/// Menú desplegable modal de dispositivos Bluetooth vinculados para OBD2 ELM327
class _BluetoothDevicesModalSheet extends ConsumerWidget {
  const _BluetoothDevicesModalSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adapterState = ref.watch(obdConnectionModeProvider);
    final obdNotifier = ref.read(obdConnectionModeProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;
    final isSimulator = adapterState.mode == ObdConnectionMode.trackSimulator;
    final devices = adapterState.pairedDevices;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.bluetooth_searching_rounded, color: primary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'DISPOSITIVOS BLUETOOTH (${devices.length})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.renaultSportHeaderStyle(
                              fontSize: 16,
                              color: primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Actualizar vinculados',
                        onPressed: obdNotifier.scanPairedBluetoothDevices,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ],
              ),
              const Text(
                'Elige tu adaptador OBD2 ELM327 vinculado para conectarlo por KWP2000 (10.4 kbps).',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: obdNotifier.openSystemBluetoothSettings,
                  icon: const Icon(Icons.settings_bluetooth_rounded, size: 17),
                  label: const Text('EMPAREJAR NUEVO EN ANDROID'),
                ),
              ),
              const Divider(height: 18),
              Expanded(
                child: devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bluetooth_disabled_rounded,
                              size: 40,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'No se encontraron adaptadores Bluetooth vinculados.\nToca "Emparejar nuevo en Android" (PIN: 1234 o 0000) y luego refresca esta lista.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: obdNotifier.openSystemBluetoothSettings,
                              icon: const Icon(Icons.settings_bluetooth_rounded,
                                  size: 18),
                              label: const Text('ABRIR AJUSTES BLUETOOTH'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: devices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final device = devices[idx];
                          final isSelected = device.macAddress ==
                                  adapterState.selectedMacAddress &&
                              !isSimulator;
                          return InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              obdNotifier.connectToBluetoothAdapter(
                                macAddress: device.macAddress,
                                deviceName: device.name,
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
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
                                        ? Icons.directions_car_filled_rounded
                                        : Icons.bluetooth_rounded,
                                    color: isSelected
                                        ? RenaultSportPalette.oemShiftGreen
                                        : primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                device.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                            ),
                                            if (device.looksLikeObdAdapter) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: primary.withValues(
                                                      alpha: 0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'OBD2',
                                                  style: AppTheme
                                                      .telemetryNumericStyle(
                                                    fontSize: 9.5,
                                                    color: primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          device.macAddress,
                                          style: AppTheme.telemetryNumericStyle(
                                            fontSize: 11.5,
                                            color: Colors.white60,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected && adapterState.isConnecting)
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: primary,
                                      ),
                                    )
                                  else if (isSelected &&
                                      adapterState.isConnected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: RenaultSportPalette.oemShiftGreen,
                                      size: 20,
                                    )
                                  else
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white54,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
