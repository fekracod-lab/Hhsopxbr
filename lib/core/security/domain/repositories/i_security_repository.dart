import '../entities/security_models.dart';

/// العقد التجريدي لمستودع الأمان والرقابة في منصة مدار
abstract class ISecurityRepository {
  /// تقديم طلب استرداد مالي موثق
  Future<RefundRequestEntity> submitRefundRequest(RefundRequestEntity request);

  /// جلب طلبات الاسترداد لمستخدم معين
  Future<List<RefundRequestEntity>> getUserRefundRequests(String userId);

  /// تسجيل حادثة أمنية في سجل الرقابة
  Future<void> logSecurityViolation(SecurityViolation violation);

  /// التحقق من عدم تكرار مفتاح المعاملة
  Future<bool> verifyIdempotencyKey(String idempotencyKey);
}
