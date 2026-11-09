import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

/// Configuración oficial de Firebase para RS Digital Cockpit (`com.rs.digital.cockpit`).
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBAWiE_ffkwGVPQyG_PzFt0Cw0xRZKMnPQ',
    appId: '1:796311716232:android:9d3b254bc49a122130ba3d',
    messagingSenderId: '796311716232',
    projectId: 'rs-digital-cockpit',
    databaseURL: 'https://rs-digital-cockpit-default-rtdb.firebaseio.com',
    storageBucket: 'rs-digital-cockpit.firebasestorage.app',
  );
}
