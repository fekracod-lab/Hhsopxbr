import 'dart:async';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dalal_alqaim/services/notification_service.dart';
import 'package:dalal_alqaim/services/notification_router.dart';
import 'package:dalal_alqaim/core/app_globals.dart';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalal_alqaim/services/ringtone_manager.dart';

// App ID for OneSignal. Never embed REST keys in client code.
const String kOneSignalAppId = "819db763-ded1-45cf-8ec2-6357e084ed9b";

/// A wrapper around the OneSignal SDK to manage notifications and user tags.
///
/// This service encapsulates all communication with OneSignal, including
/// initialisation, click handling, role synchronisation and login/logout
/// operations. It is structured to avoid race conditions, minimise repeated
/// code and log all errors for easier debugging.
class OneSignalService {
  static bool _isInitialized = false;

  /// Initialise the OneSignal SDK. On web this call is a no-op as the
  /// OneSignal plugin is unavailable.
  static Future<void> initialize() async {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      debugPrint('OneSignalService: Skipping initialisation on non-mobile platform');
      return;
    }
    try {
      // Enable warning logs for better debugging.
      OneSignal.Debug.setLogLevel(OSLogLevel.warn);
      // Initialise with the application ID.
      OneSignal.initialize(kOneSignalAppId);
      _isInitialized = true;
      
      // Request notification permissions safely.
      try {
        await OneSignal.Notifications.requestPermission(true);
        final permission = OneSignal.Notifications.permission;
        debugPrint('OneSignal: permission = $permission');
      } catch (e) {
        debugPrint('OneSignal: requestPermission caught non-fatal: $e');
      }
      // Listen to notification clicks.
      OneSignal.Notifications.addClickListener(_handleNotificationClick);
      // منع الازدواجية: FCM هو المرسل الحصري المعتمد لعرض الإشعارات الأمامية
      OneSignal.Notifications.addForegroundWillDisplayListener((event) async {
        debugPrint('OneSignal: Foreground message received in standby mode (FCM handles active display)');
        // عدم استدعاء event.notification.display() يمنع الازدواجية التامة في الواجهة
      });
    // Listen to push subscription changes (e.g. when push token becomes available dynamically)
    OneSignal.User.pushSubscription.addObserver((state) async {
      final pushId = state.current.id;
      debugPrint('OneSignalService: Push Subscription ID changed to: $pushId');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && pushId != null && pushId.isNotEmpty) {
        await _savePushTokenToFirestore(user.uid, pushId);
      }
    });
    } catch (e) {
      debugPrint(' OneSignal initialisation error: $e');
    }
  }

  /// Save push ID token to Firestore collections ('users' and optionally 'drivers').
  static Future<void> _savePushTokenToFirestore(String uid, String pushId) async {
    try {
      final now = DateTime.now();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'oneSignalId': pushId,
        'lastActive': now,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('OneSignalService: Saved push ID $pushId to users collection');

      final driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(uid).get();
      if (driverDoc.exists) {
        await FirebaseFirestore.instance.collection('drivers').doc(uid).update({
          'oneSignalId': pushId,
        });
        debugPrint('OneSignalService: Saved push ID $pushId to drivers collection');
      }
    } catch (e) {
      debugPrint('OneSignalService: Error saving push ID to Firestore: $e');
    }
  }

  /// Handle notification clicks by routing the user to the appropriate page.
  static void _handleNotificationClick(OSNotificationClickEvent event) {
    try {
      final data = event.notification.additionalData;
      if (data == null || data.isEmpty) return;

      NotificationRouter.handleNotificationData(data);
    } catch (e) {
      dev.log('OneSignalService: error handling notification click: $e');
    }
  }

  /// Synchronise the user's role with OneSignal tags and persist the push ID
  /// into Firestore. This method logs in and sets role tags immediately.
  static Future<void> syncUserRole(String uid) async {
    if (kIsWeb) {
      debugPrint('OneSignalService: syncUserRole skipped on web');
      return;
    }
    if (!_isInitialized) {
      debugPrint('OneSignalService: syncUserRole deferred because OneSignal is not initialized yet.');
      return;
    }

    try {
      debugPrint('OneSignalService: synchronizing user $uid');
      // 1. Link the external user ID to OneSignal immediately.
      await OneSignal.login(uid);

      // 2. Fetch the user document to determine their role.
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      String role = 'customer';
      if (doc.exists) {
        role = doc.data()?['role']?.toString() ?? 'customer';
      }

      // 3. Update local app global role and cache it in SharedPreferences to prevent stale filtering.
      currentUserRole = role;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentUserRole', role);
      } catch (e) {
        debugPrint('OneSignalService: Error saving currentUserRole: $e');
      }
      debugPrint('OneSignalService: detected role = $role (uid = $uid)');

      // 4. Update OneSignal tag for the user's role immediately.
      await OneSignal.User.addTagWithKey('role', role);
      debugPrint('OneSignalService: Tag "role" set to "$role"');

      // 5. Try updating pushId if it's already loaded/active in SDK.
      final pushId = OneSignal.User.pushSubscription.id;
      if (pushId != null && pushId.isNotEmpty) {
        await _savePushTokenToFirestore(uid, pushId);
      } else {
        // If not loaded yet, update other metadata in Firestore anyway.
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'role': role,
          'lastActive': DateTime.now(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('OneSignalService: Push ID not active yet (will be saved via observer when ready)');
      }
    } catch (e) {
      dev.log('OneSignalService: syncUserRole error: $e');
    }
  }

  /// Log out the user from OneSignal. On web this call is a no-op.
  static Future<void> logout() async {
    if (kIsWeb) {
      debugPrint('OneSignalService: logout skipped on web');
      return;
    }
    if (!_isInitialized) return;
    try {
      await OneSignal.logout();
      debugPrint('OneSignalService: logout success');
    } catch (e) {
      dev.log('OneSignalService: logout error: $e');
    }
  }

  /// Log in a user to OneSignal using their unique ID. Safe wrapper for web.
  static Future<void> loginUser(String uid) async {
    if (kIsWeb) {
      debugPrint('OneSignalService: loginUser skipped on web');
      return;
    }
    if (!_isInitialized) return;
    try {
      await OneSignal.login(uid);
      debugPrint('OneSignalService: logged in user $uid');
    } catch (e) {
      dev.log('OneSignalService: login error: $e');
    }
  }

  /// Retrieve the current OneSignal push ID. Safe wrapper for web.
  static Future<String?> getPushId() async {
    if (kIsWeb) return null;
    try {
      return OneSignal.User.pushSubscription.id;
    } catch (e) {
      dev.log('OneSignalService: getPushId error: $e');
      return null;
    }
  }
}
