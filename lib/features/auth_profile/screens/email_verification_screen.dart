import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_profile_providers.dart';

/// Pantalla de verificación de correo para cuentas creadas con Email/Contraseña.
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.mark_email_unread_rounded,
                        size: 48,
                        color: RenaultSportPalette.coldEngineAmber,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'VERIFICA TU CORREO',
                        textAlign: TextAlign.center,
                        style: AppTheme.renaultSportHeaderStyle(
                          fontSize: 20,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Enviamos un enlace de confirmación a ${profile?.email ?? 'tu correo'}. Verifícalo para entrar a RS Digital Cockpit.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 18),
                      if (formState.feedbackMessage != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: (formState.isError
                                    ? RenaultSportPalette.revLimiterRed
                                    : RenaultSportPalette.oemShiftGreen)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            formState.feedbackMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: formState.isError
                                  ? RenaultSportPalette.revLimiterRed
                                  : RenaultSportPalette.oemShiftGreen,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: authNotifier.checkEmailVerificationStatus,
                        icon: const Icon(Icons.verified_user_rounded, size: 18),
                        label: const Text('YA VERIFIQUÉ MI CORREO'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: authNotifier.resendVerificationEmail,
                        icon: const Icon(Icons.forward_to_inbox_rounded, size: 18),
                        label: const Text('REENVIAR CORREO'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: authNotifier.signOut,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('CERRAR SESIÓN'),
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
