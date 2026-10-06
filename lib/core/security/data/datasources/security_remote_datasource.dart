import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/security_models.dart';

/// مصدر البيانات البعيد للأمان وطلبات الاسترداد
class SecurityRemoteDatasource {
  final FirebaseFirestore? _customFirestore;

  SecurityRemoteDatasource({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  /// إرسال طلب استرداد مالي إلى Firestore
  Future<RefundRequestEntity> submitRefundRequest(RefundRequestEntity request) async {
    final docRef = _firestore.collection('refund_requests').doc();
    final data = request.toMap();
    data['id'] = docRef.id;
    data['createdAt'] = FieldValue.serverTimestamp();

    await docRef.set(data);
    return RefundRequestEntity(
      id: docRef.id,
      orderId: request.orderId,
      orderSource: request.orderSource,
      userId: request.userId,
      amount: request.amount,
      points: request.points,
      reason: request.reason,
      status: RefundStatus.pending,
      idempotencyKey: request.idempotencyKey,
      createdAt: DateTime.now(),
    );
  }

  /// جلب طلبات الاسترداد لمستخدم
  Future<List<RefundRequestEntity>> getUserRefundRequests(String userId) async {
    final snapshot = await _firestore
        .collection('refund_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => RefundRequestEntity.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// تسجيل حادثة أمنية
  Future<void> logSecurityViolation(SecurityViolation violation) async {
    await _firestore.collection('security_violations').add(violation.toMap());
  }

  /// التحقق من عدم تكرار مفتاح المعاملة
  Future<bool> verifyIdempotencyKey(String idempotencyKey) async {
    final doc = await _firestore.collection('idempotency_keys').doc(idempotencyKey).get();
    if (doc.exists) {
      return false; // المفتاح مستخدم مسبقاً
    }
    await _firestore.collection('idempotency_keys').doc(idempotencyKey).set({
      'key': idempotencyKey,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  }
}
