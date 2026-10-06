import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/observability/domain/entities/metric_sample.dart';
import 'package:dalal_alqaim/core/observability/domain/enums/observability_enums.dart';
import 'package:dalal_alqaim/core/observability/domain/services/distributed_tracing_engine.dart';
import 'package:dalal_alqaim/core/observability/domain/services/health_monitor_engine.dart';
import 'package:dalal_alqaim/core/observability/domain/services/metrics_engine.dart';

void main() {
  group('Observability Adversarial, Concurrency & Chaos Tests', () {
    test('1. Concurrency: 30 simultaneous span start and finish operations complete cleanly', () async {
      final engine = DistributedTracingEngine();
      final now = DateTime.now();

      final futures = List.generate(30, (i) async {
        final span = engine.startSpan(
          traceId: 'trace_concurrent_$i',
          correlationId: 'corr_concurrent_$i',
          name: 'ConcurrentSpan_$i',
          service: ServiceType.orderEngine,
          now: now,
        );

        // Simulate tiny async work
        await Future.delayed(const Duration(milliseconds: 1));

        return engine.finishSpan(
          spanId: span.spanId,
          status: SpanStatus.ok,
          now: now.add(Duration(milliseconds: 10 + i)),
        );
      });

      final results = await Future.wait(futures);

      expect(results.length, equals(30));
      expect(results.every((s) => s != null && s.status == SpanStatus.ok), isTrue);
      expect(engine.completedSpans.length, equals(30));
      expect(engine.activeSpans.isEmpty, isTrue);
    });

    test('2. Chaos: Rapid health probe status flipping resolves deterministically to the latest state', () {
      final engine = HealthMonitorEngine();

      for (int i = 0; i < 20; i++) {
        final isHealthy = (i % 2 == 0);
        engine.recordProbeResult(
          service: ServiceType.gps,
          isHealthy: isHealthy,
          latencyMs: 100 + i,
        );
      }

      // 20th iteration (i = 19 -> odd -> false) -> 1 failure -> degraded
      final report = engine.generateReport();
      expect(report.services[ServiceType.gps]!.status, equals(HealthStatus.degraded));
    });

    test('3. High-Frequency Burst: Ingesting 1,000 metrics executes with sub-millisecond efficiency', () {
      final engine = MetricsEngine();
      final now = DateTime.now();

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 1000; i++) {
        engine.recordSample(
          MetricSample(
            metricName: 'burst_counter',
            value: i.toDouble(),
            timestamp: now,
          ),
        );
      }

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Sub 100ms for 1000 samples
      final snapshot = engine.generateSnapshot(now: now);
      expect(snapshot.snapshotId.isNotEmpty, isTrue);
    });
  });
}
