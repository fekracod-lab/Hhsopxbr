import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/delivery_execution_models.dart';
import '../../domain/services/delivery_status_machine.dart';
import '../../domain/services/delivery_execution_calculator.dart';

/// مصدر البيانات البعيد لتنفيذ التوصيل مع العمليات الذرية (Remote Datasource)
class DeliveryExecutionRemoteDatasource {
  final FirebaseFirestore _firestore;

  DeliveryExecutionRemoteDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// الحصول على المسار الصحيح للمستند بناءً على مصدر الطلب
  DocumentReference _getOrderRef(String orderId, OrderDeliverySource source, {String? storeId}) {
    switch (source) {
      case OrderDeliverySource.restaurant:
        return _firestore.collection('orders').doc(orderId);
      case OrderDeliverySource.store:
        if (storeId != null && storeId.isNotEmpty) {
          return _firestore.collection('stores').doc(storeId).collection('madar_orders').doc(orderId);
        }
        return _firestore.collectionGroup('madar_orders').where('orderId', isEqualTo: orderId).firestore.doc(orderId);
      case OrderDeliverySource.mersal:
        return _firestore.collection('mersal_requests').doc(orderId);
    }
  }

  /// تدفق حي لمستند الطلب
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamOrderDoc(
    String orderId,
    OrderDeliverySource source, {
    String? storeId,
  }) {
    if (source == OrderDeliverySource.store && (storeId == null || storeId.isEmpty)) {
      // Find store document dynamically via collectionGroup
      return _firestore
          .collectionGroup('madar_orders')
          .where(FieldPath.documentId, isEqualTo: orderId)
          .snapshots()
          .map((query) => query.docs.isNotEmpty
              ? query.docs.first as DocumentSnapshot<Map<String, dynamic>>
              : throw Exception('Store order not found'));
    }
    return _getOrderRef(orderId, source, storeId: storeId).snapshots() as Stream<DocumentSnapshot<Map<String, dynamic>>>;
  }

  /// تدفق حي لموقع السائق
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDriverDoc(String driverId) {
    return _firestore.collection('drivers').doc(driverId).snapshots();
  }

  /// جلب وثيقة الطلب لمرة واحدة
  Future<Map<String, dynamic>?> fetchOrderData(
    String orderId,
    OrderDeliverySource source, {
    String? storeId,
  }) async {
    if (source == OrderDeliverySource.store && (storeId == null || storeId.isEmpty)) {
      final snap = await _firestore.collectionGroup('madar_orders').where(FieldPath.documentId, isEqualTo: orderId).limit(1).get();
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        data['id'] = snap.docs.first.id;
        final pathSegments = snap.docs.first.reference.path.split('/');
        if (pathSegments.length >= 2 && pathSegments[0] == 'stores') {
          data['storeId'] = pathSegments[1];
        }
        return data;
      }
      return null;
    }

