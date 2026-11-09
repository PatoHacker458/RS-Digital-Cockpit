import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/launcher/car_launcher_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../cloud_sync_fcm/fcm_notification_service.dart';

/// Apartados principales del Dock: COCKPIT, MULTIMEDIA, TRACK, GARAGE, ACCOUNT, ECU
enum CockpitSectionTab {
  cockpitHud('COCKPIT', Icons.speed_rounded),
  multimediaHub('MULTIMEDIA', Icons.headphones_rounded),
  trackMapGps('TRACK', Icons.map_rounded),
  digitalGarage('GARAGE', Icons.shopping_bag_rounded),
  pilotProfile('ACCOUNT', Icons.person_rounded),
  ecuDiagnostics('ECU', Icons.memory_rounded);

  final String label;
  final IconData icon;
  const CockpitSectionTab(this.label, this.icon);
}

class CockpitTabNotifier extends Notifier<CockpitSectionTab> {
  @override
  CockpitSectionTab build() => CockpitSectionTab.cockpitHud;

  void selectTab(CockpitSectionTab tab) => state = tab;
}

final cockpitTabProvider =
    NotifierProvider<CockpitTabNotifier, CockpitSectionTab>(
  CockpitTabNotifier.new,
);

/// Barra inferior unificada para RS Digital Cockpit:
/// - Apartados: COCKPIT, TRACK, GARAGE, ACCOUNT, ECU
/// - Accesos directos a apps externas únicamente con su ícono/logo circular.
class LauncherDockWidget extends ConsumerWidget {
  const LauncherDockWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(cockpitTabProvider);
    final tabNotifier = ref.read(cockpitTabProvider.notifier);
    final launcher = ref.read(carLauncherServiceProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141820) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? RenaultSportPalette.speedlineCardBorder
              : RenaultSportPalette.daylightBorder,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // 1. Navegación principal (COCKPIT, TRACK, GARAGE, ACCOUNT, ECU)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: CockpitSectionTab.values.map((tab) {
                  final selected = tab == activeTab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => tabNotifier.selectTab(tab),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? primary : Colors.white12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab.icon,
                              size: 17,
                              color: selected
                                  ? (isDark ? Colors.black : Colors.white)
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tab.label,
                              style: AppTheme.renaultSportHeaderStyle(
                                fontSize: 12.5,
                                color: selected
                                    ? (isDark ? Colors.black : Colors.white)
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 2. Accesos directos a las apps solo con su logo circular
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...CarLauncherService.kQuickCabinApps.map(
                (app) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Tooltip(
                    message: app.name,
                    child: InkWell(
                      onTap: () async {
                        final launched = await launcher.launchCabinApp(app);
                        if (!launched) {
                          ref
                              .read(fcmTopicsProvider.notifier)
                              .triggerSimulatedHudPush(
                                title: app.name.toUpperCase(),
                                body: 'Abriendo ${app.name}...',
                                topic: 'launcher',
                              );
                        }
                      },
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: app.brandColor.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: app.brandColor.withValues(alpha: 0.75),
                            width: 1.3,
                          ),
                        ),
                        child: Icon(
                          app.icon,
                          size: 18,
                          color: app.brandColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Ajustes de Launcher Android',
                child: InkWell(
                  onTap: launcher.openAndroid17DefaultLauncherSelector,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: primary.withValues(alpha: 0.5)),
                    ),
                    child: Icon(
                      Icons.home_outlined,
                      size: 18,
                      color: primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
