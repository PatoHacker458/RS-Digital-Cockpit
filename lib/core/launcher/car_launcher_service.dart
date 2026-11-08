import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aplicación externa del Dock de Cabina en la Google Pixel Tablet (Android 17)
class CabinExternalApp {
  final String name;
  final String packageName;
  final String fallbackWebUrl;
  final String category;

  const CabinExternalApp({
    required this.name,
    required this.packageName,
    required this.fallbackWebUrl,
    required this.category,
  });
}

/// Servicio nativo de Android 17 Car Launcher (`MethodChannel`).
/// Mantiene viva la sesión Bluetooth RFCOMM KWP2000 con la ECU Sirius 34 en
/// segundo plano mientras lanza aplicaciones de cabina (Spotify, Waze, Maps, YT Music).
class CarLauncherService {
  static const MethodChannel _launcherChannel =
      MethodChannel('com.renaultsport.clio172/launcher');

  static const List<CabinExternalApp> kQuickCabinApps = <CabinExternalApp>[
    CabinExternalApp(
      name: 'Spotify',
      packageName: 'com.spotify.music',
      fallbackWebUrl: 'https://open.spotify.com',
      category: 'Audio Cabina',
    ),
    CabinExternalApp(
      name: 'Waze',
      packageName: 'com.waze',
      fallbackWebUrl: 'https://www.waze.com/live-map',
      category: 'Radar & Tráfico',
    ),
    CabinExternalApp(
      name: 'Google Maps',
      packageName: 'com.google.android.apps.maps',
      fallbackWebUrl: 'https://maps.google.com',
      category: 'Navegación',
    ),
    CabinExternalApp(
      name: 'YT Music',
      packageName: 'com.google.android.apps.youtube.music',
      fallbackWebUrl: 'https://music.youtube.com',
      category: 'Audio Cabina',
    ),
  ];

  Future<bool> launchCabinApp(CabinExternalApp app) async {
    try {
      HapticFeedback.lightImpact();
      final ok = await _launcherChannel.invokeMethod<bool>(
        'launchExternalApp',
        <String, dynamic>{
          'packageName': app.packageName,
          'fallbackUrl': app.fallbackWebUrl,
        },
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openAndroid17DefaultLauncherSelector() async {
    try {
      final ok = await _launcherChannel.invokeMethod<bool>('openHomeLauncherSettings');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}

final carLauncherServiceProvider = Provider<CarLauncherService>((ref) {
  return CarLauncherService();
});

