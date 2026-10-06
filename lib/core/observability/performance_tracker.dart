import 'package:flutter/foundation.dart';

/// سجل المسار الزمني التفصيلي للأداء (Trace Record)
class TraceRecord {
  final String name;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMs;
  final bool isSuccess;
  final Map<String, dynamic> metadata;

  const TraceRecord({
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.durationMs,
    required this.isSuccess,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationMs': durationMs,
      'isSuccess': isSuccess,
      'metadata': metadata,
    };
  }

  @override
  String toString() => 'TraceRecord($name: ${durationMs}ms, success: $isSuccess, meta: $metadata)';
}

class _ActiveTrace {
  final String name;
  final DateTime startTime;
  final Stopwatch stopwatch;
  final Map<String, dynamic> metadata;

  _ActiveTrace({
    required this.name,
    required this.startTime,
    required this.stopwatch,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata != null ? Map<String, dynamic>.from(metadata) : <String, dynamic>{};
}

/// أداة قياس ورصد الأداء وأزمنة الإقلاع لمنصة مدار (Madar Performance Tracker)
/// متوافقة مع التوسيع المستقبلي لـ Firebase Performance Traces
class PerformanceTracker {
  PerformanceTracker._();

  static final Map<String, _ActiveTrace> _activeTraces = {};
  static final Map<String, TraceRecord> _completedTraces = {};

  /// بدء تتبع مسار زمني محدد مع بيانات وصفية اختيارية (Safe Metadata)
  static void startTrace(String traceName, {Map<String, dynamic>? metadata}) {
    final active = _ActiveTrace(
      name: traceName,
      startTime: DateTime.now(),
      stopwatch: Stopwatch()..start(),
      metadata: metadata,
    );
    _activeTraces[traceName] = active;
    if (kDebugMode) {
      debugPrint(' [Perf Start] $traceName ${metadata != null ? "(meta: $metadata)" : ""}');
    }
  }

  /// إنهاء المسار الزمني وحساب المدة وتوثيق حالة النجاح والبيانات
  static TraceRecord? stopTrace(
    String traceName, {
    bool isSuccess = true,
    String? details,
    Map<String, dynamic>? additionalMetadata,
  }) {
    final active = _activeTraces.remove(traceName);
    if (active == null) return null;

    active.stopwatch.stop();
    final endTime = DateTime.now();
    final durationMs = active.stopwatch.elapsedMilliseconds;

    if (additionalMetadata != null) {
      active.metadata.addAll(additionalMetadata);
    }
    if (details != null) {
      active.metadata['details'] = details;
    }

    final record = TraceRecord(
      name: traceName,
      startTime: active.startTime,
      endTime: endTime,
      durationMs: durationMs,
      isSuccess: isSuccess,
      metadata: Map.unmodifiable(active.metadata),
    );

    _completedTraces[traceName] = record;

    debugPrint(' [Perf Benchmark] $traceName: ${durationMs}ms | status: ${isSuccess ? "" : ""} ${details != null ? "($details)" : ""}');
    return record;
  }

  /// الحصول على مدة مسار معين بالمللي ثانية
  static int? getDuration(String traceName) => _completedTraces[traceName]?.durationMs;

  /// الحصول على سجل المسار المكتمل
  static TraceRecord? getTrace(String traceName) => _completedTraces[traceName];

  /// الحصول على جميع المسارات المكتملة
  static Map<String, TraceRecord> getAllTraces() => Map.unmodifiable(_completedTraces);

  /// مسح جميع القياسات
  static void clear() {
    _activeTraces.clear();
    _completedTraces.clear();
  }
}
