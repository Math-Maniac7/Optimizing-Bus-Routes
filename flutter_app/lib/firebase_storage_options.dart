import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options for the storage project (bus-mobile-app-4bebd)
/// This is separate from the OAuth project (route-optimization-474616)
class FirebaseStorageOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'FirebaseStorageOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'FirebaseStorageOptions are not supported for this platform.',
        );
    }
  }

  // Web configuration for storage project
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBEH7h_od-ZYOqwJGgAHR0N8_Ak3z0insc',
    appId: '1:593453456089:web:1e8a13dd8c8699e65cbcc8',
    messagingSenderId: '593453456089',
    projectId: 'bus-mobile-app-4bebd',
    authDomain: 'bus-mobile-app-4bebd.firebaseapp.com',
    storageBucket: 'bus-mobile-app-4bebd.firebasestorage.app',
  );

  // Android configuration - you may need to add a web app ID here
  // For now using web config as fallback
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBEH7h_od-ZYOqwJGgAHR0N8_Ak3z0insc',
    appId: '1:593453456089:android:YOUR_ANDROID_APP_ID', // Update if you have Android app
    messagingSenderId: '593453456089',
    projectId: 'bus-mobile-app-4bebd',
    storageBucket: 'bus-mobile-app-4bebd.firebasestorage.app',
  );

  // iOS configuration - you may need to add iOS app ID here
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBEH7h_od-ZYOqwJGgAHR0N8_Ak3z0insc',
    appId: '1:593453456089:ios:YOUR_IOS_APP_ID', // Update if you have iOS app
    messagingSenderId: '593453456089',
    projectId: 'bus-mobile-app-4bebd',
    storageBucket: 'bus-mobile-app-4bebd.firebasestorage.app',
    iosBundleId: 'com.example.flutterApp',
  );

  // macOS configuration
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBEH7h_od-ZYOqwJGgAHR0N8_Ak3z0insc',
    appId: '1:593453456089:ios:YOUR_IOS_APP_ID', // Update if you have iOS app
    messagingSenderId: '593453456089',
    projectId: 'bus-mobile-app-4bebd',
    storageBucket: 'bus-mobile-app-4bebd.firebasestorage.app',
    iosBundleId: 'com.example.flutterApp',
  );

  // Windows configuration
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBEH7h_od-ZYOqwJGgAHR0N8_Ak3z0insc',
    appId: '1:593453456089:web:1e8a13dd8c8699e65cbcc8',
    messagingSenderId: '593453456089',
    projectId: 'bus-mobile-app-4bebd',
    authDomain: 'bus-mobile-app-4bebd.firebaseapp.com',
    storageBucket: 'bus-mobile-app-4bebd.firebasestorage.app',
  );
}

