import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'fcm_notification_service.dart';

/// Listener Global de Notificaciones Push (FCM) activo en TODAS las pantallas de la app.
/// Envuelve la vista raíz del `MaterialApp` para desplegar un banner estilo HUD automotriz
/// cuando entra un mensaje en primer/segundo plano o desde Topics FCM.
class HudNotificationWrapper extends ConsumerWidget {
  final Widget child;

  const HudNotificationWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fcmState = ref.watch(fcmTopicsProvider);
    final banner = fcmState.activeHudBanner;

    return Stack(
      children: [
        child,
        if (banner != null)
          Positioned(
            top: 12,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xF5141820),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: RenaultSportPalette.sagemAmberOrange,
                          width: 2,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: RenaultSportPalette.sagemAmberOrange.withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  RenaultSportPalette.sagemAmberOrange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.campaign_rounded,
                              color: RenaultSportPalette.sagemAmberOrange,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: RenaultSportPalette.oemShiftGreen
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'FCM HUD // ${banner.topic.toUpperCase()}',
                                        style: AppTheme.telemetryNumericStyle(
                                          fontSize: 10,
                                          color: RenaultSportPalette.oemShiftGreen,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        banner.title,
                                        style: AppTheme.renaultSportHeaderStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  banner.body,
                                  style: const TextStyle(
                                    color: Color(0xFFE2E8F0),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                ref.read(fcmTopicsProvider.notifier).dismissHudBanner(),
                            icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

