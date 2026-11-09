import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth_profile/providers/auth_profile_providers.dart';
import 'features/auth_profile/screens/auth_screen.dart';
import 'features/auth_profile/screens/email_verification_screen.dart';
import 'features/cloud_sync_fcm/fcm_notification_service.dart';
import 'features/cloud_sync_fcm/hud_notification_wrapper.dart';
import 'features/cockpit_dashboard/cockpit_dashboard_screen.dart';
import 'features/onboarding/onboarding_provider.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/splash/rs_splash_screen.dart';
import 'firebase_options.dart';

/// Punto de entrada principal de **RS Digital Cockpit** (`com.rs.digital.cockpit`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Hive.initFlutter();
  } catch (_) {}

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Color(0xFF0F1115),
    ),
  );

  runApp(
    const ProviderScope(
      child: RsDigitalCockpitApp(),
    ),
  );
}

class RsDigitalCockpitApp extends ConsumerWidget {
  const RsDigitalCockpitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final splashBoot = ref.watch(splashBootProvider);
    final onboarding = ref.watch(onboardingProvider);
    final pilotProfile = ref.watch(pilotAuthProvider);

    return MaterialApp(
      title: 'RS Digital Cockpit',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.daylightCupTheme,
      darkTheme: AppTheme.nightStageTheme,
      builder: (context, child) {
        return HudNotificationWrapper(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _resolveActiveScreen(
        splashReady: splashBoot.isReady,
        onboardingCompleted: onboarding.isCompleted,
        pilotProfile: pilotProfile,
      ),
    );
  }

  Widget _resolveActiveScreen({
    required bool splashReady,
    required bool onboardingCompleted,
    required dynamic pilotProfile,
  }) {
    if (!splashReady) {
      return const RsSplashScreen();
    }
    if (!onboardingCompleted) {
      return const OnboardingScreen();
    }
    if (pilotProfile == null) {
      return const AuthScreen();
    }
    if (pilotProfile.requiresEmailVerificationGate == true) {
      return const EmailVerificationScreen();
    }
    return const CockpitDashboardScreen();
  }
}
