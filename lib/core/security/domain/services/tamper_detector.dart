import '../entities/security_models.dart';

/// كاشف التلاعب ومحاولات الحقن غير المصرح بها (Payload Tamper Detector)
class TamperDetector {
  const TamperDetector();

  /// قائمة الحقول المحمية في حسابات المستخدمين (يُمنع تعديلها بواسطة العميل العادي نهائياً)
  static const Set<String> protectedUserFields = {
    'balance',
    'walletBalance',
    'points',
    'rewardsPoints',
    'totalEarnings',
    'walletEarnings',
    'totalCommission',
    'appDebt',
    'rating',
    'completedDeliveriesCount',
    'totalTrips',
    'totalOrders',
    'role',
    'isApproved',
    'status',
  };

  /// قائمة الحقول المالية الحساسة في الطلبات
  static const Set<String> protectedOrderFinancialFields = {
    'total',
    'subtotal',
    'deliveryFee',
    'discount',
    'commission',
    'driverEarnings',
    'merchantSettlement',
    'captainEarnings',
    'platformFee',
  };

  /// فحص ما إذا كانت الحمولة تحاول تعديل حقول محمية لمستخدم عادي
  static List<String> detectUserPayloadTampering(Map<String, dynamic> payload, {required MadarRole actorRole}) {
    if (actorRole.isAdmin) return const []; // المشرف مسموح له

    final violatedFields = <String>[];
    for (final key in payload.keys) {
      if (protectedUserFields.contains(key)) {
        violatedFields.add(key);
      }
    }
    return violatedFields;
  }

  /// فحص ما إذا كانت حمولة تعديل الطلب تحتوي على تغيير مالي غير مصرح
  static List<String> detectOrderPayloadTampering(Map<String, dynamic> payload, {required MadarRole actorRole}) {
    if (actorRole.isAdmin) return const [];

    final violatedFields = <String>[];
    for (final key in payload.keys) {
      if (protectedOrderFinancialFields.contains(key)) {
        violatedFields.add(key);
      }
    }
    return violatedFields;
  }

  /// رمي استثناء إذا وجد أي تلاعب
  static void assertUserPayloadSafe(Map<String, dynamic> payload, {required MadarRole actorRole}) {
    final violations = detectUserPayloadTampering(payload, actorRole: actorRole);
    if (violations.isNotEmpty) {
      throw SecurityViolationException(
        'محاولة غير مصرح بها لتعديل حقول مالية أو أمنية محمية: ${violations.join(", ")}',
        type: SecurityViolationType.unauthorizedFinancialMutation,
        fieldName: violations.first,
      );
    }
  }
}
