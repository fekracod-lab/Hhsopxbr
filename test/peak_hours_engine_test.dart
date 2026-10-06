import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/pricing/domain/entities/pricing_policy.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/peak_hours_engine.dart';

void main() {
  group('Peak Hours Engine Dedicated Tests', () {
    test('1. Returns 1.0 multiplier when peak periods list is empty', () {
      final multiplier = PeakHoursEngine.calculatePeakMultiplier(
        time: DateTime.now(),
        peakPeriods: const [],
      );
      expect(multiplier, equals(1.0));
    });

    test('2. Honors disabled peak periods', () {
      const disabledPeak = PeakPeriod(
        startHour: 8,
        endHour: 10,
        multiplier: 1.5,
        isEnabled: false,
      );

      final multiplier = PeakHoursEngine.calculatePeakMultiplier(
        time: DateTime(2026, 8, 28, 9, 0),
        peakPeriods: [disabledPeak],
      );
      expect(multiplier, equals(1.0));
    });

    test('3. Honors applicable days filter (e.g. Friday peak only)', () {
      const fridayPeak = PeakPeriod(
        startHour: 14,
        endHour: 22,
        multiplier: 1.4,
        applicableDays: [DateTime.friday], // Friday only (5)
      );

      // Friday 16:00 -> Matches
      final fridayTime = DateTime(2026, 8, 28, 16, 0); // 2026-08-28 is Friday
      expect(
        PeakHoursEngine.calculatePeakMultiplier(time: fridayTime, peakPeriods: [fridayPeak]),
        equals(1.4),
      );

      // Saturday 16:00 -> Does not match
      final saturdayTime = DateTime(2026, 8, 29, 16, 0);
      expect(
        PeakHoursEngine.calculatePeakMultiplier(time: saturdayTime, peakPeriods: [fridayPeak]),
        equals(1.0),
      );
    });

    test('4. Selects highest multiplier when periods overlap', () {
      const peakA = PeakPeriod(startHour: 16, endHour: 20, multiplier: 1.2);
      const peakB = PeakPeriod(startHour: 17, endHour: 19, multiplier: 1.5);

      final multiplier = PeakHoursEngine.calculatePeakMultiplier(
        time: DateTime(2026, 8, 28, 18, 0),
        peakPeriods: [peakA, peakB],
      );
      expect(multiplier, equals(1.5));
    });
  });
}
