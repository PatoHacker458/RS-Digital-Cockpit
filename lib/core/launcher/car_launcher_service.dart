import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Aplicación externa del Dock de Cabina en RS Digital Cockpit
class CabinExternalApp {
  final String name;
  final String packageName;
  final String fallbackWebUrl;
  final IconData icon;
  final Color brandColor;

  const CabinExternalApp({
    required this.name,
    required this.packageName,
    required this.fallbackWebUrl,
    required this.icon,
    required this.brandColor,
  });
}

class CarLauncherService {
  static const MethodChannel _launcherChannel =
      MethodChannel('com.renaultsport.clio172/launcher');

  static const List<CabinExternalApp> kQuickCabinApps = <CabinExternalApp>[
    CabinExternalApp(
      name: 'Spotify',
      packageName: 'com.spotify.music',
      fallbackWebUrl: 'https://open.spotify.com',
      icon: Icons.music_note_rounded,
      brandColor: Color(0xFF1DB954),
    ),
    CabinExternalApp(
      name: 'Waze',
      packageName: 'com.waze',
      fallbackWebUrl: 'https://www.waze.com/live-map',
      icon: Icons.navigation_rounded,
      brandColor: Color(0xFF33CCFF),
    ),
    CabinExternalApp(
      name: 'Google Maps',
      packageName: 'com.google.android.apps.maps',
      fallbackWebUrl: 'https://maps.google.com',
      icon: Icons.location_on_rounded,
      brandColor: Color(0xFF34A853),
    ),
    CabinExternalApp(
      name: 'YouTube Music',
      packageName: 'com.google.android.apps.youtube.music',
      fallbackWebUrl: 'https://music.youtube.com',
      icon: Icons.play_circle_fill_rounded,
      brandColor: Color(0xFFFF0033),
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
      final ok =
          await _launcherChannel.invokeMethod<bool>('openHomeLauncherSettings');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}

final carLauncherServiceProvider = Provider<CarLauncherService>((ref) {
  return CarLauncherService();
});
