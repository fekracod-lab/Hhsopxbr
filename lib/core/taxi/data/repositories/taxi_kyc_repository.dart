import 'package:cloud_firestore/cloud_firestore.dart';

/// مستودع طلبات انضمام كباتن التكسي (Taxi KYC Repository)
/// يستعلم حصرياً من driver_requests لكباتن التكسي مع استبعاد طلبات الدليفري.
class TaxiKycRepository {
  final FirebaseFirestore _firestore;

  TaxiKycRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// دفق طلبات انضمام كباتن التكسي المعلقة
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamPendingTaxiKycRequests() {
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
        return !isDelivery;
      }).toList();
    });
  }

  /// دفق عدد طلبات التكسي المعلقة
  Stream<int> streamPendingTaxiKycCount() {
    return streamPendingTaxiKycRequests().map((docs) => docs.length);
  }

  /// اعتماد طلب انضمام كابتن تكسي
  Future<void> approveTaxiKyc({
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
    final driverPayload = <String, dynamic>{
      'uid': uid,
      'fullName': requestData['fullName'] ?? requestData['name'] ?? '',
      'phone': requestData['phone'] ?? '',
      'carNumber': requestData['carNumber'] ?? '',
      'plateGovernorate': requestData['plateGovernorate'] ?? '',
      'plateLetter': requestData['plateLetter'] ?? '',
      'plateType': requestData['plateType'] ?? '',
      'fullCarPlate': requestData['fullCarPlate'] ?? '',
      'carType': requestData['carType'] ?? '',
      'carModel': requestData['carModel'] ?? '',
      'carYear': requestData['carYear'] ?? '',
      'carColor': requestData['carColor'] ?? '',
      'serviceType': requestData['serviceType'] ?? '',
      'governorate': requestData['governorateName'] ?? requestData['governorate'] ?? '',
      'governorateName': requestData['governorateName'] ?? requestData['governorate'] ?? '',
      'governorateId': requestData['governorateId'],
      'regionId': requestData['regionId'],
      'regionName': requestData['regionName'],
      'subRegionName': requestData['subRegionName'] ?? '',
      'rating': 5.0,
      'available': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'active',
      'role': 'driver',
    };
    if (requestData['photoUrl'] != null) {
      driverPayload['photoUrl'] = requestData['photoUrl'];
    }
    if (requestData['carPhotoUrl'] != null && (requestData['carPhotoUrl'] as String).isNotEmpty) {
      driverPayload['carPhotoUrl'] = requestData['carPhotoUrl'];
      driverPayload['carImage'] = requestData['carPhotoUrl'];
    }
    batch.set(driverRef, driverPayload, SetOptions(merge: true));

    final userRef = _firestore.collection('users').doc(uid);
    batch.set(userRef, {
      'isDriver': true,
      'role': 'driver',
      'status': 'active',
      'approvedAt': FieldValue.serverTimestamp(),
      'fullCarPlate': requestData['fullCarPlate'] ?? '',
      'plateGovernorate': requestData['plateGovernorate'] ?? '',
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// رفض طلب انضمام كابتن تكسي
  Future<void> rejectTaxiKyc({
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
      'rejectionReason': reason ?? 'لم يتم استيفاء الشروط المطلوبة',
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
