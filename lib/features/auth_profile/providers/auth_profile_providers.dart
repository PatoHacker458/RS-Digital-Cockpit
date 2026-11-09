import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pilot_profile.dart';

/// Estado del formulario de inicio de sesión / registro.
class AuthUiFormState {
  final String email;
  final String password;
  final String pilotName;
  final bool isRegisterMode;
  final bool obscurePassword;
  final bool isSubmitting;
  final String? feedbackMessage;
  final bool isError;

  const AuthUiFormState({
    this.email = '',
    this.password = '',
    this.pilotName = '',
    this.isRegisterMode = false,
    this.obscurePassword = true,
    this.isSubmitting = false,
    this.feedbackMessage,
    this.isError = false,
  });

  AuthUiFormState copyWith({
    String? email,
    String? password,
    String? pilotName,
    bool? isRegisterMode,
    bool? obscurePassword,
    bool? isSubmitting,
    String? feedbackMessage,
    bool? isError,
  }) {
    return AuthUiFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      pilotName: pilotName ?? this.pilotName,
      isRegisterMode: isRegisterMode ?? this.isRegisterMode,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      feedbackMessage: feedbackMessage,
      isError: isError ?? this.isError,
    );
  }
}

class AuthUiFormNotifier extends Notifier<AuthUiFormState> {
  @override
  AuthUiFormState build() => const AuthUiFormState();

  void updateEmail(String val) => state = state.copyWith(email: val.trim());
  void updatePassword(String val) => state = state.copyWith(password: val);
  void updatePilotName(String val) => state = state.copyWith(pilotName: val);

  void toggleRegisterMode() => state = state.copyWith(
        isRegisterMode: !state.isRegisterMode,
        feedbackMessage: null,
      );

  void togglePasswordVisibility() =>
      state = state.copyWith(obscurePassword: !state.obscurePassword);

  void setFeedback(
    String? msg, {
    bool isError = false,
    bool isSubmitting = false,
  }) {
    state = state.copyWith(
      feedbackMessage: msg,
      isError: isError,
      isSubmitting: isSubmitting,
    );
  }
}

final authUiFormProvider = NotifierProvider<AuthUiFormNotifier, AuthUiFormState>(
  AuthUiFormNotifier.new,
);

/// Controlador de Autenticación Real con Firebase Auth + Storage (`rs-digital-cockpit`).
class PilotAuthNotifier extends Notifier<PilotProfile?> {
  static const String _cachedAvatarKey = 'rs_cockpit_cached_avatar_url';
  static const String _cachedLocalPathKey = 'rs_cockpit_cached_avatar_local_path';
  static const String _webClientId =
      '796311716232-951hm0hctbuqj3lgjhoek1crkrcrstkr.apps.googleusercontent.com';

  final ImagePicker _imagePicker = ImagePicker();
  StreamSubscription<User?>? _authSub;

