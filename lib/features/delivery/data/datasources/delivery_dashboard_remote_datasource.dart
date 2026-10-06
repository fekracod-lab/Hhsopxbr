// مصدر البيانات البعيد للوحة تحكم مندوب التوصيل (Delivery Dashboard Remote Datasource)
// Concrete Firestore Data Layer Implementation

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// فئة مصدر البيانات السحابية الحصرية للوحة المندوب
class DeliveryDashboardRemoteDatasource {
  final FirebaseFirestore? _customFirestore;

  DeliveryDashboardRemoteDatasource({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  // ────────────────────────────────────────────
  // 1. تدفقات وثائق السائق وحالة الاتصال
  // ────────────────────────────────────────────

  /// تدفق وثيقة السائق من مجموعة drivers
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDriverDocument(String uid) {
    return _firestore.collection('drivers').doc(uid).snapshots();
  }

  /// تدفق وثيقة المستخدم من مجموعة users
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserDocument(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// تحديث حالة اتصال وتوفر السائق في المجموعتين معاً
  Future<void> setDriverAvailability({
    required String driverId,
    required String status,
  }) async {
    final cleanStatus = status.toLowerCase().trim();
    final bool isOnline = cleanStatus == 'online';

    final Map<String, dynamic> driverData = {
      'availability': cleanStatus,
      'available': isOnline,
      'onTripSince': FieldValue.delete(),
      'lastStatusUpdate': FieldValue.serverTimestamp(),
    };

    final Map<String, dynamic> userData = {
      'availability': cleanStatus,
      'available': isOnline,
      'lastStatusUpdate': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();
    batch.set(_firestore.collection('drivers').doc(driverId), driverData, SetOptions(merge: true));
    batch.set(_firestore.collection('users').doc(driverId), userData, SetOptions(merge: true));
    await batch.commit();
  }

  // ────────────────────────────────────────────
  // 2. تدفقات طلبات مرسال (Mersal Requests)
  // ────────────────────────────────────────────

  /// الطلبات المعلقة المتاحة للتوصيل (مرسال)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchPendingMersalRequests() {
    return _firestore
        .collection('mersal_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// الطلبات النشطة المسندة للسائق (مرسال)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchActiveMersalRequests(String driverId) {
    return _firestore
        .collection('mersal_requests')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['accepted', 'arrived_at_pickup', 'picked_up', 'on_the_way'])
        .snapshots();
  }

  /// سجل الطلبات المكتملة للسائق (مرسال)
  Stream<QuerySnapshot<Map<String, dynamic>>> watchHistoryMersalRequests(String driverId) {
    return _firestore
        .collection('mersal_requests')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'delivered')
        .snapshots();
  }

  /// قبول طلب مرسال عبر معاملة ذرية تضمن عدم التكرار
  Future<bool> acceptMersalRequestAtomic({
    required String requestId,
    required String driverId,
    required Map<String, dynamic> driverData,
    required String agreedPrice,
  }) async {
    final reqRef = _firestore.collection('mersal_requests').doc(requestId);
    final driverRef = _firestore.collection('drivers').doc(driverId);
    final userRef = _firestore.collection('users').doc(driverId);

    try {
      return await _firestore.runTransaction<bool>((tx) async {
        final snap = await tx.get(reqRef);
        if (!snap.exists) return false;

        final data = snap.data() ?? {};
        final status = (data['status'] as String? ?? 'pending').trim().toLowerCase();
        if (status != 'pending') return false;

        // تحديث وثيقة طلب مرسال
        tx.update(reqRef, {
          'status': 'accepted',
          'driverId': driverId,
          'driverName': driverData['name'] ?? driverData['fullName'] ?? 'كابتن',
          'driverPhone': driverData['phone'] ?? driverData['phoneNumber'] ?? '',
          'driverImage': driverData['imageUrl'] ?? driverData['photoUrl'] ?? '',
          'price': agreedPrice,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // تحديث حالة السائق: يبقى متصلاً لكن في رحلة نشطة
        final Map<String, dynamic> driverStatusUpdates = {
          'available': false,
          'onTripSince': FieldValue.serverTimestamp(),
          'lastStatusUpdate': FieldValue.serverTimestamp(),
        };

        tx.set(driverRef, driverStatusUpdates, SetOptions(merge: true));
        tx.set(userRef, driverStatusUpdates, SetOptions(merge: true));

        return true;
      });
    } catch (e) {
      debugPrint('Datasource: Error in acceptMersalRequestAtomic: $e');
      return false;
    }
  }

  // ────────────────────────────────────────────
  // 3. تدفقات طلبات وجبات المطاعم (Food Orders)
  // ────────────────────────────────────────────

  /// الطلبات المتاحة للتوصيل من المطاعم
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAvailableFoodOrders() {
    return _firestore.collection('orders').snapshots();
  }

  /// طلبات المطاعم النشطة المسندة للسائق
  Stream<QuerySnapshot<Map<String, dynamic>>> watchActiveFoodOrders(String driverId) {
    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'delivering')
        .snapshots();
  }

  /// سجل طلبات المطاعم المكتملة للسائق
  Stream<QuerySnapshot<Map<String, dynamic>>> watchHistoryFoodOrders(String driverId) {
    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['completed', 'delivered'])
        .snapshots();
  }

  /// قبول طلب وجبة مطعم عبر معاملة ذرية
  Future<bool> acceptFoodOrderAtomic({
    required String orderId,
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    final docRef = _firestore.collection('orders').doc(orderId);

    try {
      return await _firestore.runTransaction<bool>((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return false;

        final data = snap.data() ?? {};
        final currentStatus = data['status']?.toString().toLowerCase().trim();
        const acceptableStatuses = ['ready', 'pending', 'accepted', 'preparing'];
        if (currentStatus == null || !acceptableStatuses.contains(currentStatus)) {
          return false;
        }

        final existingDriverId = data['driverId']?.toString();
        if (existingDriverId != null && existingDriverId.isNotEmpty && existingDriverId != driverId) {
          return false;
        }

        tx.update(docRef, {
          'status': 'delivering',
          'driverId': driverId,
          'driverName': driverData['name'] ?? driverData['fullName'] ?? 'كابتن',
          'driverPhone': driverData['phone'] ?? driverData['phoneNumber'] ?? '',
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      debugPrint('Datasource: Error in acceptFoodOrderAtomic: $e');
      return false;
    }
  }

  // ────────────────────────────────────────────
  // 4. تدفقات طلبات المتاجر والمسواك (Store Orders)
  // ────────────────────────────────────────────

  /// الطلبات المتاحة للتوصيل من المتاجر
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAvailableStoreOrders() {
    return _firestore.collectionGroup('madar_orders').snapshots();
  }

  /// طلبات المتاجر النشطة المسندة للسائق
  Stream<QuerySnapshot<Map<String, dynamic>>> watchActiveStoreOrders(String driverId) {
    return _firestore
        .collectionGroup('madar_orders')
        .where('driverId', isEqualTo: driverId)
        .snapshots();
  }

  /// سجل طلبات المتاجر المكتملة للسائق
  Stream<QuerySnapshot<Map<String, dynamic>>> watchHistoryStoreOrders(String driverId) {
    return _firestore
        .collectionGroup('madar_orders')
        .where('driverId', isEqualTo: driverId)
        .snapshots();
  }

  /// قبول طلب متجر عبر معاملة ذرية مع مزامنة سجل الزبون
  Future<bool> acceptStoreOrderAtomic({
    required String storeId,
    required String orderId,
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    final storeOrderRef = _firestore
        .collection('stores')
        .doc(storeId)
        .collection('madar_orders')
        .doc(orderId);

    try {
      return await _firestore.runTransaction<bool>((tx) async {
        final snap = await tx.get(storeOrderRef);
        if (!snap.exists) return false;

        final data = snap.data() ?? {};
        final status = data['status']?.toString().toLowerCase().trim();
        if (status != 'pending' && status != 'ready' && status != 'accepted') {
          return false;
        }

        final existingDriverId = data['driverId']?.toString();
        if (existingDriverId != null && existingDriverId.isNotEmpty && existingDriverId != driverId) {
          return false;
        }

        final customerId = data['customerId'] ?? data['userId'] ?? '';

        final driverUpdate = {
          'status': 'delivering',
          'driverId': driverId,
          'driverName': driverData['name'] ?? driverData['fullName'] ?? 'كابتن',
          'driverPhone': driverData['phone'] ?? driverData['phoneNumber'] ?? '',
          'driverCar': '${driverData['carType'] ?? ''} - ${driverData['carNumber'] ?? ''}',
          'driverImage': driverData['imageUrl'] ?? driverData['photoUrl'] ?? '',
          'driverRating': (driverData['rating'] as num?)?.toDouble() ?? 5.0,
          'assignedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        tx.update(storeOrderRef, driverUpdate);

        // مزامنة سجل الزبون إن وُجد
        if (customerId is String && customerId.isNotEmpty) {
          final userHistoryRef = _firestore
              .collection('madar_orders')
              .doc(customerId)
              .collection('store_orders')
              .doc(orderId);
          tx.set(userHistoryRef, driverUpdate, SetOptions(merge: true));
        }

        return true;
      });
    } catch (e) {
      debugPrint('Datasource: Error in acceptStoreOrderAtomic: $e');
      return false;
    }
  }

  // ────────────────────────────────────────────
  // 5. تعديل حالات الطلبات
  // ────────────────────────────────────────────

  /// تحديث حالة طلب التوصيل المباشر
  Future<void> updateOrderStatus({
    required String collection,
    required String docId,
    required Map<String, dynamic> updates,
  }) async {
    await _firestore.collection(collection).doc(docId).set(
      {
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
