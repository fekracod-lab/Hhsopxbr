import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/observability/observability.dart';

void main() {
  group('Observability & PerformanceTracker Unit Tests', () {
    test('PerformanceTracker should record start, stop, duration, and metadata', () async {
      PerformanceTracker.clear();

      PerformanceTracker.startTrace('test_bootstrap', metadata: {'mode': 'test'});
      await Future.delayed(const Duration(milliseconds: 20));
      final record = PerformanceTracker.stopTrace('test_bootstrap', isSuccess: true, details: 'OK');

      expect(record, isNotNull);
      expect(record!.name, equals('test_bootstrap'));
      expect(record.isSuccess, isTrue);
      expect(record.durationMs, greaterThanOrEqualTo(15));
      expect(record.metadata['mode'], equals('test'));
      expect(record.metadata['details'], equals('OK'));
      expect(record.startTime, isNotNull);
      expect(record.endTime, isNotNull);

      final retrieved = PerformanceTracker.getTrace('test_bootstrap');
      expect(retrieved, equals(record));
    });

    test('PerformanceTracker should handle stopping non-existent trace safely', () {
      final record = PerformanceTracker.stopTrace('non_existent');
      expect(record, isNull);
    });

    test('CrashReporter.sanitize should scrub sensitive PII credentials', () {
      const raw1 = 'User auth failed for password=SuperSecret123&user=john';
      expect(CrashReporter.sanitize(raw1), equals('User auth failed for password=[REDACTED]&user=john'));

      const raw2 = 'Invalid token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
      expect(CrashReporter.sanitize(raw2), equals('Invalid token=[REDACTED]'));

      const raw3 = 'OTP verification failed with otp=849201';
      expect(CrashReporter.sanitize(raw3), equals('OTP verification failed with otp=[REDACTED]'));

      const raw4 = 'Payment card number 4111 2222 3333 4444 declined';
      expect(CrashReporter.sanitize(raw4), equals('Payment card number [CARD_REDACTED] declined'));
    });

    test('AppLogger should log without throwing exceptions', () {
      expect(() => AppLogger.debug('Debug message test', tag: 'Test'), returnsNormally);
      expect(() => AppLogger.info('Info message test', tag: 'Test'), returnsNormally);
      expect(() => AppLogger.warning('Warning message test', tag: 'Test'), returnsNormally);
      expect(() => AppLogger.error('Error message test', tag: 'Test'), returnsNormally);
      expect(() => AppLogger.fatal('Fatal message test', tag: 'Test'), returnsNormally);
    });
  });
}
