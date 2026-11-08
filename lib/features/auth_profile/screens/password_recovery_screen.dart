import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_profile_providers.dart';

/// Pantalla completa de Recuperación de Contraseña (`sendPasswordResetEmail`)
class PasswordRecoveryScreen extends ConsumerWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(authUiFormProvider);
    final formNotifier = ref.read(authUiFormProvider.notifier);
    final authNotifier = ref.read(pilotAuthProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('RECUPERACIÓN DE CREDENCIALES RS'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.lock_reset_rounded, size: 48, color: primary),
                    const SizedBox(height: 12),
                    Text(
                      'RESTABLECER CONTRASEÑA FIREBASE',
                      textAlign: TextAlign.center,
                      style: AppTheme.renaultSportHeaderStyle(
                        fontSize: 18,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Ingresa tu correo registrado para disparar sendPasswordResetEmail() desde Firebase Auth.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      initialValue: formState.email,
                      onChanged: formNotifier.updateEmail,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo del Piloto',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (formState.feedbackMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
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
                      onPressed: () => authNotifier.sendPasswordReset(formState.email),
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('ENVIAR CORREO DE RECUPERACIÓN'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

