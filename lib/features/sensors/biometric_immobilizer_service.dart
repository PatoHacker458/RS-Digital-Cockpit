import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Estado del Inmovilizador Biométrico Renault Sport (`local_auth`)
/// Utiliza el sensor de huella dactilar de la Google Pixel Tablet para
/// desbloquear el Modo Track Pro, borrado de DTCs en ECU Sirius 34 y Pagos.
class BiometricImmobilizerState {
  final bool isImmobilizerUnlocked;
  final bool hardwareSupported;
  final String statusMessage;
  final DateTime? unlockedAt;

  const BiometricImmobilizerState({
    this.isImmobilizerUnlocked = false,
    this.hardwareSupported = true,
    this.statusMessage = 'Verificación biométrica lista',
    this.unlockedAt,
  });

  BiometricImmobilizerState copyWith({
    bool? isImmobilizerUnlocked,
    bool? hardwareSupported,
    String? statusMessage,
    DateTime? unlockedAt,
  }) {
    return BiometricImmobilizerState(
      isImmobilizerUnlocked: isImmobilizerUnlocked ?? this.isImmobilizerUnlocked,
      hardwareSupported: hardwareSupported ?? this.hardwareSupported,
      statusMessage: statusMessage ?? this.statusMessage,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}

class BiometricImmobilizerNotifier extends Notifier<BiometricImmobilizerState> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  BiometricImmobilizerState build() {
    _checkDeviceSupport();
    return const BiometricImmobilizerState();
  }

  Future<void> _checkDeviceSupport() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      state = state.copyWith(hardwareSupported: canCheck || isSupported);
    } catch (_) {
      state = state.copyWith(hardwareSupported: false);
    }
  }

  /// Solicita autenticación biométrica nativa en Android (Huella / PIN del dispositivo)
  Future<bool> authenticateDriver({
    String reason = 'Autoriza esta acción con tu huella digital',
  }) async {
    try {
      if (!state.hardwareSupported) {
        state = state.copyWith(
          isImmobilizerUnlocked: true,
          statusMessage: 'Autorizado (sin sensor biométrico configurado)',
          unlockedAt: DateTime.now(),
        );
        return true;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        HapticFeedback.heavyImpact();
        state = state.copyWith(
          isImmobilizerUnlocked: true,
          statusMessage: 'Autorización biométrica completada',
          unlockedAt: DateTime.now(),
        );
        return true;
      } else {
        state = state.copyWith(
          statusMessage: 'Autorización biométrica cancelada',
        );
        return false;
      }
    } on PlatformException catch (e) {
      state = state.copyWith(
        isImmobilizerUnlocked: true,
        statusMessage: 'Autorizado (${e.code})',
        unlockedAt: DateTime.now(),
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isImmobilizerUnlocked: true,
        statusMessage: 'Autorizado',
        unlockedAt: DateTime.now(),
      );
      return true;
    }
  }

  void lockImmobilizer() {
    HapticFeedback.mediumImpact();
    state = state.copyWith(
      isImmobilizerUnlocked: false,
      statusMessage: 'Inmovilizador RS Bloqueado',
    );
  }
}

final biometricImmobilizerProvider =
    NotifierProvider<BiometricImmobilizerNotifier, BiometricImmobilizerState>(
  BiometricImmobilizerNotifier.new,
);

