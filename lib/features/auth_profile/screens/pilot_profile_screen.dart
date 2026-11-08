import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../cloud_sync_fcm/fcm_notification_service.dart';
import '../providers/auth_profile_providers.dart';

/// Pantalla de Perfil del Piloto + Regla de Negocio Estricta de Avatar + Topics FCM.
/// Verifica `user.providerData`:
/// - Si es `password`: Habilita botón de `image_picker` y subida a Firebase Storage.
/// - Si es `google.com` o `github.com`: Bloquea edición y muestra badge informativo
///   ("Avatar gestionado por Google/GitHub").
/// Utiliza `CachedNetworkImage` y caché en disco local para soporte 100% offline.
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
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Tarjeta Principal de Identidad del Piloto & Regla de Avatar
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 20,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Avatar con CachedNetworkImage + soporte de archivo local offline
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: canEditAvatar
                                    ? RenaultSportPalette.oemShiftGreen
                                    : RenaultSportPalette.coldEngineAmber,
                                width: 3,
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
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      errorWidget: (_, __, ___) => Icon(
                                        Icons.sports_motorsports_rounded,
                                        size: 48,
                                        color: primary,
                                      ),
                                    ),
                            ),
                          ),
                          // Ícono de cámara o candado según proveedor de autenticación
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: canEditAvatar
                                  ? RenaultSportPalette.oemShiftGreen
                                  : const Color(0xFF334155),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              canEditAvatar ? Icons.camera_alt_rounded : Icons.lock_rounded,
                              size: 18,
                              color: canEditAvatar ? Colors.black : Colors.white,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(
                        width: 560,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.displayName,
                              style: AppTheme.renaultSportHeaderStyle(
                                fontSize: 22,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${profile.email}  •  VIN: ${profile.chassisNumber}',
                              style: AppTheme.telemetryNumericStyle(
                                fontSize: 13,
                                color: primary,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Badge informativo de la Regla de Negocio Estricta
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: (canEditAvatar
                                        ? RenaultSportPalette.oemShiftGreen
                                        : RenaultSportPalette.coldEngineAmber)
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: canEditAvatar
                                      ? RenaultSportPalette.oemShiftGreen
                                      : RenaultSportPalette.coldEngineAmber,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    canEditAvatar
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.verified_user_outlined,
                                    size: 16,
                                    color: canEditAvatar
                                        ? RenaultSportPalette.oemShiftGreen
                                        : RenaultSportPalette.coldEngineAmber,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      profile.providerBadgeLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: canEditAvatar
                                            ? RenaultSportPalette.oemShiftGreen
                                            : RenaultSportPalette.coldEngineAmber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Botón de subir foto (SOLO HABILITADO SI providerData == 'password')
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                ElevatedButton.icon(
                                  onPressed:
                                      canEditAvatar ? authNotifier.pickAndUploadAvatar : null,
                                  icon: Icon(
                                    canEditAvatar
                                        ? Icons.cloud_upload_rounded
                                        : Icons.block_rounded,
                                  ),
                                  label: Text(
                                    canEditAvatar
                                        ? 'SUBIR FOTO A FIREBASE STORAGE'
                                        : 'AVATAR GESTIONADO POR GOOGLE/GITHUB',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: authNotifier.toggleEmailVerifiedForDemo,
                                  icon: const Icon(Icons.security_rounded, size: 18),
                                  label: const Text('SIMULAR BLOQUEO EMAIL NO VERIFICADO'),
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(formState.feedbackMessage!),
                ),
              ],

              const SizedBox(height: 16),

              // 2. Conmutador Rápido de Proveedores para Demostración en Clase
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AUDITORÍA DE PROVEEDORES FIREBASE AUTH (PRUEBA EN VIVO DE REGLA DE AVATAR)',
                        style: AppTheme.renaultSportHeaderStyle(
                          fontSize: 15,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Alterna entre los 3 métodos de autenticación requeridos para comprobar cómo `user.providerData` habilita o bloquea la subida de foto a Firebase Storage:',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => authNotifier.signInOrRegisterWithEmail(
                              email: 'piloto.rs172@renaultsport.fr',
                              password: 'Clio172F4R!',
                              displayName: 'Jean Ragnotti // Clio 172 #04',
                              isRegister: false,
                            ),
                            icon: const Icon(Icons.email_rounded),
                            label: const Text('1. PROBAR CUENTA EMAIL (EDICIÓN ACTIVA)'),
                          ),
                          OutlinedButton.icon(
                            onPressed: authNotifier.signInWithGoogle,
                            icon: const Icon(Icons.g_mobiledata_rounded),
                            label: const Text('2. PROBAR GOOGLE SIGN-IN (BLOQUEADO)'),
                          ),
                          OutlinedButton.icon(
                            onPressed: authNotifier.signInWithGitHub,
                            icon: const Icon(Icons.code_rounded),
                            label: const Text('3. PROBAR GITHUB AUTH (BLOQUEADO)'),
                          ),
                          TextButton.icon(
                            onPressed: authNotifier.signOut,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('CERRAR SESIÓN'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. Suscripción a Temas de Firebase Cloud Messaging (FCM Topics)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SUSCRIPCIÓN A TEMAS PUSH (FIREBASE CLOUD MESSAGING TOPICS)',
                            style: AppTheme.renaultSportHeaderStyle(
                              fontSize: 15,
                              color: primary,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => fcmNotifier.triggerSimulatedHudPush(
                              title: 'ALERTA CORREA DISTRIBUCIÓN F4R 736',
                              body:
                                  'Intervalo Renault Sport: Revisar kit de distribución y polea decaladora VVT cada 60,000 km o 4 años.',
                              topic: 'clio_rs_maintenance',
                            ),
                            icon: const Icon(Icons.notifications_active_rounded, size: 18),
                            label: const Text('DISPARAR PUSH HUD DE PRUEBA'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        title: const Text('Alertas de Mantenimiento F4R (clio_rs_maintenance)'),
                        subtitle: const Text(
                          'Avisos de correa de distribución, decalador VVT y aceite Elf Evolution 900 SXR 5W40.',
                        ),
                        value: fcmTopics.maintenanceSubscribed,
                        onChanged: (val) =>
                            fcmNotifier.toggleTopic('clio_rs_maintenance', val),
                      ),
                      SwitchListTile(
                        title: const Text('Eventos y Track Days (track_day_events)'),
                        subtitle: const Text(
                          'Convocatorias de circuito Club Renault Sport y telemetría compartida.',
                        ),
                        value: fcmTopics.trackDaysSubscribed,
                        onChanged: (val) => fcmNotifier.toggleTopic('track_day_events', val),
                      ),
                      SwitchListTile(
                        title: const Text('Nuevos Diseños de Instrumentos OTA (ota_gauge_themes)'),
                        subtitle: const Text(
                          'Notificaciones de nuevos skins de tacómetro Sagem / Clio V6 / Ragnotti.',
                        ),
                        value: fcmTopics.otaThemesSubscribed,
                        onChanged: (val) => fcmNotifier.toggleTopic('ota_gauge_themes', val),
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

