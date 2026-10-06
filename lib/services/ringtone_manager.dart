import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// RingtoneManager
/// 
/// يدير حالة رنة الطلب والتنبيه المركزي. يضمن منع التداخل والتكرار بين الواجهة
/// والخلفية، ويدير الإيقاف التلقائي، وإزالة إشعار الطلب من شريط التنبيهات.
class RingtoneManager {
  static Timer? _timer;
  static bool _isPlaying = false;
  static String? _currentRequestId;

  static bool get isPlaying => _isPlaying;
  static String? get currentRequestId => _currentRequestId;

  /// تشغيل رنة الإنذار المستمرة لطلب معين مع تفعيل الإيقاف التلقائي
  static final Set<String> _processedIds = {};

  /// تشغيل رنة الإنذار المستمرة لطلب معين مع تفعيل الإيقاف التلقائي
  static Future<void> startAlarm(String requestId, {int autoStopSeconds = 15}) async {
    if (_isPlaying && _currentRequestId == requestId) {
      return;
    }

    debugPrint(' [RingtoneManager] startAlarm called for Request ID: $requestId');

    // 1. منع تكرار معالجة نفس الطلب
    if (requestId != 'unknown_request' && await _isDuplicate(requestId)) {
      debugPrint(' [RingtoneManager] Suppressed duplicate alarm for Request ID: $requestId');
      return;
    }

    try {
      _timer?.cancel();
      await FlutterRingtonePlayer().playAlarm(
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );
      _isPlaying = true;
      _currentRequestId = requestId;
      debugPrint(' [RingtoneManager] Alarm started looping.');

      // مؤقت أمان للإيقاف التلقائي
      _timer = Timer(Duration(seconds: autoStopSeconds), () async {
        debugPrint(' [RingtoneManager] Auto-stop timer elapsed.');
        await stopAlarm(requestId);
      });
    } catch (e) {
      debugPrint(' [RingtoneManager] Error playing alarm: $e');
    }
  }

  /// إيقاف الرنة لطلب معين وإلغاء الإشعار المحلي الخاص به
  static Future<void> stopAlarm(String requestId) async {
    debugPrint(' [RingtoneManager] stopAlarm requested for Request ID: $requestId');
    if (requestId.isNotEmpty) {
      _processedIds.add(requestId);
    }
    
    try {
      _timer?.cancel();
      await FlutterRingtonePlayer().stop();
      _isPlaying = false;
      _currentRequestId = null;
      debugPrint(' [RingtoneManager] Alarm stopped successfully.');
    } catch (e) {
      debugPrint(' [RingtoneManager] Error stopping ringtone: $e');
    }

    try {
      final localNotif = FlutterLocalNotificationsPlugin();
      await localNotif.cancel(id: requestId.hashCode);
      await localNotif.cancelAll();
      debugPrint(' [RingtoneManager] Cancelled local notification with ID: ${requestId.hashCode}');
    } catch (e) {
      debugPrint(' [RingtoneManager] Error cancelling notification: $e');
    }
  }

  /// إيقاف كافة الرنات الجارية فوراً
  static Future<void> stopAll() async {
    debugPrint(' [RingtoneManager] stopAll called.');
    try {
      _timer?.cancel();
      await FlutterRingtonePlayer().stop();
      _isPlaying = false;
      _currentRequestId = null;
      final localNotif = FlutterLocalNotificationsPlugin();
      await localNotif.cancelAll();
    } catch (e) {
      debugPrint(' [RingtoneManager] Error in stopAll: $e');
    }
  }

  /// التحقق الفوري محلياً وفي الذاكرة لمنع التجميد المباشر
  static Future<bool> _isDuplicate(String requestId) async {
    if (_processedIds.contains(requestId)) {
      return true;
    }
    _processedIds.add(requestId);
    if (_processedIds.length > 100) {
      _processedIds.remove(_processedIds.first);
    }
    
    // حفظ في SharedPreferences في الخلفية دون تعطيل الخيط الرئيسي
    SharedPreferences.getInstance().then((prefs) {
      final list = prefs.getStringList('processed_request_ids') ?? [];
      if (!list.contains(requestId)) {
        list.add(requestId);
        if (list.length > 50) list.removeAt(0);
        prefs.setStringList('processed_request_ids', list);
      }
    }).catchError((e) {
      debugPrint(' Error updating processed_request_ids: $e');
    });
    return false;
  }
}
