import 'package:cloud_firestore/cloud_firestore.dart';

/// مستودع المطاعم المنفصل (Restaurant Domain Repository)
/// يستعلم حصرياً من مجموعة restaurants وقوائمها دون خلط مع المتاجر (Stores).
class RestaurantDomainRepository {
  final FirebaseFirestore _firestore;

  RestaurantDomainRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// دفق جميع المطاعم المعتمدة
  Stream<QuerySnapshot<Map<String, dynamic>>> streamRestaurants({String? governorateId}) {
    Query<Map<String, dynamic>> query = _firestore.collection('restaurants');

    if (governorateId != null && governorateId.isNotEmpty) {
      query = query.where('governorateId', isEqualTo: governorateId);
    }

    return query.snapshots();
  }

  /// جلب مطعم محدد
  Future<DocumentSnapshot<Map<String, dynamic>>?> getRestaurant(String restaurantId) async {
    final doc = await _firestore.collection('restaurants').doc(restaurantId).get();
    if (!doc.exists) return null;
    return doc;
  }

  /// تحديث بيانات المطعم أو حالته
  Future<void> updateRestaurant(String restaurantId, Map<String, dynamic> data) async {
    final payload = <String, dynamic>{
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('restaurants').doc(restaurantId).update(payload);
  }

  /// دفق قائمة طعام المطعم
  Stream<QuerySnapshot<Map<String, dynamic>>> streamRestaurantMenu(String restaurantId) {
    return _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('menu')
        .snapshots();
  }

  /// دفق تصنيفات قائمة المطعم
  Stream<QuerySnapshot<Map<String, dynamic>>> streamRestaurantCategories(String restaurantId) {
    return _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('categories')
        .snapshots();
  }

  /// دفق عدد المطاعم المعتمدة
  Stream<int> streamRestaurantsCount() {
    return _firestore.collection('restaurants').snapshots().map((s) => s.docs.length);
  }
}
