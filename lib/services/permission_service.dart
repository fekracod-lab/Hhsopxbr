import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Checks if all critical driver permissions are granted.
  static Future<bool> hasAllDriverPermissions() async {
    if (!Platform.isAndroid) return true;

    // 1. Notifications (Android 13+)
    if (await Permission.notification.isDenied) return false;

    // 2. Overlay (Display over other apps) - Essential for call screens
    if (await Permission.systemAlertWindow.isDenied) return false;

    // 3. Exact Alarm (Android 12+)
    if (await Permission.scheduleExactAlarm.isDenied) return false;
    
    // 4. Requesting Battery Optimization ignoring is nice but not strictly required for "visibility"
    // but useful for reliability. We'll check it anyway.
    // if (await Permission.ignoreBatteryOptimizations.isDenied) return false;

    return true;
  }

  /// Requests critical driver permissions one by one.
  static Future<void> requestDriverPermissions(BuildContext context) async {
    if (!Platform.isAndroid) return;

    // 1. Notification Permission
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // 2. Exact Alarm (Android 12+)
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    // 3. System Alert Window (Overlay)
    // This usually opens a system setting page
    if (await Permission.systemAlertWindow.isDenied) {
      await Permission.systemAlertWindow.request();
    }

    // 4. Phone State (To handle audio/duking)
    if (await Permission.phone.isDenied) {
      await Permission.phone.request();
    }
    
    // 5. Battery Optimizations
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  /// Specialized check for Overlay permission with a custom helper if needed
  static Future<bool> isOverlayPermissionGranted() async {
    if (!Platform.isAndroid) return true;
    return await Permission.systemAlertWindow.isGranted;
  }
}
