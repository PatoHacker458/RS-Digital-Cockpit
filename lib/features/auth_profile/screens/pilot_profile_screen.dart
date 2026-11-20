import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../cloud_sync_fcm/fcm_notification_service.dart';
import '../../digital_garage_payments/providers/payment_garage_providers.dart';
import '../providers/auth_profile_providers.dart';

/// Apartado **ACCOUNT**:
/// 1) Perfil del piloto y foto (editable en cuentas Email, bloqueada en Google/GitHub).
/// 2) Odómetro automático (OBD2 + GPS) con alertas funcionales de mantenimiento por kilometraje.
/// 3) Notificaciones del sistema Android (sin banner interno duplicado).
class PilotProfileScreen extends ConsumerWidget {
  const PilotProfileScreen({super.key});

  void _showSyncOdometerDialog(
    BuildContext context,
    FcmTopicsNotifier fcmNotifier,
    double currentKm,
  ) {
    var draftKm = currentKm.round().toString();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Sincronizar Odómetro del Clio'),
        content: TextFormField(
          initialValue: draftKm,
          keyboardType: TextInputType.number,
          onChanged: (v) => draftKm = v,
          decoration: const InputDecoration(
            labelText: 'Kilometraje actual del tablero (km)',
            suffixText: 'km',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(draftKm.trim());
              if (parsed != null && parsed >= 0) {
                fcmNotifier.updateVehicleOdometerKm(parsed);
              }
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(pilotAuthProvider);
    final authNotifier = ref.read(pilotAuthProvider.notifier);
    final formState = ref.watch(authUiFormProvider);
    final fcmTopics = ref.watch(fcmTopicsProvider);
    final fcmNotifier = ref.read(fcmTopicsProvider.notifier);
    final activePlan = ref.watch(
      digitalGaragePaymentProvider.select((s) => s.activeSubscription),
    );
    final hasMileageAlertsPlan = activePlan.unlocksMileageAlerts;
    final primary = Theme.of(context).colorScheme.primary;

    if (profile == null) {
      return const Center(child: Text('Sin sesión activa'));
    }

    final canEditAvatar = profile.canEditAvatar;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
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
                                      File(profile.localAvatarPath!)
                                          .existsSync()
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
                              color:
                                  canEditAvatar ? Colors.black : Colors.white,
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
                                  icon: const Icon(Icons.logout_rounded,
                                      size: 17),
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

              // 2. Odómetro Automático + Alertas Funcionales por Kilometraje
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.speed_rounded, color: primary),
                              const SizedBox(width: 8),
                              Text(
                                'ODÓMETRO AUTOMÁTICO Y MANTENIMIENTO',
                                style: AppTheme.renaultSportHeaderStyle(
                                  fontSize: 15,
                                  color: primary,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _showSyncOdometerDialog(
                              context,
                              fcmNotifier,
                              fcmTopics.vehicleOdometerKm,
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: const Text('AJUSTAR KM'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'KILOMETRAJE DETECTADO (GPS + OBD2)',
                                  style: TextStyle(fontSize: 10.5),
                                ),
                                Text(
                                  '${fcmTopics.vehicleOdometerKm.toStringAsFixed(1)} KM',
                                  style: AppTheme.digitalDisplayStyle(
                                    fontSize: 26,
                                    color: RenaultSportPalette.oemShiftGreen,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '+${fcmTopics.sessionDistanceKm.toStringAsFixed(2)} km hoy',
                                style: AppTheme.telemetryNumericStyle(
                                  fontSize: 12,
                                  color: primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      _ServiceMileageRow(
                        title: 'Cambio de Aceite 5W40 Sintético',
                        intervalKm: FcmTopicsState.kOilIntervalKm,
                        remainingKm: fcmTopics.kmUntilOilService,
                        onMarkDone: () =>
                            fcmNotifier.markServiceCompleted('oil'),
                      ),
                      const SizedBox(height: 10),
                      _ServiceMileageRow(
                        title: 'Bujías NGK PFR6E-10 y Filtros',
                        intervalKm: FcmTopicsState.kSparkPlugIntervalKm,
                        remainingKm: fcmTopics.kmUntilSparkPlugs,
                        onMarkDone: () =>
                            fcmNotifier.markServiceCompleted('plugs'),
                      ),
                      const SizedBox(height: 10),
                      _ServiceMileageRow(
                        title: 'Kit de Distribución + Polea VVT F4R',
                        intervalKm: FcmTopicsState.kTimingBeltIntervalKm,
                        remainingKm: fcmTopics.kmUntilTimingBelt,
                        onMarkDone: () =>
                            fcmNotifier.markServiceCompleted('belt'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 3. Notificaciones del Sistema (Solo notificación nativa Android, sin popup en app)
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
                            'NOTIFICACIONES DEL SISTEMA',
                            style: AppTheme.renaultSportHeaderStyle(
                              fontSize: 15,
                              color: primary,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                fcmNotifier.triggerSystemNotification(
                              title:
                                  'MANTENIMIENTO F4R (${fcmTopics.vehicleOdometerKm.round()} KM)',
                              body:
                                  'Aceite: ${fcmTopics.kmUntilOilService.round()} km restantes • Distribución: ${fcmTopics.kmUntilTimingBelt.round()} km.',
                              topic: 'clio_rs_maintenance',
                            ),
                            icon: const Icon(
                              Icons.notifications_active_rounded,
                              size: 16,
                            ),
                            label: const Text('PROBAR ALERTA'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          hasMileageAlertsPlan
                              ? 'Alertas automáticas por kilometraje'
                              : 'Alertas automáticas por kilometraje (Plan 2+)',
                        ),
                        subtitle: Text(
                          hasMileageAlertsPlan
                              ? 'Notifica automáticamente en Android al acercarse a cada servicio.'
                              : 'Activa Plan 2 o Plan 3 en Garage para recibir avisos automáticos por kilometraje.',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: hasMileageAlertsPlan &&
                            fcmTopics.maintenanceSubscribed,
                        onChanged: hasMileageAlertsPlan
                            ? (val) => fcmNotifier.toggleTopic(
                                  'clio_rs_maintenance',
                                  val,
                                )
                            : null,
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

class _ServiceMileageRow extends StatelessWidget {
  final String title;
  final double intervalKm;
  final double remainingKm;
  final VoidCallback onMarkDone;

  const _ServiceMileageRow({
    required this.title,
    required this.intervalKm,
    required this.remainingKm,
    required this.onMarkDone,
  });

  @override
  Widget build(BuildContext context) {
    final usedRatio =
        ((intervalKm - remainingKm) / intervalKm).clamp(0.0, 1.0);
    final isDue = remainingKm <= 0;
    final isSoon = remainingKm > 0 && remainingKm <= 500;
    final statusColor = isDue
        ? RenaultSportPalette.revLimiterRed
        : isSoon
            ? RenaultSportPalette.coldEngineAmber
            : RenaultSportPalette.oemShiftGreen;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDue || isSoon ? statusColor : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      isDue
                          ? 'VENCIDO por ${remainingKm.abs().round()} km'
                          : 'Faltan ${remainingKm.round()} km (cada ${intervalKm.round()} km)',
                      style: AppTheme.telemetryNumericStyle(
                        fontSize: 11,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onMarkDone,
                child: const Text('REGISTRAR HECHO'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usedRatio,
              minHeight: 6,
              color: statusColor,
              backgroundColor: Colors.white12,
            ),
          ),
        ],
      ),
    );
  }
}
