import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../cloud_sync_fcm/fcm_notification_service.dart';
import '../providers/auth_profile_providers.dart';

/// Apartado **ACCOUNT**:
/// Perfil del piloto, gestión de avatar (habilitada para cuentas Email y bloqueada
/// para proveedores Google/GitHub) y notificaciones Push FCM.
class PilotProfileScreen extends ConsumerWidget {
  const PilotProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(pilotAuthProvider);
    final authNotifier = ref.read(pilotAuthProvider.notifier);
    final formState = ref.watch(authUiFormProvider);
    final fcmTopics = ref.watch(fcmTopicsProvider);
    final fcmNotifier = ref.read(fcmTopicsProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;

    if (profile == null) {
      return const Center(child: Text('Sin sesión activa'));
    }

    final canEditAvatar = profile.canEditAvatar;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Tarjeta de Cuenta y Avatar
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: canEditAvatar
                                    ? RenaultSportPalette.oemShiftGreen
                                    : RenaultSportPalette.coldEngineAmber,
                                width: 2.5,
                              ),
                            ),
                            child: ClipOval(
                              child: profile.localAvatarPath != null &&
                                      File(profile.localAvatarPath!).existsSync()
                                  ? Image.file(
                                      File(profile.localAvatarPath!),
                                      fit: BoxFit.cover,
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: profile.avatarUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => Icon(
                                        Icons.person_rounded,
                                        size: 42,
                                        color: primary,
                                      ),
                                    ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: canEditAvatar
                                  ? RenaultSportPalette.oemShiftGreen
                                  : const Color(0xFF334155),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              canEditAvatar
                                  ? Icons.camera_alt_rounded
                                  : Icons.lock_rounded,
                              size: 15,
                              color: canEditAvatar ? Colors.black : Colors.white,
                            ),
                          ),
                        ],
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.displayName,
                              style: AppTheme.renaultSportHeaderStyle(
                                fontSize: 20,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile.email,
                              style: AppTheme.telemetryNumericStyle(
                                fontSize: 13,
                                color: primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (canEditAvatar
                                        ? RenaultSportPalette.oemShiftGreen
                                        : RenaultSportPalette.coldEngineAmber)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                profile.providerBadgeLabel,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: canEditAvatar
                                      ? RenaultSportPalette.oemShiftGreen
                                      : RenaultSportPalette.coldEngineAmber,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: canEditAvatar
                                      ? authNotifier.pickAndUploadAvatar
                                      : null,
                                  icon: Icon(
                                    canEditAvatar
                                        ? Icons.photo_camera_rounded
                                        : Icons.lock_outline_rounded,
                                    size: 17,
                                  ),
                                  label: Text(
                                    canEditAvatar
                                        ? 'CAMBIAR FOTO'
                                        : 'FOTO VINCULADA A PROVEEDOR',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: authNotifier.signOut,
                                  icon: const Icon(Icons.logout_rounded, size: 17),
                                  label: const Text('CERRAR SESIÓN'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (formState.feedbackMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    formState.feedbackMessage!,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // 2. Notificaciones Push (FCM Topics)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
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
                            'NOTIFICACIONES Y ALERTAS (FCM)',
                            style: AppTheme.renaultSportHeaderStyle(
                              fontSize: 15,
                              color: primary,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => fcmNotifier.triggerSimulatedHudPush(
                              title: 'MANTENIMIENTO F4R',
                              body:
                                  'Revisión recomendada: kit de distribución y polea decaladora VVT.',
                              topic: 'clio_rs_maintenance',
                            ),
                            icon: const Icon(
                              Icons.notifications_active_rounded,
                              size: 16,
                            ),
                            label: const Text('PROBAR ALERTA HUD'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mantenimiento F4R'),
                        subtitle: const Text(
                          'Avisos de correa de distribución, VVT y servicio.',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: fcmTopics.maintenanceSubscribed,
                        onChanged: (val) =>
                            fcmNotifier.toggleTopic('clio_rs_maintenance', val),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Track Days & Eventos RS'),
                        subtitle: const Text(
                          'Convocatorias de circuito y salidas del club.',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: fcmTopics.trackDaysSubscribed,
                        onChanged: (val) =>
                            fcmNotifier.toggleTopic('track_day_events', val),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Nuevos Skins de Instrumentos'),
                        subtitle: const Text(
                          'Actualizaciones de carátulas para el tacómetro.',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: fcmTopics.otaThemesSubscribed,
                        onChanged: (val) =>
                            fcmNotifier.toggleTopic('ota_gauge_themes', val),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
