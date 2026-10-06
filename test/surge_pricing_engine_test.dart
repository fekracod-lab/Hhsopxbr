import 'package:flutter_test/flutter_test.dart';
import 'package:dalal_alqaim/core/pricing/domain/enums/pricing_enums.dart';
import 'package:dalal_alqaim/core/pricing/domain/entities/pricing_policy.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/demand_pressure_engine.dart';
import 'package:dalal_alqaim/core/pricing/domain/services/surge_pricing_engine.dart';

void main() {
  group('Surge Pricing & Demand Pressure Engine Dedicated Tests', () {
    test('1. Handles zero demand with normal surge state', () {
      final surge = DemandPressureEngine.calculateSurge(
        activeDemand: 0,
        availableSupply: 10,
      );
      expect(surge.level, equals(SurgeLevel.normal));
      expect(surge.multiplier, equals(1.0));
      expect(surge.hasSurge, isFalse);
    });

    test('2. Handles zero supply with critical capped multiplier', () {
      final surge = DemandPressureEngine.calculateSurge(
        activeDemand: 20,
        availableSupply: 0,
        maxMultiplier: 2.0,
      );
      expect(surge.level, equals(SurgeLevel.critical));
      expect(surge.multiplier, equals(2.0));
      expect(surge.hasSurge, isTrue);
    });

    test('3. Enforces custom maxMultiplier from policy', () {
      final surge = DemandPressureEngine.calculateSurge(
        activeDemand: 100,
        availableSupply: 1,
        maxMultiplier: 1.5, // Capped at 1.5x
      );
      expect(surge.multiplier, equals(1.5));
    });

    test('4. SurgePricingEngine merges peak hours and demand pressure correctly', () {
      final policy = PricingPolicy.defaultTaxiPolicy;

      // Peak hour (18:00 -> 1.3x) with normal demand (1.0x) -> 1.3x
      final peakOnlyState = SurgePricingEngine.resolveSurgeState(
        time: DateTime(2026, 8, 28, 18, 0),
        policy: policy,
        activeDemand: 1,
        availableSupply: 10,
      );
      expect(peakOnlyState.multiplier, equals(1.3));

      // Off-peak (12:00 -> 1.0x) with critical demand (2.0x) -> 2.0x
      final demandOnlyState = SurgePricingEngine.resolveSurgeState(
        time: DateTime(2026, 8, 28, 12, 0),
        policy: policy,
        activeDemand: 50,
        availableSupply: 1,
      );
      expect(demandOnlyState.multiplier, equals(2.0));
    });
  });
}
