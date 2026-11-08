import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

/// Configuración multiplataforma de Firebase generada para:
/// `com.renaultsport.clio172_cockpit` (Google Pixel Tablet - Android 17).
/// Puedes reemplazar estos valores ejecutando `flutterfire configure` con tu cuenta.
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
    apiKey: 'AIzaSyD-CLIO-RS-172-FIREBASE-ANDROID17-PIXEL-KEY',
    appId: '1:172200473600:android:f4r736siemenssirius34',
    messagingSenderId: '172200473600',
    projectId: 'clio-rs-172-telemetry-hub',
    databaseURL: 'https://clio-rs-172-telemetry-hub-default-rtdb.firebaseio.com',
    storageBucket: 'clio-rs-172-telemetry-hub.firebasestorage.app',
  );
}

