import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../auth_profile/providers/auth_profile_providers.dart';
import '../auth_profile/screens/pilot_profile_screen.dart';
import '../cloud_sync_fcm/blackbox_realtime_service.dart';
import '../digital_garage_payments/screens/digital_garage_screen.dart';
import '../map_track/track_map_screen.dart';
import '../multimedia/multimedia_hub_screen.dart';
import '../sensors/biometric_immobilizer_service.dart';
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
                  // 1. Barra Superior Compacta
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
                          isCompactPreview: false,
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

                  // 3. Dock Inferior Unificado (COCKPIT, TRACK, GARAGE, ACCOUNT, ECU + Logos Apps)
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
    final immobilizer = ref.watch(biometricImmobilizerProvider);
    final profile = ref.watch(pilotAuthProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final isSimulator = adapterState.mode == ObdConnectionMode.trackSimulator;

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
          // Marca RS Digital Cockpit
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

          // Controles rápidos alineados a la derecha
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón de Estado OBD2 (Lleva a la pestaña ECU para elegir adaptador)
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
                      color: (adapterState.isConnected
                              ? RenaultSportPalette.oemShiftGreen
                              : RenaultSportPalette.siriusLiquidYellow)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: adapterState.isConnected
                            ? RenaultSportPalette.oemShiftGreen
                            : RenaultSportPalette.siriusLiquidYellow,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSimulator
                              ? Icons.sports_motorsports_rounded
                              : (adapterState.isConnected
                                  ? Icons.bluetooth_connected_rounded
                                  : Icons.bluetooth_searching_rounded),
                          size: 15,
                          color: adapterState.isConnected
                              ? RenaultSportPalette.oemShiftGreen
                              : RenaultSportPalette.siriusLiquidYellow,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isSimulator
                              ? 'SIMULADOR'
                              : (adapterState.isConnected
                                  ? (adapterState.selectedDeviceName ?? 'OBD2 OK')
                                  : 'CONECTAR OBD2'),
                          style: AppTheme.telemetryNumericStyle(
                            fontSize: 11,
                            color: adapterState.isConnected
                                ? RenaultSportPalette.oemShiftGreen
                                : RenaultSportPalette.siriusLiquidYellow,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (isSimulator) ...[
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

                // Biometría
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Inmovilizador Biométrico',
                  onPressed: () {
                    final bio = ref.read(biometricImmobilizerProvider.notifier);
                    if (immobilizer.isImmobilizerUnlocked) {
                      bio.lockImmobilizer();
                    } else {
                      bio.authenticateDriver();
                    }
                  },
                  icon: Icon(
                    immobilizer.isImmobilizerUnlocked
                        ? Icons.fingerprint_rounded
                        : Icons.lock_outline_rounded,
                    size: 20,
                    color: immobilizer.isImmobilizerUnlocked
                        ? RenaultSportPalette.oemShiftGreen
                        : RenaultSportPalette.revLimiterRed,
                  ),
                ),

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
        // Columna Izquierda: Sensores K-Line + Blackbox Cloud
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

        // Columna Derecha: G-Force + Mini Mapa GPS
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
                child: TrackMapScreen(isCompactPreview: true),
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
            height: 240,
            child: TrackMapScreen(isCompactPreview: true),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionStats = ref.watch(telemetrySessionStatsProvider);
    final blackboxRecords = ref.watch(blackboxRealtimeProvider);
    final primary = Theme.of(context).colorScheme.primary;

    final metricsGrid = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PARÁMETROS MOTOR F4R',
              style: AppTheme.renaultSportHeaderStyle(
                fontSize: 13,
                color: primary,
              ),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 2.1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _KwpMetricTile(
                  label: 'TEMP MOTOR',
                  value: '${frame.coolantTempC.toStringAsFixed(0)} °C',
                  valueColor: frame.isEngineCold
                      ? RenaultSportPalette.coldEngineAmber
                      : RenaultSportPalette.oemShiftGreen,
                ),
                _KwpMetricTile(
                  label: 'ACELERADOR',
                  value: '${frame.throttleTps.toStringAsFixed(0)} %',
                  valueColor: primary,
                ),
                _KwpMetricTile(
                  label: 'PRESIÓN MAP',
                  value: '${frame.intakeMapKpa} kPa',
                  valueColor: RenaultSportPalette.siriusLiquidYellow,
                ),
                _KwpMetricTile(
                  label: 'AVANCE',
                  value: '${frame.timingAdvance.toStringAsFixed(1)}°',
                  valueColor: RenaultSportPalette.oemShiftGreen,
                ),
                _KwpMetricTile(
                  label: 'CARGA ECU',
                  value: '${frame.engineLoad.toStringAsFixed(0)} %',
                  valueColor: primary,
                ),
                _KwpMetricTile(
                  label: 'BATERÍA / IAT',
                  value:
                      '${frame.batteryVolts.toStringAsFixed(1)}V • ${frame.intakeAirTempC.toStringAsFixed(0)}°C',
                  valueColor: Colors.cyanAccent,
                ),
              ],
            ),
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
                  '${blackboxRecords.length} GUARDADAS',
                  style: AppTheme.telemetryNumericStyle(
                    fontSize: 10,
                    color: RenaultSportPalette.oemShiftGreen,
                  ),
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
                    value: '${sessionStats.bestZeroToHundredSec ?? 6.8}s',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => ref
                    .read(blackboxRealtimeProvider.notifier)
                    .syncCurrentSessionToCloud(),
                icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('GUARDAR SESIÓN'),
                ),
              ),
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

    return SingleChildScrollView(
      child: Column(
        children: [
          metricsGrid,
          const SizedBox(height: 8),
          blackboxCard,
        ],
      ),
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