  @override
  PilotProfile? build() {
    ref.onDispose(() => _authSub?.cancel());
    _listenToFirebaseAuth();
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current != null) {
        return _mapFirebaseUser(current);
      }
    } catch (_) {}
    return null;
  }

  void _listenToFirebaseAuth() {
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user == null) {
          state = null;
        } else {
          state = _mapFirebaseUser(user);
          _hydrateCachedProfile();
        }
      });
    } catch (_) {}
  }

  PilotProfile _mapFirebaseUser(User user) {
    final providers = user.providerData.map((p) => p.providerId).toList();
    return PilotProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName: (user.displayName != null && user.displayName!.isNotEmpty)
          ? user.displayName!
          : (user.email?.split('@').first ?? 'Piloto RS'),
      chassisNumber: 'CLIO RS 172 // F4R 736',
      avatarUrl: user.photoURL ??
          'https://ui-avatars.com/api/?name=RS&background=FF6B00&color=000000&size=256',
      emailVerified: user.emailVerified,
      providerIds: providers.isEmpty ? const <String>['password'] : providers,
      lastSyncedAt: DateTime.now(),
    );
  }

  Future<void> _hydrateCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUrl = prefs.getString(_cachedAvatarKey);
      final cachedPath = prefs.getString(_cachedLocalPathKey);
      if (state != null && (cachedUrl != null || cachedPath != null)) {
        state = state!.copyWith(
          avatarUrl: cachedUrl ?? state!.avatarUrl,
          localAvatarPath: cachedPath ?? state!.localAvatarPath,
        );
      }
    } catch (_) {}
  }

  /// 1. Inicio de sesión o registro con Correo y Contraseña
  Future<void> signInOrRegisterWithEmail({
    required String email,
    required String password,
    required String displayName,
    required bool isRegister,
  }) async {
    final ui = ref.read(authUiFormProvider.notifier);
    if (email.isEmpty || password.isEmpty) {
      ui.setFeedback('Ingresa tu correo y contraseña.', isError: true);
      return;
    }

    ui.setFeedback('Conectando con Firebase Auth...', isSubmitting: true);

    try {
      final auth = FirebaseAuth.instance;
      UserCredential cred;
      if (isRegister) {
        cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (displayName.trim().isNotEmpty) {
          await cred.user?.updateDisplayName(displayName.trim());
        }
        await cred.user?.sendEmailVerification();
        await cred.user?.reload();
      } else {
        cred = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      final user = FirebaseAuth.instance.currentUser ?? cred.user!;
      state = _mapFirebaseUser(user);
      ui.setFeedback(null, isSubmitting: false);
    } on FirebaseAuthException catch (e) {
      ui.setFeedback(
        _translateFirebaseError(e.code, e.message),
        isError: true,
        isSubmitting: false,
      );
    } catch (e) {
      ui.setFeedback(
        'Error de conexión: $e',
        isError: true,
        isSubmitting: false,
      );
    }
  }

  /// 2. Google Sign-In Real (`com.rs.digital.cockpit`)
  Future<void> signInWithGoogle() async {
    final ui = ref.read(authUiFormProvider.notifier);
    ui.setFeedback('Iniciando sesión con Google...', isSubmitting: true);

    try {
      final googleSignIn = GoogleSignIn(serverClientId: _webClientId);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        ui.setFeedback(null, isSubmitting: false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      if (userCred.user != null) {
        state = _mapFirebaseUser(userCred.user!);
      }
      ui.setFeedback(null, isSubmitting: false);
    } catch (e) {
      ui.setFeedback(
        'No se pudo iniciar con Google: $e',
        isError: true,
        isSubmitting: false,
      );
    }
  }

  /// 3. GitHub OAuth Real (`GithubAuthProvider`)
  Future<void> signInWithGitHub() async {
    final ui = ref.read(authUiFormProvider.notifier);
    ui.setFeedback('Abriendo autorización de GitHub...', isSubmitting: true);

    try {
      final githubProvider = GithubAuthProvider();
      final userCred =
          await FirebaseAuth.instance.signInWithProvider(githubProvider);
      if (userCred.user != null) {
        state = _mapFirebaseUser(userCred.user!);
      }
      ui.setFeedback(null, isSubmitting: false);
    } catch (e) {
      ui.setFeedback(
        'Error en GitHub Auth (verifica Client ID/Secret en Firebase Console): $e',
        isError: true,
        isSubmitting: false,
      );
    }
  }

  Future<void> resendVerificationEmail() async {
    final ui = ref.read(authUiFormProvider.notifier);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      ui.setFeedback('Correo de verificación enviado a ${state?.email}.');
    } catch (e) {
      ui.setFeedback('Espera unos segundos antes de reenviar: $e', isError: true);
    }
  }

  Future<void> checkEmailVerificationStatus() async {
    final ui = ref.read(authUiFormProvider.notifier);
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;
      if (updatedUser != null) {
        state = _mapFirebaseUser(updatedUser);
        if (!updatedUser.emailVerified) {
          ui.setFeedback(
            'Aún no figura como verificado. Haz clic en el enlace de tu correo.',
            isError: true,
          );
        } else {
          ui.setFeedback(null);
        }
      }
    } catch (e) {
      ui.setFeedback('Error al verificar estado: $e', isError: true);
    }
  }

  Future<void> sendPasswordReset(String targetEmail) async {
    final ui = ref.read(authUiFormProvider.notifier);
    if (targetEmail.trim().isEmpty) {
      ui.setFeedback('Ingresa tu correo electrónico.', isError: true);
      return;
    }
    ui.setFeedback('Enviando enlace...', isSubmitting: true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: targetEmail.trim(),
      );
      ui.setFeedback('Enlace enviado a $targetEmail. Revisa tu bandeja.');
    } catch (e) {
      ui.setFeedback('No se pudo enviar el correo: $e', isError: true);
    }
  }

  Future<void> pickAndUploadAvatar() async {
    final current = state;
    if (current == null) return;
    final ui = ref.read(authUiFormProvider.notifier);

    if (!current.canEditAvatar) {
      ui.setFeedback(
        current.providerBadgeLabel,
        isError: true,
      );
      return;
    }

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      ui.setFeedback('Subiendo foto...', isSubmitting: true);
      String finalDownloadUrl = current.avatarUrl;

      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('pilots/${current.uid}/avatar.jpg');
        await storageRef.putFile(File(picked.path));
        finalDownloadUrl = await storageRef.getDownloadURL();
        await FirebaseAuth.instance.currentUser?.updatePhotoURL(finalDownloadUrl);
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedAvatarKey, finalDownloadUrl);
      await prefs.setString(_cachedLocalPathKey, picked.path);

      state = current.copyWith(
        avatarUrl: finalDownloadUrl,
        localAvatarPath: picked.path,
        lastSyncedAt: DateTime.now(),
      );
      ui.setFeedback('Foto de perfil actualizada.');
    } catch (e) {
      ui.setFeedback('Error al actualizar imagen: $e', isError: true);
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn(serverClientId: _webClientId).signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    state = null;
  }

  String _translateFirebaseError(String code, String? fallback) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
        return 'Credenciales incorrectas o cuenta no registrada.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'email-already-in-use':
        return 'Este correo ya está registrado. Inicia sesión.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'invalid-email':
        return 'El formato del correo no es válido.';
      default:
        return fallback ?? 'Error de autenticación ($code).';
    }
  }
}

final pilotAuthProvider = NotifierProvider<PilotAuthNotifier, PilotProfile?>(
  PilotAuthNotifier.new,
);
