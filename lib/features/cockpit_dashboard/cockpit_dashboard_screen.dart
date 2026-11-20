import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../auth_profile/providers/auth_profile_providers.dart';
import '../auth_profile/screens/pilot_profile_screen.dart';
import '../cloud_sync_fcm/blackbox_realtime_service.dart';
import '../digital_garage_payments/providers/payment_garage_providers.dart';
import '../digital_garage_payments/screens/digital_garage_screen.dart';
import '../map_track/track_map_screen.dart';
import '../multimedia/multimedia_hub_screen.dart';
import '../telemetry/models/obd_telemetry_frame.dart';
import '../telemetry/providers/telemetry_providers.dart';
import '../telemetry/widgets/g_force_ball_widget.dart';
import '../telemetry/widgets/renault_sport_tachometer_widget.dart';
import 'widgets/dtc_diagnostic_sheet.dart';
import 'widgets/launcher_dock_widget.dart';

/// Pantalla Principal de **RS Digital Cockpit**.
/// Diseño 100% responsivo para tablets y teléfonos, libre de desbordamientos.
class CockpitDashboardScreen extends ConsumerWidget {
  const CockpitDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetryAsync = ref.watch(obdTelemetryStreamProvider);
    final frame = telemetryAsync.valueOrNull ??
        ObdTelemetryFrame.initial(isSimulator: false);
    final activeTab = ref.watch(cockpitTabProvider);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTabletLandscape =
                constraints.maxWidth >= 840 && constraints.maxHeight >= 480;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTabletLandscape ? 14 : 10,
                vertical: 8,
              ),
              child: Column(
                children: [
                  // 1. Barra Superior Compacta (sin inmovilizador)
                  _CockpitTopHeaderBar(frame: frame),
                  const SizedBox(height: 8),

                  // 2. Contenido Principal Responsivo
                  Expanded(
                    child: switch (activeTab) {
                      CockpitSectionTab.cockpitHud => isTabletLandscape
                          ? _TabletThreeColumnCockpitView(frame: frame)
                          : _CompactScrollableCockpitView(frame: frame),
                      CockpitSectionTab.multimediaHub =>
                        const MultimediaHubScreen(),
                      CockpitSectionTab.trackMapGps => const TrackMapScreen(
                          isMiniLiveMap: false,
                        ),
                      CockpitSectionTab.digitalGarage =>
                        const DigitalGarageScreen(),
                      CockpitSectionTab.pilotProfile =>
                        const PilotProfileScreen(),
                      CockpitSectionTab.ecuDiagnostics =>
                        const DtcDiagnosticSheet(),
                    },
                  ),
                  const SizedBox(height: 8),

                  // 3. Dock Inferior Centrado (COCKPIT, MULTIMEDIA, TRACK, GARAGE, ACCOUNT, ECU)
                  const LauncherDockWidget(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CockpitTopHeaderBar extends ConsumerWidget {
  final ObdTelemetryFrame frame;

  const _CockpitTopHeaderBar({required this.frame});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adapterState = ref.watch(obdConnectionModeProvider);
    final obdNotifier = ref.read(obdConnectionModeProvider.notifier);
    final themeMode = ref.watch(themeModeProvider);
    final profile = ref.watch(pilotAuthProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final isSimulator = adapterState.mode == ObdConnectionMode.trackSimulator;

    final Color obdBadgeColor;
    final String obdBadgeLabel;
    final IconData obdBadgeIcon;

    if (!adapterState.ecuEnabled) {
      obdBadgeColor = Colors.grey;
      obdBadgeLabel = 'ECU OFF';
      obdBadgeIcon = Icons.bluetooth_disabled_rounded;
    } else if (isSimulator) {
      obdBadgeColor = RenaultSportPalette.oemShiftGreen;
      obdBadgeLabel = 'SIMULADOR';
      obdBadgeIcon = Icons.sports_motorsports_rounded;
    } else if (adapterState.isConnected) {
      obdBadgeColor = RenaultSportPalette.oemShiftGreen;
      obdBadgeLabel = adapterState.selectedDeviceName ?? 'OBD2 OK';
      obdBadgeIcon = Icons.bluetooth_connected_rounded;
    } else {
      obdBadgeColor = RenaultSportPalette.siriusLiquidYellow;
      obdBadgeLabel = 'CONECTAR OBD2';
      obdBadgeIcon = Icons.bluetooth_searching_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primary.withValues(alpha: 0.4),
          width: 1.1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'RS',
              style: AppTheme.renaultSportHeaderStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'RS DIGITAL COCKPIT',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.renaultSportHeaderStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón de Estado OBD2 / ECU ON-OFF
                InkWell(
                  onTap: () => ref
                      .read(cockpitTabProvider.notifier)
                      .selectTab(CockpitSectionTab.ecuDiagnostics),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: obdBadgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: obdBadgeColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(obdBadgeIcon, size: 15, color: obdBadgeColor),
                        const SizedBox(width: 6),
                        Text(
                          obdBadgeLabel,
                          style: AppTheme.telemetryNumericStyle(
                            fontSize: 11,
                            color: obdBadgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (isSimulator && adapterState.ecuEnabled) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: obdNotifier.toggleSimulatorEngineWarmth,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: (frame.isEngineCold
                                ? RenaultSportPalette.coldEngineAmber
                                : RenaultSportPalette.oemShiftGreen)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: frame.isEngineCold
                              ? RenaultSportPalette.coldEngineAmber
                              : RenaultSportPalette.oemShiftGreen,
                        ),
                      ),
                      child: Text(
                        '${frame.coolantTempC.toStringAsFixed(0)}°C',
                        style: AppTheme.telemetryNumericStyle(
                          fontSize: 11,
                          color: frame.isEngineCold
                              ? RenaultSportPalette.coldEngineAmber
                              : RenaultSportPalette.oemShiftGreen,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 6),

                // Tema Oscuro / Claro
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Cambiar Tema',
                  onPressed: () =>
                      ref.read(themeModeProvider.notifier).toggleTheme(),
                  icon: Icon(
                    themeMode == ThemeMode.dark
                        ? Icons.wb_sunny_rounded
                        : Icons.nightlight_round,
                    size: 19,
                    color: primary,
                  ),
                ),

                // Avatar del Piloto
                if (profile != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => ref
                        .read(cockpitTabProvider.notifier)
                        .selectTab(CockpitSectionTab.pilotProfile),
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: primary,
                      child: ClipOval(
                        child: profile.localAvatarPath != null &&
                                File(profile.localAvatarPath!).existsSync()
                            ? Image.file(
                                File(profile.localAvatarPath!),
                                width: 28,
                                height: 28,
                                fit: BoxFit.cover,
                              )
                            : CachedNetworkImage(
                                imageUrl: profile.avatarUrl,
                                width: 28,
                                height: 28,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    const Icon(Icons.person, size: 16),
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletThreeColumnCockpitView extends StatelessWidget {
  final ObdTelemetryFrame frame;

  const _TabletThreeColumnCockpitView({required this.frame});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Columna Izquierda: Sensores K-Line + Blackbox Cloud con visor de sesiones
        Expanded(
          flex: 3,
          child: _Sirius34TelemetryColumn(frame: frame),
        ),
        const SizedBox(width: 10),

        // Columna Central: Tacómetro 120 FPS
        Expanded(
          flex: 5,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: RenaultSportTachometerWidget(frame: frame),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Columna Derecha: G-Force (con Calibrar) + Mini Google Maps en Tiempo Real
        const Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(
                flex: 5,
                child: GForceBallWidget(),
              ),
              SizedBox(height: 8),
              Expanded(
                flex: 5,
                child: TrackMapScreen(isMiniLiveMap: true),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactScrollableCockpitView extends StatelessWidget {
  final ObdTelemetryFrame frame;

  const _CompactScrollableCockpitView({required this.frame});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 310,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: RenaultSportTachometerWidget(frame: frame),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _Sirius34TelemetryColumn(frame: frame, isScrollableMode: true),
          const SizedBox(height: 10),
          const SizedBox(
            height: 250,
            child: GForceBallWidget(),
          ),
          const SizedBox(height: 10),
          const SizedBox(
            height: 220,
            child: TrackMapScreen(isMiniLiveMap: true),
          ),
        ],
      ),
    );
  }
}

class _Sirius34TelemetryColumn extends ConsumerWidget {
  final ObdTelemetryFrame frame;
  final bool isScrollableMode;

  const _Sirius34TelemetryColumn({
    required this.frame,
    this.isScrollableMode = false,
  });

  void _openBlackboxHistorySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _BlackboxSessionsModalSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionStats = ref.watch(telemetrySessionStatsProvider);
    final blackboxRecords = ref.watch(blackboxRealtimeProvider);
    final activePlan = ref.watch(
      digitalGaragePaymentProvider.select((s) => s.activeSubscription),
    );
    final hasExtendedPids = activePlan.unlocksExtendedSiriusPids;
    final primary = Theme.of(context).colorScheme.primary;

    final tileCoolant = _KwpMetricTile(
      label: 'TEMP MOTOR',
      value: '${frame.coolantTempC.toStringAsFixed(0)} °C',
      valueColor: frame.isEngineCold
          ? RenaultSportPalette.coldEngineAmber
          : RenaultSportPalette.oemShiftGreen,
    );
    final tileTps = _KwpMetricTile(
      label: 'ACELERADOR',
      value: '${frame.throttleTps.toStringAsFixed(0)} %',
      valueColor: primary,
    );
    final tileMap = _KwpMetricTile(
      label: 'PRESIÓN MAP',
      value: hasExtendedPids ? '${frame.intakeMapKpa} kPa' : 'PLAN 2+',
      valueColor: hasExtendedPids
          ? RenaultSportPalette.siriusLiquidYellow
          : Colors.white38,
    );
    final tileAdvance = _KwpMetricTile(
      label: 'AVANCE',
      value: hasExtendedPids
          ? '${frame.timingAdvance.toStringAsFixed(1)}°'
          : 'PLAN 2+',
      valueColor:
          hasExtendedPids ? RenaultSportPalette.oemShiftGreen : Colors.white38,
    );
    final tileLoad = _KwpMetricTile(
      label: 'CARGA ECU',
      value: hasExtendedPids
          ? '${frame.engineLoad.toStringAsFixed(0)} %'
          : 'PLAN 2+',
      valueColor: hasExtendedPids ? primary : Colors.white38,
    );
    final tileBatteryIat = _KwpMetricTile(
      label: 'BATERÍA / IAT',
      value:
          '${frame.batteryVolts.toStringAsFixed(1)}V • ${frame.intakeAirTempC.toStringAsFixed(0)}°C',
      valueColor: Colors.cyanAccent,
    );

    final Widget metricsGrid = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'PARÁMETROS MOTOR F4R',
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.renaultSportHeaderStyle(
                      fontSize: 13,
                      color: primary,
                    ),
                  ),
                ),
                if (!hasExtendedPids)
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: Colors.white54,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (isScrollableMode)
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 2.0,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  tileCoolant,
                  tileTps,
                  tileMap,
                  tileAdvance,
                  tileLoad,
                  tileBatteryIat,
                ],
              )
            else ...[
              // En modo Tablet apaisado: expandir uniformemente las 3 filas
              // para que no quede espacio en blanco debajo de Blackbox Cloud
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tileCoolant),
                    const SizedBox(width: 6),
                    Expanded(child: tileTps),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tileMap),
                    const SizedBox(width: 6),
                    Expanded(child: tileAdvance),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tileLoad),
                    const SizedBox(width: 6),
                    Expanded(child: tileBatteryIat),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final blackboxCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'BLACKBOX CLOUD',
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.renaultSportHeaderStyle(
                      fontSize: 12.5,
                      color: RenaultSportPalette.siriusLiquidYellow,
                    ),
                  ),
                ),
                Text(
                  '${blackboxRecords.length} guardadas',
                  style: const TextStyle(fontSize: 10.5, color: Colors.white60),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _PeakStatColumn(
                    label: 'PEAK RPM',
                    value: '${sessionStats.peakRpm.round()}',
                  ),
                  const SizedBox(width: 18),
                  _PeakStatColumn(
                    label: 'MAX KM/H',
                    value: '${sessionStats.maxSpeedKmh}',
                  ),
                  const SizedBox(width: 18),
                  _PeakStatColumn(
                    label: '0-100 KM/H',
                    value: sessionStats.bestZeroToHundredSec != null
                        ? '${sessionStats.bestZeroToHundredSec}s'
                        : '--',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => ref
                          .read(blackboxRealtimeProvider.notifier)
                          .syncCurrentSessionToCloud(),
                      icon: const Icon(Icons.cloud_upload_rounded, size: 15),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('GUARDAR'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _openBlackboxHistorySheet(context),
                      icon: const Icon(Icons.history_rounded, size: 15),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('HISTORIAL'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (isScrollableMode) {
      return Column(
        children: [
          metricsGrid,
          const SizedBox(height: 8),
          blackboxCard,
        ],
      );
    }

    // Columna de altura completa: Parámetros se expande y Blackbox Cloud toca abajo sin hueco
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: metricsGrid),
        const SizedBox(height: 8),
        blackboxCard,
      ],
    );
  }
}

/// Visor modal de sesiones guardadas en Blackbox Cloud (Firebase + Local)
class _BlackboxSessionsModalSheet extends ConsumerWidget {
  const _BlackboxSessionsModalSheet();

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year} • $h:$min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(blackboxRealtimeProvider);
    final notifier = ref.read(blackboxRealtimeProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;

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
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_done_rounded,
                        color: RenaultSportPalette.siriusLiquidYellow,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'HISTORIAL BLACKBOX CLOUD (${sessions.length})',
                        style: AppTheme.renaultSportHeaderStyle(
                          fontSize: 16,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Sincronizar desde Firebase',
                        onPressed: notifier.refreshFromCloud,
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
                'Cada sesión guarda los valores máximos registrados en tu recorrido (RPM pico, velocidad máxima, temperatura máxima y códigos DTC).',
                style: TextStyle(fontSize: 12),
              ),
              const Divider(height: 18),
              Expanded(
                child: sessions.isEmpty
                    ? const Center(
                        child: Text(
                          'Todavía no has guardado sesiones en Blackbox Cloud.\nPresiona "GUARDAR" en Cockpit al finalizar tu recorrido.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final rec = sessions[idx];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _formatDate(rec.syncedAt),
                                          style: AppTheme.renaultSportHeaderStyle(
                                            fontSize: 13.5,
                                            color: primary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (rec.syncedToFirebase
                                                  ? RenaultSportPalette
                                                      .oemShiftGreen
                                                  : RenaultSportPalette
                                                      .coldEngineAmber)
                                              .withValues(alpha: 0.16),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          rec.syncedToFirebase
                                              ? 'FIREBASE OK'
                                              : 'LOCAL',
                                          style: AppTheme.telemetryNumericStyle(
                                            fontSize: 9.5,
                                            color: rec.syncedToFirebase
                                                ? RenaultSportPalette
                                                    .oemShiftGreen
                                                : RenaultSportPalette
                                                    .coldEngineAmber,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'Eliminar sesión',
                                        onPressed: () => notifier
                                            .deleteSession(rec.sessionId),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    children: [
                                      _PeakStatColumn(
                                        label: 'PEAK RPM',
                                        value: '${rec.peakRpm.round()}',
                                      ),
                                      _PeakStatColumn(
                                        label: 'MAX VEL',
                                        value: '${rec.maxSpeedKmh} km/h',
                                      ),
                                      _PeakStatColumn(
                                        label: 'TEMP MÁX',
                                        value:
                                            '${rec.maxCoolantTempC.toStringAsFixed(0)} °C',
                                      ),
                                      _PeakStatColumn(
                                        label: '0-100 KM/H',
                                        value: rec.zeroToHundredSec != null
                                            ? '${rec.zeroToHundredSec}s'
                                            : '--',
                                      ),
                                      _PeakStatColumn(
                                        label: 'FALLAS DTC',
                                        value: '${rec.dtcCount}',
                                      ),
                                    ],
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

class _KwpMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _KwpMetricTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTheme.telemetryNumericStyle(
                fontSize: 14,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeakStatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _PeakStatColumn({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 9)),
        Text(
          value,
          style: AppTheme.telemetryNumericStyle(
            fontSize: 13.5,
            color: RenaultSportPalette.oemShiftGreen,
          ),
        ),
      ],
    );
  }
}
