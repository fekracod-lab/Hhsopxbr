import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// مصدر البيانات البعيد لإدارة المطاعم (Restaurant Management Remote Datasource)
class RestaurantManagementRemoteDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  RestaurantManagementRemoteDatasource({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  /// بث المطاعم من المجموعة الأساسية
  Stream<List<Map<String, dynamic>>> getMainRestaurantsStream() {
    return _firestore.collection('restaurants').snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        data['_id'] = doc.id;
        data['_path'] = doc.reference.path;
        return data;
      }).toList();
    });
  }

  /// بث المطاعم من مجموعة العناصر الفرعية
  Stream<List<Map<String, dynamic>>> getItemsGroupRestaurantsStream() {
    return _firestore
        .collectionGroup('items')
        .where('type', whereIn: ['restaurant', 'مطعم', 'كافيه'])
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        data['_id'] = doc.id;
        data['_path'] = doc.reference.path;
        return data;
      }).toList();
    });
  }

  /// حظر أو تفعيل المطعم
  Future<void> toggleSuspension(String docPath, bool newSuspendedStatus) async {
    await _firestore.doc(docPath).update({'isSuspended': newSuspendedStatus});
  }

  /// تعديل بيانات المطعم
  Future<void> updateRestaurant(
    String docPath, {
    required String name,
    required String imageUrl,
    required String status,
  }) async {
    await _firestore.doc(docPath).update({
      'name': name,
      'imageUrl': imageUrl,
      'status': status,
    });
  }

  /// حذف المطعم نهائياً
  Future<void> deleteRestaurant(String docPath) async {
    await _firestore.doc(docPath).delete();
  }

  /// جلب بيانات حساب مالك المطعم
  Future<Map<String, dynamic>?> getOwnerUserData(String ownerId) async {
    final doc = await _firestore.collection('users').doc(ownerId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    data['_id'] = doc.id;
    return data;
  }

  /// تغيير كلمة مرور مالك المطعم عبر Cloud Function
  Future<void> changeOwnerPassword(String ownerId, String newPassword) async {
    final callable = _functions.httpsCallable('adminChangePassword');
    await callable.call({'uid': ownerId, 'newPassword': newPassword});

    await _firestore.collection('users').doc(ownerId).update({
      'passwordChangedAt': FieldValue.serverTimestamp(),
    });
  }
}
