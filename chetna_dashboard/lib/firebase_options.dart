// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // Check for Windows
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return windows;
    }

    // Throw error for other platforms (Android/iOS/Linux/macOS)
    throw UnsupportedError(
      'DefaultFirebaseOptions have not been configured for this platform. '
      'Only Web and Windows are enabled.',
    );
  }

  // -------------------------------------------------------------------------
  // 1. WEB CONFIGURATION (Fully Configured)
  // -------------------------------------------------------------------------
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCwiOdp7fzdLd3mAYoK2zR2XGfYXzFzpnA',
    appId: '1:738663675010:web:7d1044219ef9bf3f54b09b',
    messagingSenderId: '738663675010',
    projectId: 'chetna-healthhack',
    authDomain: 'chetna-healthhack.firebaseapp.com',
    databaseURL: 'https://chetna-healthhack-default-rtdb.firebaseio.com',
    storageBucket: 'chetna-healthhack.firebasestorage.app',
    measurementId: 'G-3FB4FEGM8B',
  );

  // -------------------------------------------------------------------------
  // 2. WINDOWS CONFIGURATION
  // (Shared details are filled. You must add the specific App ID/API Key)
  // -------------------------------------------------------------------------
  // Inside lib/firebase_options.dart

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCwiOdp7fzdLd3mAYoK2zR2XGfYXzFzpnA', // Same as Web
    appId: '1:738663675010:web:7d1044219ef9bf3f54b09b', // Same as Web
    messagingSenderId: '738663675010',
    projectId: 'chetna-healthhack',
    authDomain: 'chetna-healthhack.firebaseapp.com',
    databaseURL: 'https://chetna-healthhack-default-rtdb.firebaseio.com',
    storageBucket: 'chetna-healthhack.firebasestorage.app',
    measurementId: 'G-3FB4FEGM8B',
  );
}
