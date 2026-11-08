import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_profile_providers.dart';

/// Pantalla Obligatoria de Seguridad:
/// Bloquea el acceso al Dashboard si `user.emailVerified == false` (en cuentas de correo),
/// permitiendo reenviar el correo de confirmación y comprobar el estado en vivo.
class EmailVerificationScreen extends ConsumerWidget {
  const EmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(pilotAuthProvider);
    final formState = ref.watch(authUiFormProvider);
    final authNotifier = ref.read(pilotAuthProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.mark_email_unread_rounded,
                        size: 56,
                        color: RenaultSportPalette.coldEngineAmber,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'VERIFICACIÓN DE CORREO OBLIGATORIA',
                        textAlign: TextAlign.center,
                        style: AppTheme.renaultSportHeaderStyle(
                          fontSize: 22,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Por seguridad de la telemetría en la nube, el acceso al Cockpit del Clio RS 172 está bloqueado porque la cuenta (${profile?.email ?? ''}) tiene emailVerified == false.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      if (formState.feedbackMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: RenaultSportPalette.oemShiftGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            formState.feedbackMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: RenaultSportPalette.oemShiftGreen,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: authNotifier.checkEmailVerificationStatus,
                        icon: const Icon(Icons.verified_user_rounded),
                        label: const Text('YA VERIFIQUÉ MI CORREO (COMPROBAR ESTADO)'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: authNotifier.resendVerificationEmail,
                        icon: const Icon(Icons.forward_to_inbox_rounded),
                        label: const Text('REENVIAR CORREO DE CONFIRMACIÓN'),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: authNotifier.signOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('CERRAR SESIÓN / CAMBIAR PROVEEDOR'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

