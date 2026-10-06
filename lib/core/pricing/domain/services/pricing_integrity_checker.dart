import '../entities/fare_breakdown.dart';
import '../entities/pricing_snapshot.dart';
import '../enums/pricing_enums.dart';

/// فاحص النزاهة والتلاعب في التسعير (Pricing Integrity Hash Checker)
class PricingIntegrityChecker {
  const PricingIntegrityChecker();

  static const String _secretSalt = 'madar_pricing_integrity_secure_salt_2026';

  /// توليد كود التجزئة المشفر للقطة السعر لمنع التلاعب
  static String generateCalculationHash({
    required String orderId,
    required int pricingPolicyVersion,
    required PricingServiceType serviceType,
    required FareBreakdown breakdown,
  }) {
    final payload = 'ord:$orderId|pol:$pricingPolicyVersion|srv:${serviceType.key}|'
        'base:${breakdown.baseFare}|dist:${breakdown.distanceFare}|'
        'time:${breakdown.timeFare}|pkg:${breakdown.packageFee}|'
        'surge:${breakdown.surgeMultiplier}|peak:${breakdown.peakMultiplier}|'
        'sub:${breakdown.subtotal}|final:${breakdown.finalFare}|salt:$_secretSalt';

    return _computeSecureHexHash(payload);
  }

  /// التحقق من مطابقة وسلامة لقطة السعر ضد أي تلاعب
  static bool verifySnapshotIntegrity(PricingSnapshot snapshot) {
    final expectedHash = generateCalculationHash(
      orderId: snapshot.orderId,
      pricingPolicyVersion: snapshot.pricingPolicyVersion,
      serviceType: snapshot.serviceType,
      breakdown: snapshot.fareBreakdown,
    );

    return snapshot.calculationHash == expectedHash;
  }

  /// خوارزمية FNV-1a 64-bit المشفرة الحتمية
  static String _computeSecureHexHash(String input) {
    var hash1 = 0xcbf29ce484222325;
    var hash2 = 0x84222325cbf29ce4;
    const prime1 = 0x100000001b3;
    const prime2 = 0x1b310000000;

    for (var i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      hash1 = (hash1 ^ code) * prime1;
      hash2 = (hash2 ^ (code + i)) * prime2;
    }

    final part1 = (hash1 & 0xFFFFFFFFFFFFFFFF).toRadixString(16).padLeft(16, '0');
    final part2 = (hash2 & 0xFFFFFFFFFFFFFFFF).toRadixString(16).padLeft(16, '0');
    return 'hsh_$part1$part2';
  }
}
