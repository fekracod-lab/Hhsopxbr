import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/services/concurrency_guard_engine.dart';

void main() {
  group('Concurrency Guard & Mutex Dedicated Tests', () {
    test('1. 100 concurrent candidate drivers competing for single ride assignment produce exactly 1 winner', () async {
      final guard = ConcurrencyGuardEngine();

      final futures = List.generate(100, (i) {
        return guard.acquireExclusiveAssignment(
          resourceId: 'ride_req_999',
          candidateId: 'driver_$i',
        );
      });

      final results = await Future.wait(futures);

      final winners = results.where((r) => r.$1 == true).toList();
      final losers = results.where((r) => r.$1 == false).toList();

      expect(winners.length, equals(1)); // Exactly 1 candidate won the ride!
      expect(losers.length, equals(99));  // 99 candidates received clean loss without double-assignment

      final winningDriverId = winners.first.$2;
      for (final loser in losers) {
        expect(loser.$2, equals(winningDriverId)); // All losers acknowledge the same winning driver
      }
    });

    test('2. 500 concurrent claims on single store inventory product yield exactly 1 winner', () async {
      final guard = ConcurrencyGuardEngine();

      final futures = List.generate(500, (i) {
        return guard.acquireExclusiveAssignment(
          resourceId: 'product_last_item_sku',
          candidateId: 'cart_user_$i',
        );
      });

      final results = await Future.wait(futures);
      final winners = results.where((r) => r.$1 == true).toList();

      expect(winners.length, equals(1));
      expect(results.length, equals(500));
    });

    test('3. Optimistic Concurrency CAS (Compare-And-Swap) blocks stale version updates', () async {
      final guard = ConcurrencyGuardEngine();

      // Initial version 0 -> 1
      final (res1, ok1, _) = await guard.compareAndSwap<String>(
        resourceId: 'order_status_doc',
        expectedVersion: 0,
        updateAction: () async => 'UPDATED_TO_PREPARING',
      );

      expect(ok1, isTrue);
      expect(res1, equals('UPDATED_TO_PREPARING'));
      expect(guard.versions['order_status_doc'], equals(1));

      // Attempt update with stale version 0 -> Conflict!
      final (res2, ok2, err2) = await guard.compareAndSwap<String>(
        resourceId: 'order_status_doc',
        expectedVersion: 0,
        updateAction: () async => 'STALE_MUTATION',
      );

      expect(ok2, isFalse);
      expect(res2, isNull);
      expect(err2, contains('Optimistic concurrency conflict'));
    });
  });
}
