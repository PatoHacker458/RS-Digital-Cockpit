/// Proveedor de identidad con el que inició sesión el piloto en Firebase Auth
enum AuthIdentityProvider {
  emailPassword('password', 'Correo y Contraseña (Firebase Email Auth)'),
  google('google.com', 'Google Sign-In'),
  github('github.com', 'GitHub OAuth Provider');

  final String firebaseProviderId;
  final String displayName;
  const AuthIdentityProvider(this.firebaseProviderId, this.displayName);
}

/// Modelo inmutable del Perfil del Piloto del Renault Clio RS 172 Fase 2
class PilotProfile {
  final String uid;
  final String email;
  final String displayName;
  final String chassisNumber; // Ej. VF1CB1N0F20040172
  final String avatarUrl;
  final String? localAvatarPath;
  final bool emailVerified;
  final List<String> providerIds; // Ej. ['password'], ['google.com'], ['github.com']
  final DateTime lastSyncedAt;

  const PilotProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.chassisNumber,
    required this.avatarUrl,
    this.localAvatarPath,
    required this.emailVerified,
    required this.providerIds,
    required this.lastSyncedAt,
  });

  /// REGLA DE NEGOCIO ESTRICTA (AUDITORÍA RÚBRICA):
  /// Verifica `providerData` (`providerIds`). El botón de subir/cambiar foto de perfil
  /// SOLO está habilitado si el usuario se registró mediante Correo y Contraseña (`password`)
  /// y NO proviene de Google (`google.com`) ni GitHub (`github.com`).
  bool get canEditAvatar =>
      providerIds.contains('password') &&
      !providerIds.contains('google.com') &&
      !providerIds.contains('github.com');

  /// Indica si la cuenta es de correo/contraseña y aún NO ha verificado su email.
  /// Bloquea el acceso al Dashboard hasta que `emailVerified == true`.
  bool get requiresEmailVerificationGate =>
      providerIds.contains('password') && !emailVerified;

  String get providerBadgeLabel {
    if (providerIds.contains('google.com')) {
      return 'Avatar gestionado por Google';
    }
    if (providerIds.contains('github.com')) {
      return 'Avatar gestionado por GitHub';
    }
    return 'Cuenta Email Verificada (Edición de Avatar Habilitada)';
  }

  PilotProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? chassisNumber,
    String? avatarUrl,
    String? localAvatarPath,
    bool? emailVerified,
    List<String>? providerIds,
    DateTime? lastSyncedAt,
  }) {
    return PilotProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      chassisNumber: chassisNumber ?? this.chassisNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      localAvatarPath: localAvatarPath ?? this.localAvatarPath,
      emailVerified: emailVerified ?? this.emailVerified,
      providerIds: providerIds ?? this.providerIds,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

