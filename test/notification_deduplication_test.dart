import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/notifications/domain/services/notification_deduplication_engine.dart';

void main() {
  group('Notification Deduplication Engine Dedicated Tests', () {
    test('1. Detects duplicate idempotency keys accurately', () {
      final engine = NotificationDeduplicationEngine();

      expect(engine.isDuplicate('idemp_abc_1'), isFalse);
      engine.markProcessed('idemp_abc_1');
      expect(engine.isDuplicate('idemp_abc_1'), isTrue);

      expect(engine.isDuplicate('idemp_abc_2'), isFalse);
    });

    test('2. Handles empty key gracefully', () {
      final engine = NotificationDeduplicationEngine();
      expect(engine.isDuplicate(''), isFalse);
    });

    test('3. Clear resets processed keys', () {
      final engine = NotificationDeduplicationEngine();
      engine.markProcessed('idemp_temp');
      expect(engine.isDuplicate('idemp_temp'), isTrue);
      engine.clear();
      expect(engine.isDuplicate('idemp_temp'), isFalse);
    });
  });
}
