import '../entities/trace_span.dart';
import '../enums/observability_enums.dart';

/// محرك إدارة التتبع الموزع وقياس زمن الاستجابة (Distributed Tracing Engine)
class DistributedTracingEngine {
  final Map<String, TraceSpan> _activeSpans = {};
  final List<TraceSpan> _completedSpans = [];

  DistributedTracingEngine();

  List<TraceSpan> get completedSpans => List.unmodifiable(_completedSpans);
  Map<String, TraceSpan> get activeSpans => Map.unmodifiable(_activeSpans);

  /// بدء مقطع زمني جديد (Start Span)
  TraceSpan startSpan({
    required String traceId,
    String? parentSpanId,
    required String correlationId,
    required String name,
    required ServiceType service,
    Map<String, dynamic> attributes = const {},
    DateTime? now,
  }) {
    final spanId = 'span-${DateTime.now().millisecondsSinceEpoch}-${_activeSpans.length}';
    final startTime = now ?? DateTime.now();

    final span = TraceSpan(
      traceId: traceId,
      spanId: spanId,
      parentSpanId: parentSpanId,
      correlationId: correlationId,
      name: name,
      service: service,
      startTime: startTime,
      status: SpanStatus.unset,
      attributes: attributes,
    );

    _activeSpans[spanId] = span;
    return span;
  }

  /// إنهاء المقطع الزمني وحساب مدة التنفيذ (Finish Span)
  TraceSpan? finishSpan({
    required String spanId,
    SpanStatus status = SpanStatus.ok,
    Map<String, dynamic>? additionalAttributes,
    DateTime? now,
  }) {
    final activeSpan = _activeSpans.remove(spanId);
    if (activeSpan == null) return null;

    final endTime = now ?? DateTime.now();
    final durationMs = endTime.difference(activeSpan.startTime).inMilliseconds.abs();

    final mergedAttributes = Map<String, dynamic>.from(activeSpan.attributes);
    if (additionalAttributes != null) {
      mergedAttributes.addAll(additionalAttributes);
    }

    final completed = activeSpan.copyWith(
      endTime: endTime,
      durationMs: durationMs,
      status: status,
      attributes: mergedAttributes,
    );

    _completedSpans.add(completed);
    return completed;
  }

  /// كشف العمليات العالقة المتجاوزة للحد الزمني (Stuck Operations Detector)
  List<TraceSpan> findStuckSpans({
    Duration threshold = const Duration(minutes: 5),
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final stuck = <TraceSpan>[];

    for (final span in _activeSpans.values) {
      final elapsed = currentTime.difference(span.startTime);
      if (elapsed > threshold) {
        stuck.add(span);
      }
    }

    return stuck;
  }

  void clear() {
    _activeSpans.clear();
    _completedSpans.clear();
  }
}
