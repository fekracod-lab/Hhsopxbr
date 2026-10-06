import 'dart:async';
import 'package:flutter/services.dart';

/// منبه صوتي لتنبيه الكاشير والمطبخ عند وصول طلب جديد من مدار
class AudioAlertService {
  static Timer? _repeatTimer;

  /// تشغيل نغمة التنبيه (تتكرر كل ثانيتين حتى يتم الإيقاف أو مرور 30 ثانية)
  static void playOrderAlarm({int durationSeconds = 20}) {
    stopAlarm();
    // نقرة صوتية أولى
    SystemSound.play(SystemSoundType.alert);

    int elapsed = 0;
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      elapsed += 2;
      SystemSound.play(SystemSoundType.alert);
      if (elapsed >= durationSeconds) {
        stopAlarm();
      }
    });
  }

  /// إيقاف المنبه
  static void stopAlarm() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }
}