    final docSnap = await _getOrderRef(orderId, source, storeId: storeId).get();
    if (!docSnap.exists) return null;
    final data = docSnap.data() as Map<String, dynamic>?;
    if (data != null) data['id'] = docSnap.id;
    return data;
  }

  /// قبول طلب التوصيل ذرّياً (Atomic Acceptance Transaction)
  Future<bool> acceptDelivery({
    required String orderId,
    required OrderDeliverySource source,
    required DeliveryDriverInfo driverInfo,
    String? storeId,
  }) async {
    try {
      final docRef = _getOrderRef(orderId, source, storeId: storeId);
      final driverRef = _firestore.collection('drivers').doc(driverInfo.id);
      final userRef = _firestore.collection('users').doc(driverInfo.id);

      return await _firestore.runTransaction<bool>((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return false;

        final data = snap.data() as Map<String, dynamic>? ?? {};
        final currentStatus = data['status']?.toString() ?? 'pending';
        final assignedDriverId = data['driverId']?.toString();

        // منع القبول المزدوج إذا كان الطلب مُسنداً مسبقاً أو غير متاح
        const availableStatuses = ['pending', 'ready', 'accepted', 'preparing'];
        if (!availableStatuses.contains(currentStatus) && assignedDriverId != null && assignedDriverId.isNotEmpty) {
          return false;
        }

        final updates = <String, dynamic>{
          'status': 'accepted',
          'driverId': driverInfo.id,
          'driverName': driverInfo.name,
          'driverPhone': driverInfo.phone,
          'driverImage': driverInfo.imageUrl,
          'driverVehicleType': driverInfo.vehicleType,
          'driverVehiclePlate': driverInfo.vehiclePlate,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        tx.update(docRef, updates);

        // تحديث حالة السائق إلى مشغول (on_trip)
        final driverUpdates = {
          'availability': 'on_trip',
          'available': false,
          'onTripSince': FieldValue.serverTimestamp(),
          'lastStatusUpdate': FieldValue.serverTimestamp(),
        };
        tx.set(driverRef, driverUpdates, SetOptions(merge: true));
        tx.set(userRef, driverUpdates, SetOptions(merge: true));

        // إذا كان طلب مطعم، نحدّث نسخة سجل الزبون
        final customerId = data['customerId'] ?? data['userId'];
        if (customerId != null && customerId.toString().isNotEmpty) {
          final userOrderRef = _firestore.collection('madar_orders').doc(customerId.toString()).collection('orders').doc(orderId);
          tx.set(userOrderRef, updates, SetOptions(merge: true));
        }

        return true;
      });
    } catch (e) {
      debugPrint(' [DeliveryExecutionRemoteDatasource] acceptDelivery error: $e');
      return false;
    }
  }

  /// تحديث حالة الطلب ذرّياً مع التسوية المالية عند الإكمال (Atomic Status Transition)
  Future<bool> updateDeliveryStatus({
    required String orderId,
    required OrderDeliverySource source,
    required DeliveryExecutionStatus newStatus,
    required String driverId,
    String cancelReason = '',
    String? storeId,
  }) async {
    try {
      final docRef = _getOrderRef(orderId, source, storeId: storeId);
      final driverRef = _firestore.collection('drivers').doc(driverId);
      final userRef = _firestore.collection('users').doc(driverId);

      return await _firestore.runTransaction<bool>((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return false;

        final data = snap.data() as Map<String, dynamic>? ?? {};
        final currentStatus = DeliveryExecutionStatus.fromString(data['status']?.toString());

        // 1. التحقق من صلاحية السائق (Driver Authorization Guard)
        final assignedDriverId = data['driverId']?.toString();
        if (assignedDriverId != null && assignedDriverId != driverId && driverId.isNotEmpty) {
          debugPrint(' Unauthorized driver attempt on order $orderId');
          return false;
        }

        // 2. التحقق من صحة انتقال الحالة (State Machine Guard)
        if (!DeliveryStatusMachine.canTransition(currentStatus, newStatus)) {
          debugPrint(' Illegal transition: $currentStatus -> $newStatus on order $orderId');
          return false;
        }

        final updates = <String, dynamic>{
          'status': newStatus.value,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (newStatus == DeliveryExecutionStatus.headingToPickup) {
          updates['headingToPickupAt'] = FieldValue.serverTimestamp();
        } else if (newStatus == DeliveryExecutionStatus.arrivedAtPickup) {
          updates['arrivedAtPickupAt'] = FieldValue.serverTimestamp();
        } else if (newStatus == DeliveryExecutionStatus.pickedUp) {
          updates['pickedUpAt'] = FieldValue.serverTimestamp();
        } else if (newStatus == DeliveryExecutionStatus.headingToCustomer) {
          updates['headingToCustomerAt'] = FieldValue.serverTimestamp();
        } else if (newStatus == DeliveryExecutionStatus.arrivedAtCustomer) {
          updates['arrivedAtCustomerAt'] = FieldValue.serverTimestamp();
        } else if (newStatus == DeliveryExecutionStatus.delivered) {
          updates['deliveredAt'] = FieldValue.serverTimestamp();
          updates['completedAt'] = FieldValue.serverTimestamp();

          // 3. التسوية المالية الآمنة داخل الـ Transaction (Financial Settlement)
          final double deliveryFee = (data['deliveryFee'] as num? ?? 1000.0).toDouble();
          final double total = (data['total'] as num? ?? data['grandTotal'] as num? ?? 0.0).toDouble();
          final String paymentMethod = (data['paymentMethod'] ?? data['paymentStatus'] ?? 'cash_on_delivery').toString();
          final bool isPaid = data['isPaid'] == true;

          final metrics = DeliveryExecutionCalculator.calculateMetrics(
            deliveryFee: deliveryFee,
            orderTotal: total,
            paymentMethod: paymentMethod,
            isPaid: isPaid,
          );

          updates['captainEarnings'] = metrics.captainEarnings;
          updates['platformCommission'] = metrics.platformCommission;
          updates['cashCollected'] = metrics.cashToCollect;
          updates['merchantSettlement'] = metrics.merchantSettlement;
          updates['customerPointsEarned'] = metrics.customerPointsEarned;

          // إيداع الأرباح في رصيد الكابتن
          tx.update(driverRef, {
            'balance': FieldValue.increment(metrics.captainEarnings),
            'totalEarnings': FieldValue.increment(metrics.captainEarnings),
            'completedDeliveriesCount': FieldValue.increment(1),
          });
          tx.update(userRef, {
            'balance': FieldValue.increment(metrics.captainEarnings),
            'totalEarnings': FieldValue.increment(metrics.captainEarnings),
          });

          // إعادة حالة السائق إلى متاح (online)
          final resetDriver = {
            'availability': 'online',
            'available': true,
            'onTripSince': FieldValue.delete(),
            'lastStatusUpdate': FieldValue.serverTimestamp(),
          };
          tx.set(driverRef, resetDriver, SetOptions(merge: true));
          tx.set(userRef, resetDriver, SetOptions(merge: true));
        } else if (newStatus == DeliveryExecutionStatus.cancelled) {
          updates['cancelledAt'] = FieldValue.serverTimestamp();
          updates['cancelReason'] = cancelReason;

          // إعادة السائق إلى متاح عند الإلغاء
          final resetDriver = {
            'availability': 'online',
            'available': true,
            'onTripSince': FieldValue.delete(),
            'lastStatusUpdate': FieldValue.serverTimestamp(),
          };
          tx.set(driverRef, resetDriver, SetOptions(merge: true));
          tx.set(userRef, resetDriver, SetOptions(merge: true));
        }

        tx.update(docRef, updates);

        // مزامنة نسخة سجل الزبون
        final customerId = data['customerId'] ?? data['userId'];
        if (customerId != null && customerId.toString().isNotEmpty) {
          final userOrderRef = _firestore.collection('madar_orders').doc(customerId.toString()).collection('orders').doc(orderId);
          tx.set(userOrderRef, updates, SetOptions(merge: true));
        }

        // إذا كان مطعماً، نحدّث مرآة المطعم أيضاً
        final restaurantId = data['restaurantId'] ?? data['restaurantDocId'];
        if (source == OrderDeliverySource.restaurant && restaurantId != null) {
          final restOrderRef = _firestore.collection('restaurants').doc(restaurantId.toString()).collection('orders').doc(orderId);
          tx.set(restOrderRef, updates, SetOptions(merge: true));
        }

        return true;
      });
    } catch (e) {
      debugPrint(' [DeliveryExecutionRemoteDatasource] updateDeliveryStatus error: $e');
      return false;
    }
  }

  /// مزامنة موقع السائق مع كولكشن السائقين ومستند الطلب
  Future<void> syncDriverLocation({
    required String driverId,
    required DeliveryLocationEntity location,
    String? activeOrderId,
    OrderDeliverySource? activeSource,
    String? storeId,
  }) async {
    try {
      final driverRef = _firestore.collection('drivers').doc(driverId);
      final driverData = {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'currentLat': location.latitude,
        'currentLng': location.longitude,
        'heading': location.heading,
        'speed': location.speed,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      };

      await driverRef.set(driverData, SetOptions(merge: true));

      // إذا كان هناك طلب نشط، حدّث موقع السائق فيه أيضاً لتسهيل تتبع الزبون
      if (activeOrderId != null && activeOrderId.isNotEmpty && activeSource != null) {
        final orderRef = _getOrderRef(activeOrderId, activeSource, storeId: storeId);
        await orderRef.update({
          'driverLatitude': location.latitude,
          'driverLongitude': location.longitude,
          'driverHeading': location.heading,
          'driverLastLocationUpdate': FieldValue.serverTimestamp(),
        }).catchError((_) {});
      }
    } catch (e) {
      debugPrint(' [DeliveryExecutionRemoteDatasource] syncDriverLocation error: $e');
    }
  }
}
