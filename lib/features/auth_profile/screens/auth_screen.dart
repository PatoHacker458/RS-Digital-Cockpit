import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_profile_providers.dart';
import 'password_recovery_screen.dart';

/// Pantalla de Inicio de Sesión de RS Digital Cockpit (Email, Google, GitHub).
class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(authUiFormProvider);
    final formNotifier = ref.read(authUiFormProvider.notifier);
    final authNotifier = ref.read(pilotAuthProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.sports_motorsports_rounded,
                            color: primary,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RS DIGITAL COCKPIT',
                                  style: AppTheme.renaultSportHeaderStyle(
                                    fontSize: 20,
                                    color: primary,
                                  ),
                                ),
                                const Text(
                                  'Inicia sesión con tu cuenta de piloto',
                                  style: TextStyle(fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      if (formState.isRegisterMode) ...[
                        TextFormField(
                          initialValue: formState.pilotName,
                          onChanged: formNotifier.updatePilotName,
                          decoration: const InputDecoration(
                            labelText: 'Nombre o Apodo',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        initialValue: formState.email,
                        onChanged: formNotifier.updateEmail,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: formState.password,
                        onChanged: formNotifier.updatePassword,
                        obscureText: formState.obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: formNotifier.togglePasswordVisibility,
                            icon: Icon(
                              formState.obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const PasswordRecoveryScreen(),
                              ),
                            );
                          },
                          child: const Text('¿Olvidaste tu contraseña?'),
                        ),
                      ),
                      if (formState.feedbackMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: (formState.isError
                                    ? RenaultSportPalette.revLimiterRed
                                    : RenaultSportPalette.oemShiftGreen)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            formState.feedbackMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: formState.isError
                                  ? RenaultSportPalette.revLimiterRed
                                  : RenaultSportPalette.oemShiftGreen,
                            ),
                          ),
                        ),
                      ],
                      ElevatedButton(
                        onPressed: formState.isSubmitting
                            ? null
                            : () => authNotifier.signInOrRegisterWithEmail(
                                  email: formState.email,
                                  password: formState.password,
                                  displayName: formState.pilotName,
                                  isRegister: formState.isRegisterMode,
                                ),
                        child: Text(
                          formState.isRegisterMode
                              ? 'CREAR CUENTA'
                              : 'INICIAR SESIÓN',
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: formNotifier.toggleRegisterMode,
                        child: Text(
                          formState.isRegisterMode
                              ? '¿Ya tienes cuenta? Inicia sesión'
                              : '¿No tienes cuenta? Regístrate con correo',
                        ),
                      ),
                      const Divider(height: 24),
                      const Text(
                        'O CONTINÚA CON',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: formState.isSubmitting
                                  ? null
                                  : authNotifier.signInWithGoogle,
                              icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                              label: const Text('GOOGLE'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: formState.isSubmitting
                                  ? null
                                  : authNotifier.signInWithGitHub,
                              icon: const Icon(Icons.code_rounded, size: 18),
                              label: const Text('GITHUB'),
                            ),
                          ),
                        ],
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
