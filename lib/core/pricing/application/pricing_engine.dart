import '../domain/entities/fare_request.dart';
import '../domain/entities/fare_breakdown.dart';
import '../domain/entities/pricing_policy.dart';
import '../domain/entities/pricing_snapshot.dart';
import '../domain/enums/pricing_enums.dart';
import '../domain/services/fare_calculator.dart';
import '../domain/services/pricing_integrity_checker.dart';
import '../domain/repositories/i_pricing_repository.dart';
import '../data/repositories/pricing_repository.dart';

/// المحرك المركزي للتسعير الديناميكي والأجرة (Dynamic Pricing & Fare Engine)
class PricingEngine {
  static PricingEngine? _instance;
  static PricingEngine get instance => _instance ??= PricingEngine();

  final IPricingRepository _repository;

  PricingEngine({IPricingRepository? repository})
      : _repository = repository ?? PricingRepository();

  /// احتساب الأجرة وتفصيل المكونات
  Future<FareBreakdown> calculateFare({
    required FareRequest request,
    PricingPolicy? customPolicy,
  }) async {
    final policy = customPolicy ?? await _repository.getActivePolicy(request.serviceType);
    return FareCalculator.calculateFare(
      request: request,
      policy: policy,
    );
  }

  /// إنشاء وتثبيت لقطة السعر غير القابلة للتعديل والمحمية بالـ Hash
  Future<PricingSnapshot> createAndPersistSnapshot({
    required String orderId,
    required FareRequest request,
    PricingPolicy? customPolicy,
  }) async {
    final policy = customPolicy ?? await _repository.getActivePolicy(request.serviceType);
    final breakdown = FareCalculator.calculateFare(
      request: request,
      policy: policy,
    );

    final hash = PricingIntegrityChecker.generateCalculationHash(
      orderId: orderId,
      pricingPolicyVersion: policy.version,
      serviceType: request.serviceType,
      breakdown: breakdown,
    );

    final snapshot = PricingSnapshot(
      snapshotId: 'snap-$orderId',
      orderId: orderId,
      pricingPolicyVersion: policy.version,
      serviceType: request.serviceType,
      fareBreakdown: breakdown,
      calculationHash: hash,
      calculatedAt: DateTime.now(),
    );

    return await _repository.saveSnapshot(snapshot);
  }

  /// فحص سلامة وتطابق لقطة السعر ضد أي تلاعب
  bool verifySnapshotIntegrity(PricingSnapshot snapshot) {
    return PricingIntegrityChecker.verifySnapshotIntegrity(snapshot);
  }

  /// جلب لقطة سابقة
  Future<PricingSnapshot?> getSnapshot(String snapshotId) {
    return _repository.getSnapshot(snapshotId);
  }

  // =========================================================================
  // Backward Compatibility Helpers (محولات التوافق مع الأنظمة السابقة)
  // =========================================================================

  /// حساب سريع لأجرة توصيل طعام أو متجر (بالدينار العراقي)
  static int estimateDeliveryFee({
    required double distanceKm,
    bool isStore = false,
  }) {
    final policy = isStore ? PricingPolicy.defaultStorePolicy : PricingPolicy.defaultFoodPolicy;
    final breakdown = FareCalculator.calculateFare(
      request: FareRequest(
        serviceType: isStore ? PricingServiceType.store : PricingServiceType.food,
        distanceMeters: distanceKm * 1000.0,
        requestedAt: DateTime.now(),
        idempotencyKey: 'quick_est_${DateTime.now().millisecondsSinceEpoch}',
      ),
      policy: policy,
    );
    return breakdown.finalFare;
  }

  /// حساب سريع لأجرة رحلة تكسي (بالدينار العراقي)
  static int estimateTaxiFare({
    required double distanceKm,
    int durationMinutes = 10,
  }) {
    final breakdown = FareCalculator.calculateFare(
      request: FareRequest(
        serviceType: PricingServiceType.taxi,
        distanceMeters: distanceKm * 1000.0,
        estimatedDurationSeconds: durationMinutes * 60,
        requestedAt: DateTime.now(),
        idempotencyKey: 'quick_taxi_${DateTime.now().millisecondsSinceEpoch}',
      ),
      policy: PricingPolicy.defaultTaxiPolicy,
    );
    return breakdown.finalFare;
  }
}
