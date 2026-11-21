import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth_profile/providers/auth_profile_providers.dart';
import '../../onboarding/onboarding_provider.dart';
import '../../splash/rs_splash_screen.dart';

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

/// Controla FLAG_KEEP_SCREEN_ON en Android: mantiene la pantalla encendida en
/// COCKPIT, MULTIMEDIA y ECU, y permite el reposo normal en el resto de vistas.
class ScreenWakeLockNotifier extends Notifier<bool> {
  static const MethodChannel _channel =
      MethodChannel('com.renaultsport.clio172/launcher');

  bool? _lastApplied;

  @override
  bool build() {
    final splashReady = ref.watch(splashBootProvider.select((s) => s.isReady));
    final onboardingCompleted =
        ref.watch(onboardingProvider.select((s) => s.isCompleted));
    final isAuthenticated = ref.watch(
      pilotAuthProvider
          .select((p) => p != null && !p.requiresEmailVerificationGate),
    );
    final activeTab = ref.watch(cockpitTabProvider);

    final shouldKeepOn = splashReady &&
        onboardingCompleted &&
        isAuthenticated &&
        (activeTab == CockpitSectionTab.cockpitHud ||
            activeTab == CockpitSectionTab.multimediaHub ||
            activeTab == CockpitSectionTab.ecuDiagnostics);

    if (_lastApplied != shouldKeepOn) {
      _lastApplied = shouldKeepOn;
      _applyWakeLock(shouldKeepOn);
    }

    return shouldKeepOn;
  }

  Future<void> _applyWakeLock(bool enabled) async {
    try {
      await _channel.invokeMethod<bool>(
        'setKeepScreenOn',
        <String, dynamic>{'enabled': enabled},
      );
    } catch (_) {}
  }
}

final screenWakeLockProvider = NotifierProvider<ScreenWakeLockNotifier, bool>(
  ScreenWakeLockNotifier.new,
);

/// Barra inferior limpia, centrada y responsiva para RS Digital Cockpit.
/// Cuando el ancho de pantalla no permite mostrar texto + icono sin desbordar,
/// cambia automáticamente a modo compacto de solo iconos para que todos quepan.
class LauncherDockWidget extends ConsumerWidget {
  const LauncherDockWidget({super.key});

  double _measureFullTabsWidth(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    var totalWidth = 0.0;
    for (final tab in CockpitSectionTab.values) {
      final painter = TextPainter(
        text: TextSpan(
          text: tab.label,
          style: AppTheme.renaultSportHeaderStyle(
            fontSize: 12.5,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();

      // margen horizontal (8) + borde (2) + padding interno (32) + icono (17) + espacio (6) + texto
      totalWidth += 8.0 + 2.0 + 32.0 + 17.0 + 6.0 + painter.width;
    }
    return totalWidth;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(cockpitTabProvider);
    final tabNotifier = ref.read(cockpitTabProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fullTabsWidth = _measureFullTabsWidth(context);

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final useIconOnlyMode = fullTabsWidth > (outerConstraints.maxWidth - 28.0);

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: useIconOnlyMode ? 8 : 14,
            vertical: 8,
          ),
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
          child: useIconOnlyMode
              ? Row(
                  children: CockpitSectionTab.values.map((tab) {
                    final selected = tab == activeTab;
                    final fgColor = selected
                        ? (isDark ? Colors.black : Colors.white)
                        : Theme.of(context).colorScheme.onSurface;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Tooltip(
                          message: tab.label,
                          child: InkWell(
                            onTap: () => tabNotifier.selectTab(tab),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: selected ? primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? primary
                                      : (isDark
                                          ? Colors.white12
                                          : Colors.black12),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  tab.icon,
                                  size: 21,
                                  color: fgColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                )
              : Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: CockpitSectionTab.values.map((tab) {
                      final selected = tab == activeTab;
                      final fgColor = selected
                          ? (isDark ? Colors.black : Colors.white)
                          : Theme.of(context).colorScheme.onSurface;
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
                                    : (isDark
                                        ? Colors.white12
                                        : Colors.black12),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tab.icon,
                                  size: 17,
                                  color: fgColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tab.label,
                                  style: AppTheme.renaultSportHeaderStyle(
                                    fontSize: 12.5,
                                    color: fgColor,
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
        );
      },
    );
  }
}
