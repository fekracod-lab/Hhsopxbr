import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/security/security.dart';

void main() {
  group('Privacy & PII Protection Engine Dedicated Tests', () {
    const privacy = PrivacyEngine();

    test('1. Masks personal phone numbers safely', () {
      final masked = privacy.maskPhoneNumber('07801234567');
      expect(masked, equals('078****4567'));
    });

    test('2. Masks personal email addresses safely', () {
      final masked = privacy.maskEmail('captain_ali@madar.iq');
      expect(masked, equals('c***i@madar.iq'));
    });

    test('3. Coarsens precise GPS coordinates for privacy logs', () {
      final (lat, lng) = privacy.coarsenLocation(33.3128456, 44.3614987);
      expect(lat, equals(33.31));
      expect(lng, equals(44.36));
    });

    test('4. Sanitizes nested data maps according to sensitivity descriptors', () {
      final payload = {
        'customerName': 'Omar',
        'phoneNumber': '07801234567',
        'email': 'omar@madar.iq',
        'password': 'RawPassword123!',
        'cardNumber': '4111222233334444',
      };

      final sanitized = privacy.sanitizeMap(payload);
      expect(sanitized['customerName'], equals('Omar'));
      expect(sanitized['phoneNumber'], equals('078****4567'));
      expect(sanitized['email'], equals('o***r@madar.iq'));
      expect(sanitized['password'], equals('[REDACTED_HIGHLY_SENSITIVE]'));
      expect(sanitized['cardNumber'], equals('[REDACTED_HIGHLY_SENSITIVE]'));
    });
  });
}
