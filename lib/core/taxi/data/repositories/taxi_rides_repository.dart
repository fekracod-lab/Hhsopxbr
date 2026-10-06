import 'package:cloud_firestore/cloud_firestore.dart';

/// مستودع رحلات التكسي المنفصل (Taxi Rides Repository)
/// يستعلم حصرياً من مجموعة ride_requests فقط دون دمج مع طلبات التوصيل أو الوجبات.
class TaxiRidesRepository {
  final FirebaseFirestore _firestore;

  TaxiRidesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// دفق جميع رحلات التكسي مع إمكانية الفلترة بالحالة
  Stream<QuerySnapshot<Map<String, dynamic>>> streamTaxiRides({String? status}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('ride_requests')
        .orderBy('createdAt', descending: true);

    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots();
  }

  /// جلب رحلة تكسي محددة
  Future<DocumentSnapshot<Map<String, dynamic>>?> getTaxiRide(String rideId) async {
    final doc = await _firestore.collection('ride_requests').doc(rideId).get();
    if (!doc.exists) return null;
    return doc;
  }

  /// تحديث حالة رحلة التكسي
  Future<void> updateTaxiRideStatus(String rideId, String newStatus, {Map<String, dynamic>? extraData}) async {
    final payload = <String, dynamic>{
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (extraData != null) {
      payload.addAll(extraData);
    }
    await _firestore.collection('ride_requests').doc(rideId).update(payload);
  }

  /// دفق عدد رحلات التكسي حسب الحالة
  Stream<int> streamTaxiRidesCount({String? status}) {
    Query<Map<String, dynamic>> query = _firestore.collection('ride_requests');
    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots().map((s) => s.docs.length);
  }
}
