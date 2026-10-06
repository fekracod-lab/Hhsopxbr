import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/dispatch_candidate.dart';
import '../../domain/entities/dispatch_offer.dart';
import '../../domain/entities/dispatch_session.dart';
import '../../domain/enums/dispatch_enums.dart';
import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';
import 'package:dalal_alqaim/services/notification_service.dart';

/// مصدر البيانات البعيد للتوزيع الذكي وتعيين السائقين (Dispatch Remote Datasource)
class DispatchRemoteDatasource {
  final FirebaseFirestore? _customFirestore;

  DispatchRemoteDatasource({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  /// جلب السائقين المتصلين حسب نوع الخدمة
  Future<List<DispatchCandidate>> getOnlineDrivers({required DispatchType dispatchType}) async {
    final query = await _firestore
        .collection('drivers')
        .where('available', isEqualTo: true)
        .limit(100)
        .get();

    return query.docs
        .map((doc) => DispatchCandidate.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// إنشاء جلسة توزيع
  Future<DispatchSession> createSession(DispatchSession session) async {
    final docRef = _firestore.collection('dispatch_sessions').doc(session.sessionId);
    await docRef.set(session.toMap());
    return session;
  }

  /// جلب بيانات جلسة التوزيع
  Future<DispatchSession?> getSession(String sessionId) async {
    final doc = await _firestore.collection('dispatch_sessions').doc(sessionId).get();
    if (!doc.exists || doc.data() == null) return null;
    return DispatchSession.fromMap(doc.data()!, doc.id);
  }

  /// إنشاء عرض وإرساله للسائق
  Future<DispatchOffer> createOffer(DispatchOffer offer) async {
    final docRef = _firestore.collection('dispatch_offers').doc(offer.offerId);
    await docRef.set(offer.toMap());

    // إرسال إشعار فوري للسائق
    try {
      await NotificationService.emitEvent(
        type: 'new_dispatch_offer',
        payload: {
          'driverId': offer.driverId,
          'offerId': offer.offerId,
          'orderId': offer.orderId,
          'expiresAt': offer.expiresAt.toIso8601String(),
        },
      );
    } catch (_) {}

    return offer;
  }

  /// جلب بيانات العرض
  Future<DispatchOffer?> getOffer(String offerId) async {
    final doc = await _firestore.collection('dispatch_offers').doc(offerId).get();
    if (!doc.exists || doc.data() == null) return null;
    return DispatchOffer.fromMap(doc.data()!, doc.id);
  }

  /// قبول العرض وتعيين السائق ذرياً مع حماية السباق (Atomic Acceptance)
  Future<bool> acceptOfferAtomic({
    required String offerId,
    required String driverId,
    required String orderId,
    required DispatchType dispatchType,
  }) async {
    final offerRef = _firestore.collection('dispatch_offers').doc(offerId);
    
    await _firestore.runTransaction((tx) async {
      // 1. فحص العرض
      final offerSnap = await tx.get(offerRef);
      if (!offerSnap.exists || offerSnap.data() == null) {
        throw const SecurityViolationException(
          'عرض التوزيع غير موجود',
          type: SecurityViolationType.unauthorizedFinancialMutation,
        );
      }
      final offer = DispatchOffer.fromMap(offerSnap.data()!, offerSnap.id);
      if (offer.isExpired || offer.status == DispatchOfferStatus.expired) {
        throw const SecurityViolationException(
          'انتهت صلاحية هذا العرض',
          type: SecurityViolationType.unauthorizedFinancialMutation,
        );
      }
      if (offer.status == DispatchOfferStatus.accepted) {
        return; // قبول مسبق
      }

      // 2. فحص جلسة التوزيع
      final sessionRef = _firestore.collection('dispatch_sessions').doc(offer.dispatchId);
      final sessionSnap = await tx.get(sessionRef);
      if (sessionSnap.exists && sessionSnap.data() != null) {
        final session = DispatchSession.fromMap(sessionSnap.data()!, sessionSnap.id);
        if (session.assignedDriverId != null && session.assignedDriverId != driverId) {
          throw const SecurityViolationException(
            'تم تعيين هذا الطلب لسائق آخر مسبقاً (Order Already Assigned)',
            type: SecurityViolationType.unauthorizedFinancialMutation,
          );
        }
      }

      // 3. فحص وتحديث وثيقة الطلب الرئيسية
      final orderCollection = dispatchType == DispatchType.taxi ? 'ride_requests' : 'orders';
      final orderRef = _firestore.collection(orderCollection).doc(orderId);
      final orderSnap = await tx.get(orderRef);
      if (orderSnap.exists && orderSnap.data() != null) {
        final currentDriverId = orderSnap.data()!['driverId']?.toString();
        if (currentDriverId != null && currentDriverId.isNotEmpty && currentDriverId != driverId) {
          throw const SecurityViolationException(
            'الطلب معين مسبقاً لكابتن آخر',
            type: SecurityViolationType.unauthorizedFinancialMutation,
          );
        }

        // تعيين السائق وتحديث الحالة
        final orderUpdates = <String, dynamic>{
          'driverId': driverId,
          'driverName': offer.driverName,
          'driverPhone': offer.driverPhone,
          'status': dispatchType == DispatchType.taxi ? 'accepted' : 'assigned',
          'updatedAt': FieldValue.serverTimestamp(),
        };
        tx.update(orderRef, orderUpdates);
      }

      // 4. تحديث العرض والجلسة
      tx.update(offerRef, {'status': DispatchOfferStatus.accepted.key});
      tx.update(sessionRef, {
        'status': DispatchStatus.assigned.key,
        'assignedDriverId': driverId,
        'assignedDriverName': offer.driverName,
        'assignedDriverPhone': offer.driverPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return true;
  }

  /// رفض العرض
  Future<bool> rejectOffer({
    required String offerId,
    required String driverId,
    required String reason,
  }) async {
    final offerRef = _firestore.collection('dispatch_offers').doc(offerId);
    await offerRef.update({
      'status': DispatchOfferStatus.rejected.key,
      'rejectReason': reason,
    });
    return true;
  }

  /// تحديث حالة الجلسة
  Future<void> updateSessionStatus(String sessionId, DispatchStatus status) async {
    final sessionRef = _firestore.collection('dispatch_sessions').doc(sessionId);
    await sessionRef.update({
      'status': status.key,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
