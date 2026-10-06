import 'package:cloud_firestore/cloud_firestore.dart';

/// مستودع طلبات انضمام مناديب التوصيل / مرسال (Mersal KYC Repository)
/// يستعلم حصرياً من driver_requests لطلبات الدليفري فقط (isDelivery == true).
class MersalKycRepository {
  final FirebaseFirestore _firestore;

  MersalKycRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// دفق طلبات انضمام مناديب الدليفري المعلقة
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamPendingMersalKycRequests() {
    return _firestore
        .collection('driver_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data();
        final isDelivery = data['isDelivery'] == true ||
            data['role'] == 'delivery' ||
            data['subRole'] == 'delivery';
        return isDelivery;
      }).toList();
    });
  }

  /// دفق عدد طلبات الدليفري المعلقة
  Stream<int> streamPendingMersalKycCount() {
    return streamPendingMersalKycRequests().map((docs) => docs.length);
  }

  /// اعتماد طلب انضمام مندوب توصيل
  Future<void> approveMersalKyc({
    required String docId,
    required Map<String, dynamic> requestData,
  }) async {
    final batch = _firestore.batch();
    final uid = requestData['uid'] ?? requestData['id'] ?? docId;

    final reqRef = _firestore.collection('driver_requests').doc(docId);
    batch.update(reqRef, {
      'status': 'approved',
      'processedAt': FieldValue.serverTimestamp(),
    });

    final driverRef = _firestore.collection('drivers').doc(uid);
    batch.set(driverRef, {
      ...requestData,
      'uid': uid,
      'status': 'approved',
      'isApproved': true,
      'isDeliveryApproved': true,
      'available': false,
      'rating': 5.0,
      'type': 'delivery',
      'role': 'delivery_captain',
      'subRole': 'delivery',
      'isDelivery': true,
      'isDriver': true,
      'vehicleType': requestData['vehicleType'] ?? 'دراجة نارية',
      'fullCarPlate': requestData['fullCarPlate'] ?? requestData['carNumber'] ?? '',
      'plateGovernorate': requestData['plateGovernorate'] ?? '',
      'subRegionName': requestData['subRegionName'] ?? '',
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final userRef = _firestore.collection('users').doc(uid);
    batch.set(userRef, {
      'status': 'approved',
      'isApproved': true,
      'isDeliveryApproved': true,
      'isDriver': true,
      'isDelivery': true,
      'role': 'delivery_captain',
      'subRole': 'delivery',
      'vehicleType': requestData['vehicleType'] ?? 'دراجة نارية',
      'fullCarPlate': requestData['fullCarPlate'] ?? requestData['carNumber'] ?? '',
      'approvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// رفض طلب انضمام مندوب توصيل
  Future<void> rejectMersalKyc({
    required String docId,
    required String uid,
    String? reason,
  }) async {
    final batch = _firestore.batch();

    final reqRef = _firestore.collection('driver_requests').doc(docId);
    batch.update(reqRef, {
      'status': 'rejected',
      'rejectionReason': reason ?? 'لم يتم استيفاء الشروط المطلوبة',
      'processedAt': FieldValue.serverTimestamp(),
    });

    final userRef = _firestore.collection('users').doc(uid);
    batch.update(userRef, {
      'status': 'rejected',
      'isApproved': false,
      'isDeliveryApproved': false,
      'rejectionReason': reason ?? 'لم يتم استيفاء الشروط المطلوبة',
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
