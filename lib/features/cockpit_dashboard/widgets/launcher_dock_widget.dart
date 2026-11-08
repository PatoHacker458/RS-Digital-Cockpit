import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/launcher/car_launcher_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../cloud_sync_fcm/fcm_notification_service.dart';

/// Navegación principal de secciones dentro del Cockpit & Telemetry Hub
enum CockpitSectionTab {
  cockpitHud('COCKPIT 172', Icons.speed_rounded),
  trackMapGps('TRACK & PITS GPS', Icons.map_rounded),
  digitalGarage('GARAGE & PAGOS PRO', Icons.shopping_bag_rounded),
  pilotProfile('PILOTO & CLOUD', Icons.person_pin_rounded);

  final String label;
  final IconData icon;
  const CockpitSectionTab(this.label, this.icon);
}

class CockpitTabNotifier extends Notifier<CockpitSectionTab> {
  @override
  CockpitSectionTab build() => CockpitSectionTab.cockpitHud;

  void selectTab(CockpitSectionTab tab) => state = tab;
}

final cockpitTabProvider = NotifierProvider<CockpitTabNotifier, CockpitSectionTab>(
  CockpitTabNotifier.new,
);

/// Dock Inferior de Android 17 Car Launcher para Google Pixel Tablet (2560x1600):
/// - Pestañas de navegación rápida sin salir del Launcher.
/// - Lanzador rápido de aplicaciones externas (Spotify, Waze, Google Maps, YT Music)
///   mediante `MethodChannel` manteniendo viva la conexión OBD-II KWP2000.
class LauncherDockWidget extends ConsumerWidget {
  final VoidCallback onOpenDtcScanner;

  const LauncherDockWidget({
    super.key,
    required this.onOpenDtcScanner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(cockpitTabProvider);
    final tabNotifier = ref.read(cockpitTabProvider.notifier);
    final launcher = ref.read(carLauncherServiceProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141820) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? RenaultSportPalette.speedlineCardBorder
              : RenaultSportPalette.daylightBorder,
          width: 1.4,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Módulos internos de la Suite Clio RS 172
          Wrap(
            spacing: 8,
            children: CockpitSectionTab.values.map((tab) {
              final selected = tab == activeTab;
              return InkWell(
                onTap: () => tabNotifier.selectTab(tab),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? primary : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        size: 18,
                        color: selected
                            ? (isDark ? Colors.black : Colors.white)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab.label,
                        style: AppTheme.renaultSportHeaderStyle(
                          fontSize: 12,
                          color: selected
                              ? (isDark ? Colors.black : Colors.white)
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // 2. Botón Diagnóstico KWP2000 Sirius 34 (Modo 03 / Terminal Hex)
          OutlinedButton.icon(
            onPressed: onOpenDtcScanner,
            icon: const Icon(
              Icons.troubleshoot_rounded,
              size: 18,
              color: RenaultSportPalette.siriusLiquidYellow,
            ),
            label: Text(
              'ECU SIRIUS 34 DTC / K-LINE LOG',
              style: AppTheme.telemetryNumericStyle(
                fontSize: 11,
                color: RenaultSportPalette.siriusLiquidYellow,
              ),
            ),
          ),

          // 3. Lanzador Rápido de Apps de Cabina (Android 17 Pixel Tablet)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...CarLauncherService.kQuickCabinApps.map(
                (app) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ActionChip(
                    avatar: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: Text(
                      app.name,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () async {
                      final launched = await launcher.launchCabinApp(app);
                      if (!launched) {
                        ref.read(fcmTopicsProvider.notifier).triggerSimulatedHudPush(
                              title: 'ANDROID 17 CAR LAUNCHER DOCK',
                              body:
                                  'Intent enviado a ${app.name} (${app.packageName}). Telemetría KWP2000 activa en segundo plano.',
                              topic: 'car_launcher_dock',
                            );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Configurar como Android 17 Home Launcher predeterminado',
                onPressed: launcher.openAndroid17DefaultLauncherSelector,
                icon: Icon(Icons.home_max_rounded, color: primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
