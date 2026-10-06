import 'package:cloud_firestore/cloud_firestore.dart';

/// مصدر البيانات البعيد لعمليات محاسبة التوصيل (Remote Datasource)
class DeliveryAccountingRemoteDatasource {
  final FirebaseFirestore _firestore;

  DeliveryAccountingRemoteDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// جلب طلبات المطاعم لسائق معين
  Future<List<Map<String, dynamic>>> fetchDriverFoodOrders(String driverId, DateTime startLimit) async {
    final snap = await _firestore
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .get();

    final result = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final date = (data['createdAt'] as Timestamp?)?.toDate();
      if (date == null || date.isBefore(startLimit)) continue;

      final status = data['status'] as String?;
      if (status == 'completed' || status == 'delivered' || status == 'مكتمل' || status == 'تم الدفع') {
        data['id'] = doc.id;
        data['type'] = 'food_order';
        result.add(data);
      }
    }
    return result;
  }

  /// جلب طلبات المتاجر لسائق معين
  Future<List<Map<String, dynamic>>> fetchDriverStoreOrders(String driverId, DateTime startLimit) async {
    final snap = await _firestore
        .collectionGroup('madar_orders')
        .orderBy('createdAt', descending: true)
        .limit(1000)
        .get();

    final result = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final dId = data['driverId']?.toString();
      if (dId != driverId) continue;

      final date = (data['createdAt'] as Timestamp?)?.toDate();
      if (date == null || date.isBefore(startLimit)) continue;

      final status = data['status'] as String?;
      if (status == 'completed' || status == 'delivered' || status == 'مكتمل' || status == 'تم الدفع') {
        data['id'] = doc.id;
        data['type'] = 'store_order';
        result.add(data);
      }
    }
    return result;
  }

  /// جلب طلبات التوصيل (Ride Delivery) لسائق معين
  Future<List<Map<String, dynamic>>> fetchDriverRideDeliveries(String driverId, DateTime startLimit) async {
    final snap = await _firestore
        .collection('ride_requests')
        .where('driverId', isEqualTo: driverId)
        .get();

    final result = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final date = (data['createdAt'] as Timestamp?)?.toDate();
      if (date == null || date.isBefore(startLimit)) continue;

      final isDelivery = data['isDelivery'] as bool? ?? false;
      if (!isDelivery) continue;

      final status = data['status'] as String?;
      if (status == 'completed' || status == 'delivered' || status == 'finished' || status == 'paid') {
        data['id'] = doc.id;
        data['type'] = 'ride_delivery';
        result.add(data);
      }
    }
    return result;
  }

  /// جلب قائمة السائقين في محافظة/منطقة معينة
  Future<Map<String, Map<String, dynamic>>> fetchDrivers(String govId, {String? regionId}) async {
    var query = _firestore.collection('drivers').where('governorateId', isEqualTo: govId);
    if (regionId != null) {
      query = query.where('regionId', isEqualTo: regionId);
    }

    final snap = await query.get();
    final driversMap = <String, Map<String, dynamic>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      data['id'] = doc.id;
      driversMap[doc.id] = data;
    }
    return driversMap;
  }

  /// جلب أسماء المطاعم في محافظة/منطقة معينة
  Future<Map<String, String>> fetchRestaurants(String govId, {String? regionId}) async {
    var query = _firestore.collection('restaurants').where('governorateId', isEqualTo: govId);
    if (regionId != null) {
      query = query.where('regionId', isEqualTo: regionId);
    }

    final snap = await query.get();
    final namesMap = <String, String>{};
    for (final doc in snap.docs) {
      namesMap[doc.id] = doc.data()['name'] ?? 'مطعم';
    }
    return namesMap;
  }

  /// جلب أسماء المتاجر في محافظة/منطقة معينة
  Future<Map<String, String>> fetchStores(String govId, {String? regionId}) async {
    final snap = await _firestore.collection('stores').get();
    final namesMap = <String, String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final gId = data['governorateId']?.toString();
      final rId = data['regionId']?.toString();
      if (gId == govId && (regionId == null || rId == regionId)) {
        namesMap[doc.id] = data['name'] ?? 'متجر';
      }
    }
    return namesMap;
  }

  /// جلب سجلات حالات المحاسبة الأسبوعية المسجلة لمحافظة
  Future<Map<String, Map<String, dynamic>>> fetchPaymentsStatus(String govId) async {
    final snap = await _firestore
        .collection('governorates')
        .doc(govId)
        .collection('weekly_accounting')
        .get();

    final statusMap = <String, Map<String, dynamic>>{};
    for (final doc in snap.docs) {
      statusMap[doc.id] = doc.data();
    }
    return statusMap;
  }

  /// جلب طلبات الكباتن بالجملة للمدير (Chunked Queries)
  Future<List<Map<String, dynamic>>> fetchManagerDriverOrders(
    Set<String> driverIds,
    DateTime startLimit,
  ) async {
    if (driverIds.isEmpty) return const [];

    final driverIdsList = driverIds.toList();
    final driverChunks = <List<String>>[];
    for (var i = 0; i < driverIdsList.length; i += 30) {
      driverChunks.add(driverIdsList.sublist(i, i + 30 > driverIdsList.length ? driverIdsList.length : i + 30));
    }

    final orders = <Map<String, dynamic>>[];
    for (final chunk in driverChunks) {
      final foodSnap = await _firestore.collection('orders').where('driverId', whereIn: chunk).get();
      for (final doc in foodSnap.docs) {
        final data = doc.data();
        final date = (data['createdAt'] as Timestamp?)?.toDate();
        if (date == null || date.isBefore(startLimit)) continue;
        final status = data['status'] as String?;
        if (status == 'completed' || status == 'delivered' || status == 'مكتمل' || status == 'تم الدفع') {
          data['id'] = doc.id;
          data['type'] = 'food_order';
          orders.add(data);
        }
      }

      final rideSnap = await _firestore.collection('ride_requests').where('driverId', whereIn: chunk).get();
      for (final doc in rideSnap.docs) {
        final data = doc.data();
        final date = (data['createdAt'] as Timestamp?)?.toDate();
        if (date == null || date.isBefore(startLimit)) continue;
        final isDelivery = data['isDelivery'] as bool? ?? false;
        if (!isDelivery) continue;
        final status = data['status'] as String?;
        if (status == 'completed' || status == 'delivered' || status == 'finished' || status == 'paid') {
          data['id'] = doc.id;
          data['type'] = 'ride_delivery';
          orders.add(data);
        }
      }
    }

    // Madar Store Orders for drivers
    final storeSnap = await _firestore
        .collectionGroup('madar_orders')
        .orderBy('createdAt', descending: true)
        .limit(1000)
        .get();

    for (final doc in storeSnap.docs) {
      final data = doc.data();
      final dId = data['driverId']?.toString();
      if (dId == null || !driverIds.contains(dId)) continue;
      final date = (data['createdAt'] as Timestamp?)?.toDate();
      if (date == null || date.isBefore(startLimit)) continue;
      final status = data['status'] as String?;
      if (status == 'completed' || status == 'delivered' || status == 'مكتمل' || status == 'تم الدفع') {
        data['id'] = doc.id;
        data['type'] = 'store_order';
        orders.add(data);
      }
    }

    return orders;
  }

  /// جلب طلبات المطاعم للمدير بالجملة
  Future<List<Map<String, dynamic>>> fetchManagerRestaurantOrders(
    List<String> restaurantIds,
    DateTime startLimit,
  ) async {
    if (restaurantIds.isEmpty) return const [];

    final restChunks = <List<String>>[];
    for (var i = 0; i < restaurantIds.length; i += 30) {
      restChunks.add(restaurantIds.sublist(i, i + 30 > restaurantIds.length ? restaurantIds.length : i + 30));
    }

    final orders = <Map<String, dynamic>>[];
    for (final chunk in restChunks) {
      final foodSnap = await _firestore.collection('orders').where('restaurantId', whereIn: chunk).get();
      for (final doc in foodSnap.docs) {
        final data = doc.data();
        final date = (data['createdAt'] as Timestamp?)?.toDate();
        if (date == null || date.isBefore(startLimit)) continue;
        final status = data['status'] as String?;
        if (status == 'completed' || status == 'delivered' || status == 'مكتمل' || status == 'تم الدفع') {
          data['id'] = doc.id;
          data['type'] = 'food_order';
          orders.add(data);
        }
      }
    }
    return orders;
  }

  /// جلب طلبات المتاجر للمدير
  Future<List<Map<String, dynamic>>> fetchManagerStoreOrders(
    Set<String> storeIds,
    DateTime startLimit,
  ) async {
    if (storeIds.isEmpty) return const [];

    final storeSnap = await _firestore
        .collectionGroup('madar_orders')
        .orderBy('createdAt', descending: true)
        .limit(1000)
        .get();

    final orders = <Map<String, dynamic>>[];
    for (final doc in storeSnap.docs) {
      final data = doc.data();
      final storeId = doc.reference.parent.parent?.id ?? '';
      if (!storeIds.contains(storeId)) continue;
      final date = (data['createdAt'] as Timestamp?)?.toDate();
      if (date == null || date.isBefore(startLimit)) continue;
      final status = data['status'] as String?;
      if (status == 'completed' || status == 'delivered' || status == 'مكتمل' || status == 'تم الدفع') {
        data['id'] = doc.id;
        data['type'] = 'store_order';
        orders.add(data);
      }
    }
    return orders;
  }

  /// تحديث حالة المحاسبة الأسبوعية لمحافظة
  Future<void> updatePaymentStatus({
    required String govId,
    required String key,
    required String newStatus,
    DateTime? postponedToDate,
  }) async {
    final docRef = _firestore
        .collection('governorates')
        .doc(govId)
        .collection('weekly_accounting')
        .doc(key);

    final data = <String, dynamic>{
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (newStatus == 'postponed' && postponedToDate != null) {
      data['postponedTo'] = Timestamp.fromDate(postponedToDate);
    } else {
      data['postponedTo'] = FieldValue.delete();
    }

    await docRef.set(data, SetOptions(merge: true));
  }
}
