import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/observability/domain/enums/observability_enums.dart';
import 'package:dalal_alqaim/core/observability/domain/services/distributed_tracing_engine.dart';

void main() {
  group('Distributed Tracing Engine Dedicated Tests', () {
    test('1. Starts, executes and completes span with duration and status', () {
      final engine = DistributedTracingEngine();
      final t0 = DateTime(2026, 8, 28, 12, 0, 0);

      final span = engine.startSpan(
        traceId: 'trace_order_100',
        correlationId: 'corr_100',
        name: 'OrderValidationSpan',
        service: ServiceType.orderEngine,
        now: t0,
      );

      expect(engine.activeSpans.containsKey(span.spanId), isTrue);

      final t1 = t0.add(const Duration(milliseconds: 145));
      final completed = engine.finishSpan(
        spanId: span.spanId,
        status: SpanStatus.ok,
        additionalAttributes: {'orderId': 'ord_123'},
        now: t1,
      );

      expect(completed, isNotNull);
      expect(completed!.durationMs, equals(145));
      expect(completed.status, equals(SpanStatus.ok));
      expect(completed.attributes['orderId'], equals('ord_123'));
      expect(engine.activeSpans.isEmpty, isTrue);
      expect(engine.completedSpans.length, equals(1));
    });

    test('2. Accurately identifies stuck spans exceeding duration threshold', () {
      final engine = DistributedTracingEngine();
      final t0 = DateTime(2026, 8, 28, 12, 0, 0);

      // Span 1: Started 10 minutes ago and never finished
      engine.startSpan(
        traceId: 'trace_stuck_1',
        correlationId: 'corr_stuck_1',
        name: 'StuckPaymentSpan',
        service: ServiceType.financialEngine,
        now: t0,
      );

      // Span 2: Started 1 minute ago
      engine.startSpan(
        traceId: 'trace_recent_1',
        correlationId: 'corr_recent_1',
        name: 'RecentLocationSpan',
        service: ServiceType.realtimeTracking,
        now: t0.add(const Duration(minutes: 9)),
      );

      // Evaluate at t0 + 10 minutes (Threshold: 5 minutes)
      final stuck = engine.findStuckSpans(
        threshold: const Duration(minutes: 5),
        now: t0.add(const Duration(minutes: 10)),
      );

      expect(stuck.length, equals(1));
      expect(stuck.first.name, equals('StuckPaymentSpan'));
    });
  });
}
