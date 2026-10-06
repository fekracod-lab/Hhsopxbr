import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration — يُستخدم فقط على الويب
/// على الموبايل يتم التهيئة تلقائياً عبر google-services.json / GoogleService-Info.plist
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return web;
      default:
        return android;
    }
  }

  /// Web — نفس المشروع (dala-alqaim)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDmIrIXEKy1hmvkgDtAAws95fFnIrWVeZs',
    appId: '1:656705978860:web:0000000000000000d280c9', // سيتم تحديثه
    messagingSenderId: '656705978860',
    projectId: 'dala-alqaim',
    authDomain: 'dala-alqaim.firebaseapp.com',
    storageBucket: 'dala-alqaim.firebasestorage.app',
  );

  /// Android
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDmIrIXEKy1hmvkgDtAAws95fFnIrWVeZs',
    appId: '1:656705978860:android:07fd42dc65b8d06ed280c9',
    messagingSenderId: '656705978860',
    projectId: 'dala-alqaim',
    storageBucket: 'dala-alqaim.firebasestorage.app',
  );

  /// iOS (نفس المشروع)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDSn6zdRa1y-9CiHGaBUVpQaiiE28SrZDw',
    appId: '1:656705978860:ios:97a2f152694c9afdd280c9',
    messagingSenderId: '656705978860',
    projectId: 'dala-alqaim',
    storageBucket: 'dala-alqaim.firebasestorage.app',
    iosBundleId: 'com.madaralairaq',
    iosClientId: '656705978860-uuk2dosi4tjrc1q1geip905377grs52q.apps.googleusercontent.com',
  );
}
