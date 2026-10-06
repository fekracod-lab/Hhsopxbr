import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/resilience/services/concurrency_guard_engine.dart';

void main() {
  group('Chaos Scenario 015 & 017: Extreme Concurrency & Race Tests', () {
    test('CHAOS-015: 100 concurrent driver bids across 10 rides result in exactly 10 distinct assignments with zero overlap', () async {
      final guard = ConcurrencyGuardEngine();

      final futures = <Future<(bool, String)>>[];

      // 10 rides, each contested by 10 drivers (total 100 concurrent bids)
      for (int rideIndex = 0; rideIndex < 10; rideIndex++) {
        for (int driverIndex = 0; driverIndex < 10; driverIndex++) {
          futures.add(
            guard.acquireExclusiveAssignment(
              resourceId: 'ride_$rideIndex',
              candidateId: 'driver_${rideIndex}_$driverIndex',
            ),
          );
        }
      }

      final results = await Future.wait(futures);

      final winningBids = results.where((r) => r.$1 == true).toList();
      final losingBids = results.where((r) => r.$1 == false).toList();

      expect(winningBids.length, equals(10)); // Exactly 1 winner per ride!
      expect(losingBids.length, equals(90));  // Exactly 90 rejected bids

      final assignedDriverIds = winningBids.map((w) => w.$2).toSet();
      expect(assignedDriverIds.length, equals(10)); // 10 unique driver assignments
    });
  });
}
