import 'package:cloud_firestore/cloud_firestore.dart';

/// مستودع المتاجر المنفصل (Store Domain Repository)
/// يستعلم حصرياً من مجموعة stores ومنتجاتها دون خلط مع المطاعم.
class StoreDomainRepository {
  final FirebaseFirestore _firestore;

  StoreDomainRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// دفق جميع المتاجر المعتمدة
  Stream<QuerySnapshot<Map<String, dynamic>>> streamStores({String? governorateId}) {
    Query<Map<String, dynamic>> query = _firestore.collection('stores');

    if (governorateId != null && governorateId.isNotEmpty) {
      query = query.where('governorateId', isEqualTo: governorateId);
    }

    return query.snapshots();
  }

  /// جلب متجر محدد
  Future<DocumentSnapshot<Map<String, dynamic>>?> getStore(String storeId) async {
    final doc = await _firestore.collection('stores').doc(storeId).get();
    if (!doc.exists) return null;
    return doc;
  }

  /// تحديث بيانات المتجر أو حالته
  Future<void> updateStore(String storeId, Map<String, dynamic> data) async {
    final payload = <String, dynamic>{
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('stores').doc(storeId).update(payload);
  }

  /// دفق منتجات المتجر
  Stream<QuerySnapshot<Map<String, dynamic>>> streamStoreProducts(String storeId) {
    return _firestore
        .collection('stores')
        .doc(storeId)
        .collection('products')
        .snapshots();
  }

  /// دفق تصنيفات المتجر
  Stream<QuerySnapshot<Map<String, dynamic>>> streamStoreCategories(String storeId) {
    return _firestore
        .collection('stores')
        .doc(storeId)
        .collection('categories')
        .snapshots();
  }

  /// دفق عدد المتاجر المعتمدة
  Stream<int> streamStoresCount() {
    return _firestore.collection('stores').snapshots().map((s) => s.docs.length);
  }
}
