import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/services/idempotency_engine.dart';

void main() {
  group('Idempotency Engine Dedicated Tests', () {
    test('1. Executes operation and stores canonical result', () async {
      final engine = IdempotencyEngine();
      int mutationCounter = 0;

      final res = await engine.executeIdempotent<String>(
        idempotencyKey: 'tx_create_order_100',
        operation: () async {
          mutationCounter++;
          return 'ORDER_#100_CREATED';
        },
      );

      expect(res, equals('ORDER_#100_CREATED'));
      expect(mutationCounter, equals(1));
      expect(engine.hasResult('tx_create_order_100'), isTrue);
    });

    test('2. Returns exact canonical result on duplicate request without re-executing', () async {
      final engine = IdempotencyEngine();
      int mutationCounter = 0;

      // First call
      final res1 = await engine.executeIdempotent<Map<String, dynamic>>(
        idempotencyKey: 'key_wallet_debit_99',
        operation: () async {
          mutationCounter++;
          return {'status': 'DEBITED', 'amount': 5000};
        },
      );

      // Duplicate call with same key
      final res2 = await engine.executeIdempotent<Map<String, dynamic>>(
        idempotencyKey: 'key_wallet_debit_99',
        operation: () async {
          mutationCounter++;
          return {'status': 'SHOULD_NOT_EXECUTE'};
        },
      );

      expect(res1, equals({'status': 'DEBITED', 'amount': 5000}));
      expect(res2, equals({'status': 'DEBITED', 'amount': 5000}));
      expect(mutationCounter, equals(1)); // Executed exactly ONCE!
    });

    test('3. Concurrent Single-Flight: 50 simultaneous calls on same key execute exactly 1 mutation', () async {
      final engine = IdempotencyEngine();
      int mutationCounter = 0;

      final futures = List.generate(50, (i) {
        return engine.executeIdempotent<String>(
          idempotencyKey: 'race_ride_assign_77',
          operation: () async {
            await Future.delayed(const Duration(milliseconds: 10));
            mutationCounter++;
            return 'RIDE_ASSIGNED_DRIVER_D1';
          },
        );
      });

      final results = await Future.wait(futures);

      expect(mutationCounter, equals(1)); // Exactly 1 winner!
      expect(results.length, equals(50));
      for (final r in results) {
        expect(r, equals('RIDE_ASSIGNED_DRIVER_D1'));
      }
    });
  });
}
