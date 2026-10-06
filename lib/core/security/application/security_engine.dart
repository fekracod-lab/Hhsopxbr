import 'dart:math';
import '../domain/entities/security_models.dart';
import '../domain/repositories/i_security_repository.dart';
import '../domain/services/permission_guard.dart';
import '../domain/services/financial_operation_guard.dart';
import '../domain/services/tamper_detector.dart';
import '../data/repositories/security_repository.dart';

/// المحرك الأمني المركزي لمنظومة مدار (MADAR Security Engine)
class SecurityEngine {
  static SecurityEngine? _instance;
  static SecurityEngine get instance => _instance ??= SecurityEngine();

  final ISecurityRepository _repository;

  SecurityEngine({ISecurityRepository? repository})
      : _repository = repository ?? SecurityRepository();

  /// توليد مفتاح عدم تكرار فريد (Cryptographically robust Idempotency Key)
  String generateIdempotencyKey({String prefix = 'tx'}) {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$hex';
  }

  /// التحقق من صلاحية المستخدم
  void guardPermission(MadarRole role, MadarPermission permission) {
    if (!PermissionGuard.hasPermission(role, permission)) {
      throw SecurityViolationException(
        'المستخدم بدور (${role.key}) لا يملك صلاحية (${permission.name})',
        type: SecurityViolationType.unauthorizedRoleEscalation,
      );
    }
  }

  /// فحص وتدقيق حمولة التعديل لحساب المستخدم ومنع التلاعب بالرصيد
  void guardUserUpdatePayload(Map<String, dynamic> payload, {required MadarRole actorRole}) {
    TamperDetector.assertUserPayloadSafe(payload, actorRole: actorRole);
  }

  /// تدقيق والتحقق من العمليات المالية
  void validateFinancialPayload(FinancialOperationPayload payload) {
    FinancialOperationGuard.validatePayload(payload);
  }

  /// إرسال طلب استرداد مالي موثق (P0 Server-Authoritative Refund Pipeline)
  Future<RefundRequestEntity> submitOrderRefundRequest({
    required String orderId,
    required String orderSource,
    required String userId,
    required double amount,
    int points = 0,
    required String reason,
    String? idempotencyKey,
  }) async {
    final effectiveKey = idempotencyKey ?? generateIdempotencyKey(prefix: 'ref');

    // 1. التحقق الصارم من المدخلات
    FinancialOperationGuard.validateRefundRequest(
      orderId: orderId,
      userId: userId,
      amount: amount,
      points: points,
      idempotencyKey: effectiveKey,
    );

    // 2. التحقق من عدم تكرار الطلب
    final isUnique = await _repository.verifyIdempotencyKey(effectiveKey);
    if (!isUnique) {
      throw const SecurityViolationException(
        'تم إرسال طلب الاسترداد مسبقاً بنفس مفتاح المعاملة',
        type: SecurityViolationType.invalidIdempotency,
      );
    }

    final entity = RefundRequestEntity(
      id: '',
      orderId: orderId,
      orderSource: orderSource,
      userId: userId,
      amount: amount,
      points: points,
      reason: reason,
      status: RefundStatus.pending,
      idempotencyKey: effectiveKey,
      createdAt: DateTime.now(),
    );

    // 3. تقديم الطلب إلى مستودع الأمان
    return await _repository.submitRefundRequest(entity);
  }

  /// تسجيل حادثة أمنية
  Future<void> logViolation({
    required SecurityViolationType type,
    required String userId,
    required String actionAttempted,
    required String reason,
    String severity = 'HIGH',
    Map<String, dynamic> metadata = const {},
  }) async {
    final violation = SecurityViolation(
      type: type,
      userId: userId,
      actionAttempted: actionAttempted,
      reason: reason,
      severity: severity,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    await _repository.logSecurityViolation(violation);
  }
}
