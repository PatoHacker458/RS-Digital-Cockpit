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
import '../sensors/biometric_immobilizer_service.dart';
import '../telemetry/models/obd_telemetry_frame.dart';
import '../telemetry/providers/telemetry_providers.dart';
import '../telemetry/widgets/g_force_ball_widget.dart';
import '../telemetry/widgets/renault_sport_tachometer_widget.dart';
import 'widgets/dtc_diagnostic_sheet.dart';
import 'widgets/launcher_dock_widget.dart';

/// Dashboard Principal Responsivo del "Clio RS 172 Cockpit & Telemetry Hub".
/// - Ancho >= 840px (Google Pixel Tablet 2560x1600 en horizontal):
///   Dashboard apaisado de 3 columnas con tacómetro central gigante, telemetría
///   lateral KWP2000, fuerzas G, mini-mapa nativo y dock inferior de Car Launcher.
/// - Ancho < 840px (Modo Móvil):
///   Navegación inferior compacta con pestañas apiladas para usar desde el teléfono.
/// Cumplimiento estricto: Gestión 100% reactiva en Riverpod.
class CockpitDashboardScreen extends ConsumerWidget {
  const CockpitDashboardScreen({super.key});

  void _openDtcModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => const SizedBox(
        height: 520,
        child: DtcDiagnosticSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetryAsync = ref.watch(obdTelemetryStreamProvider);
    final frame = telemetryAsync.valueOrNull ?? ObdTelemetryFrame.initial();
    final activeTab = ref.watch(cockpitTabProvider);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTabletCockpit = constraints.maxWidth >= 840;

            if (isTabletCockpit) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  children: [
                    // 1. Cabecera Superior de Telemetría, Switch Simulador/ELM327 y Avatar
                    _CockpitTopHeaderBar(frame: frame),
                    const SizedBox(height: 10),

                    // 2. Cuerpo Principal según pestaña activa en el Dock
                    Expanded(
                      child: switch (activeTab) {
                        CockpitSectionTab.cockpitHud => _TabletThreeColumnCockpitView(
                            frame: frame,
                          ),
                        CockpitSectionTab.trackMapGps => const TrackMapScreen(
                            isCompactPreview: false,
                          ),
                        CockpitSectionTab.digitalGarage => const DigitalGarageScreen(),
                        CockpitSectionTab.pilotProfile => const PilotProfileScreen(),
                      },
                    ),
                    const SizedBox(height: 10),

                    // 3. Dock Inferior de Android 17 Car Launcher
                    LauncherDockWidget(
                      onOpenDtcScanner: () => _openDtcModal(context),
                    ),
                  ],
                ),
              );
            }

            // MODO MÓVIL COMPACTO (< 840px)
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: _CockpitTopHeaderBar(frame: frame, isCompact: true),
                ),
                Expanded(
                  child: switch (activeTab) {
                    CockpitSectionTab.cockpitHud => SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 360,
                              child: RenaultSportTachometerWidget(frame: frame),
                            ),
                            const SizedBox(height: 12),
                            _Sirius34TelemetryColumn(frame: frame),
                            const SizedBox(height: 12),
                            const SizedBox(height: 280, child: GForceBallWidget()),
                          ],
                        ),
                      ),
                    CockpitSectionTab.trackMapGps => const TrackMapScreen(
                        isCompactPreview: false,
                      ),
                    CockpitSectionTab.digitalGarage => const DigitalGarageScreen(),
                    CockpitSectionTab.pilotProfile => const PilotProfileScreen(),
                  },
                ),
                NavigationBar(
                  selectedIndex: CockpitSectionTab.values.indexOf(activeTab),
                  onDestinationSelected: (idx) => ref
                      .read(cockpitTabProvider.notifier)
                      .selectTab(CockpitSectionTab.values[idx]),
                  destinations: CockpitSectionTab.values
                      .map(
                        (t) => NavigationDestination(
                          icon: Icon(t.icon),
                          label: t.label,
                        ),
                      )
                      .toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CockpitTopHeaderBar extends ConsumerWidget {
  final ObdTelemetryFrame frame;
  final bool isCompact;

  const _CockpitTopHeaderBar({
    required this.frame,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionMode = ref.watch(obdConnectionModeProvider);
    final obdNotifier = ref.read(obdConnectionModeProvider.notifier);
    final themeMode = ref.watch(themeModeProvider);
    final immobilizer = ref.watch(biometricImmobilizerProvider);
    final profile = ref.watch(pilotAuthProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final isSimulator = connectionMode == ObdConnectionMode.trackSimulator;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primary.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Identificador Oficial Renault Sport Clio 172 Fase 2
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'RS 172',
                  style: AppTheme.renaultSportHeaderStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CLIO II SPORT 2.0 16V // SIEMENS SIRIUS 34',
                    style: AppTheme.renaultSportHeaderStyle(
                      fontSize: isCompact ? 13 : 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${frame.activeProtocol} • K-Line ${frame.kLineHz} Hz',
                    style: AppTheme.telemetryNumericStyle(
                      fontSize: 11,
                      color: RenaultSportPalette.oemShiftGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Controles en Caliente: Switch Simulador/Bluetooth, Temp Frío/Caliente, Biometría y Tema
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 1. Switch Polimórfico en Caliente: Simulador de Pista vs ELM327 Bluetooth Real
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isSimulator
                          ? RenaultSportPalette.siriusLiquidYellow
                          : RenaultSportPalette.oemShiftGreen)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSimulator
                        ? RenaultSportPalette.siriusLiquidYellow
                        : RenaultSportPalette.oemShiftGreen,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSimulator
                          ? Icons.sports_motorsports_rounded
                          : Icons.bluetooth_connected_rounded,
                      size: 16,
                      color: isSimulator
                          ? RenaultSportPalette.siriusLiquidYellow
                          : RenaultSportPalette.oemShiftGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isSimulator ? 'SIMULADOR PISTA' : 'ELM327 RFCOMM',
                      style: AppTheme.telemetryNumericStyle(
                        fontSize: 11,
                        color: isSimulator
                            ? RenaultSportPalette.siriusLiquidYellow
                            : RenaultSportPalette.oemShiftGreen,
                      ),
                    ),
                    Switch(
                      value: !isSimulator,
                      onChanged: (useRealBt) {
                        obdNotifier.setConnectionMode(
                          useRealBt
                              ? ObdConnectionMode.realElm327Bluetooth
                              : ObdConnectionMode.trackSimulator,
                        );
                      },
                    ),
                  ],
                ),
              ),

              // 2. Botón para conmutar en vivo Motor Frío (<75°C) vs Caliente (>=75°C) en clase
              if (isSimulator)
                ActionChip(
                  avatar: Icon(
                    Icons.thermostat_rounded,
                    size: 16,
                    color: frame.isEngineCold
                        ? RenaultSportPalette.coldEngineAmber
                        : RenaultSportPalette.oemShiftGreen,
                  ),
                  label: Text(
                    frame.isEngineCold
                        ? 'FRÍO ${frame.coolantTempC.toStringAsFixed(0)}°C (5K RPM)'
                        : 'CALIENTE ${frame.coolantTempC.toStringAsFixed(0)}°C (6.75K RPM)',
                    style: AppTheme.telemetryNumericStyle(
                      fontSize: 11,
                      color: frame.isEngineCold
                          ? RenaultSportPalette.coldEngineAmber
                          : RenaultSportPalette.oemShiftGreen,
                    ),
                  ),
                  onPressed: obdNotifier.toggleSimulatorEngineWarmth,
                ),

              // 3. Inmovilizador Biométrico (`local_auth`)
              ActionChip(
                avatar: Icon(
                  immobilizer.isImmobilizerUnlocked
                      ? Icons.fingerprint_rounded
                      : Icons.lock_outline_rounded,
                  size: 16,
                  color: immobilizer.isImmobilizerUnlocked
                      ? RenaultSportPalette.oemShiftGreen
                      : RenaultSportPalette.revLimiterRed,
                ),
                label: Text(
                  immobilizer.isImmobilizerUnlocked ? 'TRACK UNLOCKED' : 'INMOVILIZADOR',
                  style: AppTheme.telemetryNumericStyle(
                    fontSize: 11,
                    color: immobilizer.isImmobilizerUnlocked
                        ? RenaultSportPalette.oemShiftGreen
                        : RenaultSportPalette.revLimiterRed,
                  ),
                ),
                onPressed: () {
                  final bio = ref.read(biometricImmobilizerProvider.notifier);
                  if (immobilizer.isImmobilizerUnlocked) {
                    bio.lockImmobilizer();
                  } else {
                    bio.authenticateDriver();
                  }
                },
              ),

              // 4. Conmutador de Tema Dinámico (Night Stage Sagem vs Daylight Cup Mondial Blue)
              IconButton.outlined(
                tooltip: 'Cambiar Tema: Night Stage (Oscuro) / Daylight Cup (Claro)',
                onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
                icon: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.wb_sunny_rounded
                      : Icons.nightlight_round,
                  color: primary,
                ),
              ),

              // 5. Avatar del Piloto Sincronizado Dinámicamente (CachedNetworkImage + Offline)
              if (profile != null)
                InkWell(
                  onTap: () => ref
                      .read(cockpitTabProvider.notifier)
                      .selectTab(CockpitSectionTab.pilotProfile),
                  borderRadius: BorderRadius.circular(24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: primary,
                        child: ClipOval(
                          child: profile.localAvatarPath != null &&
                                  File(profile.localAvatarPath!).existsSync()
                              ? Image.file(
                                  File(profile.localAvatarPath!),
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  imageUrl: profile.avatarUrl,
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      const Icon(Icons.person, size: 18),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
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
        // COLUMNA IZQUIERDA (Flex 3): Cola de Prioridad KWP2000 & Blackbox Firebase Sync
        Expanded(
          flex: 3,
          child: _Sirius34TelemetryColumn(frame: frame),
        ),
        const SizedBox(width: 12),

        // COLUMNA CENTRAL (Flex 5): Tacómetro Sagem 120 FPS + Barra LED Shift-Light
        Expanded(
          flex: 5,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: RenaultSportTachometerWidget(frame: frame),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // COLUMNA DERECHA (Flex 3): Medidor G-Force Nativo + Mini-Mapa GPS Nativo
        const Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(
                flex: 5,
                child: GForceBallWidget(),
              ),
              SizedBox(height: 10),
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

class _Sirius34TelemetryColumn extends ConsumerWidget {
  final ObdTelemetryFrame frame;

  const _Sirius34TelemetryColumn({required this.frame});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionStats = ref.watch(telemetrySessionStatsProvider);
    final blackboxRecords = ref.watch(blackboxRealtimeProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        // Tarjeta de Parámetros de la Cola de Prioridad KWP2000
        Expanded(
          flex: 6,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TELEMETRÍA K-LINE SIRIUS 34',
                    style: AppTheme.renaultSportHeaderStyle(
                      fontSize: 14,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.65,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _KwpMetricTile(
                          pidCode: '0105 (LOW)',
                          label: 'REFRIGERANTE',
                          value: '${frame.coolantTempC.toStringAsFixed(1)} °C',
                          valueColor: frame.isEngineCold
                              ? RenaultSportPalette.coldEngineAmber
                              : RenaultSportPalette.oemShiftGreen,
                        ),
                        _KwpMetricTile(
                          pidCode: '0111 (HIGH)',
                          label: 'MARIPOSA TPS',
                          value: '${frame.throttleTps.toStringAsFixed(1)} %',
                          valueColor: primary,
                        ),
                        _KwpMetricTile(
                          pidCode: '010B (MED)',
                          label: 'COLECTOR MAP',
                          value: '${frame.intakeMapKpa} kPa',
                          valueColor: RenaultSportPalette.siriusLiquidYellow,
                        ),
                        _KwpMetricTile(
                          pidCode: '010E (MED)',
                          label: 'AVANCE ENC.',
                          value: '${frame.timingAdvance.toStringAsFixed(1)}°',
                          valueColor: RenaultSportPalette.oemShiftGreen,
                        ),
                        _KwpMetricTile(
                          pidCode: '0104 (MED)',
                          label: 'CARGA MOTOR',
                          value: '${frame.engineLoad.toStringAsFixed(0)} %',
                          valueColor: primary,
                        ),
                        _KwpMetricTile(
                          pidCode: 'ATRV / 010F',
                          label: 'VOLTS / IAT',
                          value:
                              '${frame.batteryVolts.toStringAsFixed(1)}V • ${frame.intakeAirTempC.toStringAsFixed(0)}°C',
                          valueColor: Colors.cyanAccent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Tarjeta "Blackbox Live" (Firebase Realtime Database Sync)
        Expanded(
          flex: 4,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FIREBASE BLACKBOX LIVE',
                        style: AppTheme.renaultSportHeaderStyle(
                          fontSize: 13,
                          color: RenaultSportPalette.siriusLiquidYellow,
                        ),
                      ),
                      Text(
                        '${blackboxRecords.length} SESIONES CLOUD',
                        style: AppTheme.telemetryNumericStyle(
                          fontSize: 10,
                          color: RenaultSportPalette.oemShiftGreen,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _PeakStatColumn(
                        label: 'PEAK RPM',
                        value: '${sessionStats.peakRpm.round()}',
                      ),
                      _PeakStatColumn(
                        label: 'MAX SPEED',
                        value: '${sessionStats.maxSpeedKmh} km/h',
                      ),
                      _PeakStatColumn(
                        label: '0-100 KM/H',
                        value: '${sessionStats.bestZeroToHundredSec ?? 6.85}s',
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => ref
                        .read(blackboxRealtimeProvider.notifier)
                        .syncCurrentSessionToCloud(),
                    icon: const Icon(Icons.cloud_upload_rounded, size: 17),
                    label: const Text(
                      'SINCRONIZAR TELEMETRÍA EN FIREBASE',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KwpMetricTile extends StatelessWidget {
  final String pidCode;
  final String label;
  final String value;
  final Color valueColor;

  const _KwpMetricTile({
    required this.pidCode,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700),
              ),
              Text(
                pidCode,
                style: AppTheme.telemetryNumericStyle(
                  fontSize: 8.5,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTheme.telemetryNumericStyle(
              fontSize: 15,
              color: valueColor,
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
      children: [
        Text(label, style: const TextStyle(fontSize: 9.5)),
        Text(
          value,
          style: AppTheme.telemetryNumericStyle(
            fontSize: 14,
            color: RenaultSportPalette.oemShiftGreen,
          ),
        ),
      ],
    );
  }
}
