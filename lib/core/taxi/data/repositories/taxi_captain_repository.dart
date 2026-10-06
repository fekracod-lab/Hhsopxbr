import 'package:cloud_firestore/cloud_firestore.dart';

/// مستودع كباتن التكسي المنفصل (Taxi Captain Repository)
/// يستعلم حصرياً من مجموعة drivers لكباتن التكسي فقط دون دمج مع الدليفري.
class TaxiCaptainRepository {
  final FirebaseFirestore _firestore;

  TaxiCaptainRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// دفق جميع كباتن التكسي المعتمدين
  Stream<QuerySnapshot<Map<String, dynamic>>> streamTaxiCaptains({String? status}) {
    Query<Map<String, dynamic>> query = _firestore.collection('drivers');

    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots().map((snapshot) {
      // عزل كباتن التكسي واستبعاد مناديب الدليفري بدقة وفق المحددات المعتمدة
      final taxiDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final subRole = data['subRole']?.toString().toLowerCase();
        final type = data['type']?.toString().toLowerCase();
        final isDelivery = data['isDelivery'] == true;
        return subRole != 'delivery' && type != 'delivery' && !isDelivery;
      }).toList();

      return _FilteredQuerySnapshot(taxiDocs);
    });
  }

  /// جلب كابتن تكسي محدد
  Future<DocumentSnapshot<Map<String, dynamic>>?> getTaxiCaptain(String driverId) async {
    final doc = await _firestore.collection('drivers').doc(driverId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    if (data['subRole'] == 'delivery' || data['type'] == 'delivery' || data['isDelivery'] == true) {
      return null; // ليس كابتن تكسي
    }
    return doc;
  }

  /// تحديث حالة كابتن التكسي
  Future<void> updateTaxiCaptainStatus({
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

  /// دفق عدد كباتن التكسي النشطين
  Stream<int> streamActiveTaxiCaptainsCount() {
    return _firestore
        .collection('drivers')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data();
        return data['subRole'] != 'delivery' && data['type'] != 'delivery' && data['isDelivery'] != true;
      }).length;
    });
  }
}

/// غلاف بسيط لعكس نتائج المستندات المفلترة دون تغيير واجهة QuerySnapshot
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
