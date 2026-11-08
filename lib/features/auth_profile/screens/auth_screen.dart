import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_profile_providers.dart';
import 'password_recovery_screen.dart';

/// Pantalla de Autenticación Renault Sport (Firebase Auth):
/// - Correo y Contraseña (`password`)
/// - Google Sign-In (`google.com`)
/// - GitHub OAuth (`github.com`)
/// Cumplimiento estricto: Gestión de estado 100% reactiva en Riverpod.
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
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_rounded, color: primary, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RENAULT SPORT TELEMETRY ID',
                                  style: AppTheme.renaultSportHeaderStyle(
                                    fontSize: 20,
                                    color: primary,
                                  ),
                                ),
                                const Text(
                                  'ECU Siemens Sirius 34 // Firebase Cloud Gate',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (formState.isRegisterMode) ...[
                        TextFormField(
                          initialValue: formState.pilotName,
                          onChanged: formNotifier.updatePilotName,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del Piloto',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        initialValue: formState.email,
                        onChanged: formNotifier.updateEmail,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo Electrónico',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
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
                      const SizedBox(height: 8),
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
                          padding: const EdgeInsets.all(12),
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
                      ElevatedButton.icon(
                        onPressed: () => authNotifier.signInOrRegisterWithEmail(
                          email: formState.email,
                          password: formState.password,
                          displayName: formState.pilotName,
                          isRegister: formState.isRegisterMode,
                        ),
                        icon: const Icon(Icons.key_rounded),
                        label: Text(
                          formState.isRegisterMode
                              ? 'REGISTRAR CUENTA EMAIL (REQUIERE VERIFICACIÓN)'
                              : 'ENTRAR CON CORREO Y CONTRASEÑA',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: formNotifier.toggleRegisterMode,
                        child: Text(
                          formState.isRegisterMode
                              ? '¿Ya tienes cuenta? Inicia sesión aquí'
                              : '¿Nuevo piloto? Regístrate con Correo (prueba bloqueo emailVerified=false)',
                        ),
                      ),
                      const Divider(height: 28),
                      const Text(
                        'PROVEEDORES FEDERADOS OAUTH 2.0 (AVATAR BLOQUEADO POR REGLA DE NEGOCIO):',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: authNotifier.signInWithGoogle,
                              icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                              label: const Text('GOOGLE SIGN-IN'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: authNotifier.signInWithGitHub,
                              icon: const Icon(Icons.code_rounded, size: 20),
                              label: const Text('GITHUB AUTH'),
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
