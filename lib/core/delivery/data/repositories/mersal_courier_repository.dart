import 'package:cloud_firestore/cloud_firestore.dart';

/// مستودع مناديب وكباتن التوصيل / مرسال المنفصل (Mersal Courier Repository)
/// يستعلم حصرياً من مجموعة drivers لمناديب الدليفري فقط دون دمج مع كباتن التكسي.
class MersalCourierRepository {
  final FirebaseFirestore _firestore;

  MersalCourierRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// دفق جميع مناديب التوصيل المعتمدين
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMersalCouriers({String? status}) {
    Query<Map<String, dynamic>> query = _firestore.collection('drivers');

    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots().map((snapshot) {
      // عزل مناديب الدليفري بدقة وفق المحددات المعتمدة
      final deliveryDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final subRole = data['subRole']?.toString().toLowerCase();
        final type = data['type']?.toString().toLowerCase();
        final isDelivery = data['isDelivery'] == true;
        return subRole == 'delivery' || type == 'delivery' || isDelivery;
      }).toList();

      return _FilteredQuerySnapshot(deliveryDocs);
    });
  }

  /// جلب مندوب توصيل محدد
  Future<DocumentSnapshot<Map<String, dynamic>>?> getMersalCourier(String driverId) async {
    final doc = await _firestore.collection('drivers').doc(driverId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    if (data['subRole'] != 'delivery' && data['type'] != 'delivery' && data['isDelivery'] != true) {
      return null; // ليس مندوب توصيل
    }
    return doc;
  }

  /// تحديث حالة مندوب التوصيل
  Future<void> updateMersalCourierStatus({
    required String uid,
    required String newStatus,
  }) async {
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(uid);
    final driverRef = _firestore.collection('drivers').doc(uid);

    batch.update(userRef, {'status': newStatus, 'updatedAt': FieldValue.serverTimestamp()});
    batch.update(driverRef, {'status': newStatus, 'updatedAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  /// دفق عدد مناديب التوصيل النشطين
  Stream<int> streamActiveMersalCouriersCount() {
    return _firestore
        .collection('drivers')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data();
        return data['subRole'] == 'delivery' || data['type'] == 'delivery' || data['isDelivery'] == true;
      }).length;
    });
  }
}

class _FilteredQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  _FilteredQuerySnapshot(this.docs);

  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => [];

  @override
  SnapshotMetadata get metadata => const _DummySnapshotMetadata();

  @override
  int get size => docs.length;
}

class _DummySnapshotMetadata implements SnapshotMetadata {
  const _DummySnapshotMetadata();
  @override
  bool get hasPendingWrites => false;
  @override
  bool get isFromCache => false;
}
