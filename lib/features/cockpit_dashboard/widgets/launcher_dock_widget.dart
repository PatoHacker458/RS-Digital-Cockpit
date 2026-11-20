import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

/// Apartados principales centrados en la barra inferior:
/// COCKPIT, MULTIMEDIA, TRACK, GARAGE, ACCOUNT, ECU
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

/// Barra inferior limpia y centrada para RS Digital Cockpit
class LauncherDockWidget extends ConsumerWidget {
  const LauncherDockWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(cockpitTabProvider);
    final tabNotifier = ref.read(cockpitTabProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
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
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: CockpitSectionTab.values.map((tab) {
              final selected = tab == activeTab;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => tabNotifier.selectTab(tab),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? primary
                            : (isDark ? Colors.white12 : Colors.black12),
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
    );
  }
}
