import 'package:cloud_firestore/cloud_firestore.dart';

/// مصدر البيانات البعيد للوحة تحكم الكابتن (Driver Dashboard Remote Datasource)
class DriverDashboardRemoteDatasource {
  final FirebaseFirestore _firestore;

  DriverDashboardRemoteDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// بث بيانات وثيقة الكابتن
  Stream<Map<String, dynamic>?> getDriverDocStream(String driverId) {
    return _firestore.collection('drivers').doc(driverId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      data['uid'] = doc.id;
      return data;
    }).handleError((e) {
      return null;
    });
  }

  /// بث الطلبات المعلقة المتاحة
  Stream<List<Map<String, dynamic>>> getPendingRequestsStream() {
    return _firestore
        .collection('ride_requests')
        .where('status', whereIn: ['searching', 'pending'])
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    }).handleError((e) {
      return <Map<String, dynamic>>[];
    });
  }

  /// بث الرحلة الحالية النشطة للكابتن
  Stream<List<Map<String, dynamic>>> getCurrentRideStream(String driverId) {
    return _firestore
        .collection('ride_requests')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['accepted', 'in_progress', 'arrived'])
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    }).handleError((e) {
      return <Map<String, dynamic>>[];
    });
  }

  /// بث سجل الرحلات السابقة للكابتن
  Stream<List<Map<String, dynamic>>> getRideHistoryStream(String driverId) {
    return _firestore
        .collection('ride_requests')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['completed', 'cancelled'])
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    }).handleError((e) {
      return <Map<String, dynamic>>[];
    });
  }

  /// بث عدد الإشعارات غير المقروءة للكابتن
  Stream<int> getUnreadNotificationsCountStream(String driverId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: driverId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length)
        .handleError((e) {
      return 0;
    });
  }

  /// قبول الطلب بحماية ذرية صارمة لمنع التنازع والقبول المزدوج (Atomic Transaction Acceptance)
  Future<bool> acceptRideAtomic({
    required String requestId,
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    final rideRef = _firestore.collection('ride_requests').doc(requestId);
    final driverRef = _firestore.collection('drivers').doc(driverId);
    final userRef = _firestore.collection('users').doc(driverId);

    try {
      final success = await _firestore.runTransaction<bool>((transaction) async {
        final rideSnap = await transaction.get(rideRef);
        if (!rideSnap.exists) return false;

        final rideData = rideSnap.data() ?? {};
        final currentStatus = (rideData['status'] ?? '').toString().toLowerCase().trim();

        // شرط الحماية الذرية: لا يُقبل الطلب إلا إذا كان searching أو pending حصراً ولم يُقبل من كابتن آخر
        if (currentStatus != 'searching' && currentStatus != 'pending') {
          return false;
        }

        // 1. تحديث وثيقة الرحلة
        transaction.update(rideRef, {
          'driverId': driverId,
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
          'driverName': driverData['name'] ?? driverData['fullName'] ?? 'كابتن مدار',
          'driverPhone': driverData['phone'] ?? '',
          'carModel': driverData['carModel'] ?? '',
          'carColor': driverData['carColor'] ?? '',
          'carNumber': driverData['carNumber'] ?? '',
          'driverPhoto': driverData['photoUrl'] ?? '',
        });

        // 2. تحديث وثيقة الكابتن إلى on_trip
        transaction.set(driverRef, {
          'availability': 'on_trip',
          'available': false,
          'onTripSince': FieldValue.serverTimestamp(),
          'lastStatusUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 3. تحديث وثيقة المستخدم
        transaction.update(userRef, {
          'availability': 'on_trip',
          'available': false,
          'lastStatusUpdate': FieldValue.serverTimestamp(),
        });

        return true;
      });

      return success;
    } catch (_) {
      return false;
    }
  }

  /// رفض الطلب للكابتن (إضافته لقائمة rejectedDrivers)
  Future<void> rejectRideForDriver(String requestId, String driverId) async {
    await _firestore.collection('ride_requests').doc(requestId).update({
      'rejectedDrivers': FieldValue.arrayUnion([driverId]),
      'lastRejectedAt': FieldValue.serverTimestamp(),
    });
  }

  /// تحديث حالة الرحلة أثناء التنفيذ (arrived, in_progress, completed, cancelled)
  Future<void> updateRideStatus({
    required String requestId,
    required String status,
    required String driverId,
    double? finalFare,
  }) async {
    final batch = _firestore.batch();
    final rideRef = _firestore.collection('ride_requests').doc(requestId);
    final driverRef = _firestore.collection('drivers').doc(driverId);
    final userRef = _firestore.collection('users').doc(driverId);

    final updatePayload = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == 'arrived') {
      updatePayload['arrivedAt'] = FieldValue.serverTimestamp();
    } else if (status == 'in_progress') {
      updatePayload['startedAt'] = FieldValue.serverTimestamp();
    } else if (status == 'completed') {
      updatePayload['completedAt'] = FieldValue.serverTimestamp();
      if (finalFare != null) updatePayload['finalPrice'] = finalFare;
    } else if (status == 'cancelled') {
      updatePayload['cancelledAt'] = FieldValue.serverTimestamp();
    }

    batch.update(rideRef, updatePayload);

    // عند انتهاء الرحلة أو إلغائها، إعادة الكابتن للحالة online
    if (status == 'completed' || status == 'cancelled') {
      batch.set(driverRef, {
        'availability': 'online',
        'available': true,
        'onTripSince': FieldValue.delete(),
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.update(userRef, {
        'availability': 'online',
        'available': true,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// تغيير حالة الاتصال (online / offline)
  Future<void> setDriverAvailability(String driverId, String availability) async {
    final newAvailability = availability.toLowerCase().trim();
    final isOnline = newAvailability == 'online';
    final batch = _firestore.batch();

    final driverRef = _firestore.collection('drivers').doc(driverId);
    final userRef = _firestore.collection('users').doc(driverId);

    batch.set(driverRef, {
      'availability': newAvailability,
      'available': isOnline,
      'onTripSince': FieldValue.delete(),
      'lastStatusUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.update(userRef, {
      'availability': newAvailability,
      'available': isOnline,
      'lastStatusUpdate': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// تحديث الموقع الجغرافي للكابتن
  Future<void> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
    required double heading,
  }) async {
    await _firestore.collection('drivers').doc(driverId).set({
      'currentLat': latitude,
      'currentLng': longitude,
      'heading': heading,
      'lastLocationUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
