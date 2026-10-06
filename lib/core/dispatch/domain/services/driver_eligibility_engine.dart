import '../entities/dispatch_candidate.dart';
import '../entities/driver_eligibility_result.dart';
import '../enums/dispatch_enums.dart';

/// محرك تدقيق أهلية السائق (Driver Eligibility Filtering Engine)
class DriverEligibilityEngine {
  const DriverEligibilityEngine();

  /// أقصى عمر مسموح لتحديث موقع GPS (15 دقيقة = 900 ثانية)
  static const int maxGpsAgeSeconds = 900;

  /// فحص أهلية السائق لاستقبال طلب توزيع محدد
  static DriverEligibilityResult checkEligibility({
    required DispatchCandidate candidate,
    required DispatchType dispatchType,
    int? customMaxGpsAgeSeconds,
    int? customMaxConcurrentOrders,
  }) {
    // 1. فحص الاتصال والنشاط
    if (!candidate.isOnline) {
      return DriverEligibilityResult.ineligible(
        DriverEligibilityStatus.offline,
        'السائق غير متصل (Offline)',
      );
    }

    // 2. فحص الاعتماد
    if (!candidate.isApproved) {
      return DriverEligibilityResult.ineligible(
        DriverEligibilityStatus.unapproved,
        'حساب السائق غير معتمد بعد',
      );
    }

    // 3. فحص الحظر والتعليق
    final status = candidate.status.trim().toLowerCase();
    if (status == 'suspended' || status == 'blocked' || status == 'banned') {
      return DriverEligibilityResult.ineligible(
        DriverEligibilityStatus.suspended,
        'حساب السائق معلق أو محظور',
      );
    }

    // 4. فحص الحمل الحالي (Driver Load)
    final maxLoad = customMaxConcurrentOrders ?? (dispatchType == DispatchType.taxi ? 1 : 2);
    if (candidate.activeOrdersCount >= maxLoad) {
      return DriverEligibilityResult.ineligible(
        DriverEligibilityStatus.busy,
        'السائق مشغول بالحد الأقصى للطلبات النشطة ($maxLoad)',
      );
    }

    // 5. فحص صلاحية إحداثيات الموقع
    if (candidate.latitude == 0.0 && candidate.longitude == 0.0) {
      return DriverEligibilityResult.ineligible(
        DriverEligibilityStatus.invalidLocation,
        'موقع السائق غير صالح أو مفقود',
      );
    }

    // 6. فحص حداثة إشارة الـ GPS
    final allowedGpsAge = customMaxGpsAgeSeconds ?? maxGpsAgeSeconds;
    if (candidate.gpsAgeSeconds > allowedGpsAge) {
      return DriverEligibilityResult.ineligible(
        DriverEligibilityStatus.staleGps,
        'إشارة GPS قديمة (${candidate.gpsAgeSeconds} ثانية)',
      );
    }

    // 7. فحص تطابق الخدمة (Service Compatibility)
    final role = candidate.role.trim().toLowerCase();
    if (dispatchType == DispatchType.taxi) {
      final isTaxiRole = role.contains('taxi') || role.contains('captain');
      if (!isTaxiRole && role != 'driver') {
        return DriverEligibilityResult.ineligible(
          DriverEligibilityStatus.incompatibleService,
          'السائق غير مصرح له بتقديم خدمة التكسي',
        );
      }
    }

    return DriverEligibilityResult.eligible();
  }
}
