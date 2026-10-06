import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_service.dart';
import 'onesignal_service.dart'; // Keep for syncUserRole
import 'package:flutter/foundation.dart';
import 'dart:async';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Location Logic ---
  Future<int> getCancellationCount(String driverId) async {
    final query = await _firestore.collection('taxi_requests')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'cancelled')
        .get();
    return query.docs.length;
  }

  StreamSubscription<Position>? _positionStream;
  DateTime? _lastLocationWriteAt;

  // بدء تتبع الموقع
  void startLocationUpdates(String driverId) {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 5, // Increased precision
      ),
    ).listen(
      (position) async {
        try {
          final now = DateTime.now();
          final driverDoc = await _firestore.collection('drivers').doc(driverId).get();
          final data = driverDoc.data() ?? {};
          final bool isOnTrip = data['availability'] == 'on_trip';

          // Throttle based on status: 3s if on trip, 10s otherwise
          final int threshold = isOnTrip ? 3 : 10;

          if (_lastLocationWriteAt != null &&
              now.difference(_lastLocationWriteAt!).inSeconds < threshold) {
            return;
          }
          _lastLocationWriteAt = now;

          await _firestore.collection('drivers').doc(driverId).set({
            'currentLat': position.latitude,
            'currentLng': position.longitude,
            'heading': position.heading,
            'lastLocationUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Location update failed: $e');
        }
      },
      onError: (e) {
        debugPrint('Location stream error: $e');
      },
    );
  }

  // إيقاف تتبع الموقع
  void stopLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = null;
    _lastLocationWriteAt = null;
  }

  // --- Availability Logic (New String-based states) ---
  // states: 'online', 'offline', 'on_trip'

  Future<String> toggleAvailability(String driverId, String currentAvailability) async {
    final String current = currentAvailability.toLowerCase().trim();
    // Toggle logic: If currently online -> go offline. Otherwise (offline/on_trip/null) -> go online.
    final target = (current == 'online' || current == 'on_trip') ? 'offline' : 'online';
    await setAvailability(driverId, target);
    return target;
  }

  Future<void> setAvailability(String driverId, String status) async {
    final newAvailability = status.toLowerCase().trim();

    await _firestore.collection('drivers').doc(driverId).set({
      'availability': newAvailability,
      'available': (newAvailability == 'online'),
      'onTripSince': FieldValue.delete(), // Always clear onTripSince when manually setting
      'lastStatusUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final userRef = _firestore.collection('users').doc(driverId);
    await userRef.update({
      'availability': newAvailability,
      'available': (newAvailability == 'online'),
      'lastStatusUpdate': FieldValue.serverTimestamp(),
    });

    if (newAvailability == 'online') {
      startLocationUpdates(driverId);
      await OneSignalService.syncUserRole(driverId);
    } else {
      stopLocationUpdates();
    }
  }

  Future<void> ensureDriverDocExists(String driverId) async {
    try {
      final driverRef = _firestore.collection('drivers').doc(driverId);
      
      final userDoc = await _firestore.collection('users').doc(driverId).get();
      final userData = userDoc.data() ?? {};
      
      final reqDoc = await _firestore.collection('driver_requests').doc(driverId).get();
      final reqData = reqDoc.data() ?? {};

      final nameVal = userData['fullName'] ?? userData['name'] ?? reqData['fullName'] ?? reqData['name'] ?? 'كابتن';
      final phoneVal = userData['phone'] ?? reqData['phone'] ?? '';
      final carNumVal = userData['carNumber'] ?? reqData['carNumber'] ?? userData['car_number'] ?? reqData['car_number'] ?? '';
      final carTypeVal = userData['carType'] ?? reqData['carType'] ?? userData['car_type'] ?? reqData['car_type'] ?? '';
      final carModelVal = userData['carModel'] ?? reqData['carModel'] ?? userData['car_model'] ?? reqData['car_model'] ?? '';
      final carYearVal = userData['carYear'] ?? reqData['carYear'] ?? userData['car_year'] ?? reqData['car_year'] ?? '';
      final carColorVal = userData['carColor'] ?? reqData['carColor'] ?? userData['car_color'] ?? reqData['car_color'] ?? '';
      final photoVal = userData['photoUrl'] ?? reqData['photoUrl'] ?? userData['profileImage'] ?? reqData['profileImage'] ?? userData['carImage'] ?? reqData['carImage'] ?? '';

      final mergedData = {
        'uid': driverId,
        'name': nameVal,
        'fullName': nameVal,
        'phone': phoneVal,
        'email': userData['email'] ?? reqData['email'] ?? '',
        'carNumber': carNumVal,
        'carType': carTypeVal,
        'carModel': carModelVal,
        'carYear': carYearVal,
        'carColor': carColorVal,
        'photoUrl': photoVal,
        'profileImage': photoVal,
        'carImage': photoVal,
        'role': userData['role'] ?? reqData['role'] ?? 'captain',
        'status': userData['status'] ?? reqData['status'] ?? 'active',
        'isApproved': userData['isApproved'] ?? reqData['isApproved'] ?? true,
        'available': true,
        'availability': 'online',
        'rating': 5.0,
        'totalTrips': 0,
      };

      await driverRef.set(mergedData, SetOptions(merge: true));
    } catch (e) {
      debugPrint(' ensureDriverDocExists error: $e');
    }
  }

  // --- Streams ---
  // الاستماع لبيانات السائق
  Stream<DocumentSnapshot> getDriverStream(String driverId) {
    ensureDriverDocExists(driverId);
    return _firestore.collection('drivers').doc(driverId).snapshots();
  }

  // الاستماع للطلبات الجديدة المتاحة
  Stream<QuerySnapshot> getPendingRequestsStream() {
    return _firestore
        .collection('ride_requests')
        .where('status', whereIn: ['searching', 'pending'])
        .snapshots();
  }

  // الاستماع للرحلة الحالية للسائق
  Stream<QuerySnapshot> getCurrentRideStream(String driverId) {
    return _firestore
        .collection('ride_requests')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['accepted', 'in_progress', 'arrived'])
        .snapshots();
  }

  // رفض الطلب من قبل السائق (Uber / Careem Dispatch Strategy)
  Future<void> rejectRideForDriver(String requestId, String driverId, {String? reason}) async {
    try {
      await _firestore.collection('ride_requests').doc(requestId).update({
        'rejectedDrivers': FieldValue.arrayUnion([driverId]),
        'lastRejectedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(' [DriverService] Driver $driverId rejected ride: $requestId');
    } catch (e) {
      debugPrint(' Error in rejectRideForDriver: $e');
    }
  }

  // تنظيف الرحلات المعلقة القديمة (أكثر من 60 دقيقة) حتى لا تحجب السائق
  Future<void> cleanupStaleDriverRides(String driverId) async {
    try {
      final oneHourAgo = DateTime.now().subtract(const Duration(minutes: 60));
      final snap = await _firestore
          .collection('ride_requests')
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: ['accepted', 'arrived', 'in_progress'])
          .get();

      for (var doc in snap.docs) {
        final data = doc.data();
        final rawAccepted = data['acceptedAt'] ?? data['updatedAt'] ?? data['createdAt'];
        DateTime? tripTime;
        if (rawAccepted is Timestamp) tripTime = rawAccepted.toDate();
        if (rawAccepted is DateTime) tripTime = rawAccepted;
        if (rawAccepted is String) tripTime = DateTime.tryParse(rawAccepted);

        if (tripTime != null && tripTime.isBefore(oneHourAgo)) {
          debugPrint(' [DriverService] Auto-cancelling stale zombie ride: ${doc.id}');
          await doc.reference.update({
            'status': 'cancelled',
            'cancelReason': 'إلغاء تلقائي بسبب مرور أكثر من 60 دقيقة (Stale Auto-Cleanup)',
            'cancelledAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint(' Error in cleanupStaleDriverRides: $e');
    }
  }

  // الاستماع لسجل الرحلات المكتملة
  Stream<QuerySnapshot> getRideHistoryStream(String driverId) {
    return _firestore
        .collection('ride_requests')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'completed')
        .limit(20)
        .snapshots();
  }

  // قبول الرحلة (Atomic Transaction with Commission & Debt Check)
  Future<bool> acceptRide({
    required String requestId,
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    final reqRef = _firestore.collection('ride_requests').doc(requestId);
    final driverRef = _firestore.collection('drivers').doc(driverId);

    final result = await _firestore.runTransaction<bool>((tx) async {
      // 1. ALL READS FIRST
      final snap = await tx.get(reqRef);
      if (!snap.exists) return false;

      final status = (snap.data() ?? {})['status'] as String? ?? 'pending';
      if (status != 'pending' && status != 'searching') return false;

      final dSnap = await tx.get(driverRef);
      final dData = dSnap.exists ? dSnap.data() ?? {} : driverData;

      // فحص عمولة التطبيق وحد المديونية (5,000 د.ع أو المخصص)
      final double appDebt = (dData['appDebt'] as num?)?.toDouble() ?? 0.0;
      final double maxLimit = (dData['customCommissionLimit'] as num?)?.toDouble() ?? 5000.0;
      final bool commissionException = dData['commissionException'] == true;
      final bool isBlockedByAdmin = dData['isBlocked'] == true;

      if (isBlockedByAdmin) {
        throw Exception('ACCOUNT_BLOCKED');
      }

      if (appDebt >= maxLimit && !commissionException) {
        throw Exception('COMMISSION_LIMIT_EXCEEDED');
      }

      // 2. ALL WRITES
      // تحديث الطلب
      tx.update(reqRef, {
        'status': 'accepted',
        'driverId': driverId,
        'driverName': driverData['name'],
        'driverPhone': driverData['phone'],
        'driverCar': '${driverData['carType']} - ${driverData['carModel'] ?? ''}',
        'driverCarColor': driverData['carColor'] ?? 'غير محدد',
        'driverCarNumber': driverData['carNumber'] ?? 'غير محدد',
        'driverImage': driverData['photoUrl'] ?? driverData['imageUrl'],
        'driverRating': driverData['rating'],
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // تحديث السائق: يبقى متصل ولكنه غير متاح لاستلام طلبات جديدة حالياً
      final Map<String, dynamic> driverStatusUpdates = {
        'available': false, // Legacy field
        'onTripSince': FieldValue.serverTimestamp(),
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      };

      tx.update(driverRef, driverStatusUpdates);

      // مزامنة حالة المستخدم أيضاً
      final userRef = _firestore.collection('users').doc(driverId);
      tx.update(userRef, driverStatusUpdates);

      return true;
    });

    // إشعارات العميل
    if (result == true) {
      try {
        await NotificationService.emitEvent(
          type: 'ride_status_updated',
          payload: {
            'ride_id': requestId,
            'status': 'accepted',
            'title': 'تم قبول المشوار!',
            'body': 'كابتن ${driverData['name'] ?? 'مدار'} قبل رحلتك وهو بالطريق إليك',
            'driverId': driverId,
            'driverName': driverData['name'],
            'driverPhone': driverData['phone'],
          },
        );
      } catch (e) {
        debugPrint('Failed to notify customer after acceptRide: $e');
      }
    }

    return result;
  }

  // تحديث حالة الرحلة (Atomic Transaction with Terminal States & Financial Accounting)
  Future<void> updateRideStatus(String requestId, String newStatus, {String? reason}) async {
    final reqRef = _firestore.collection('ride_requests').doc(requestId);

    final Map<String, dynamic> updates = {
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (newStatus == 'rejected') {
      updates['rejectedAt'] = FieldValue.serverTimestamp();
      if (reason != null && reason.trim().isNotEmpty) {
        updates['rejectionReason'] = reason.trim();
      }
    }

    if (newStatus == 'completed') {
      updates['completedAt'] = FieldValue.serverTimestamp();
    }

    // حالات انتهاء الرحلة التي يجب أن تعيد السائق online
    const terminalStatuses = {'completed', 'cancelled', 'driver_cancelled', 'rejected'};

    // Fetch dynamic commission percent from config
    double commissionPercent = 10.0;
    if (newStatus == 'completed') {
      try {
        final configDoc = await _firestore.collection('settings').doc('taxi_config').get();
        if (configDoc.exists) {
          commissionPercent = (configDoc.data()?['platformCommissionPercent'] as num?)?.toDouble() ?? 10.0;
        }
      } catch (_) {}
    }

    await _firestore.runTransaction((tx) async {
      // 1. ALL READS FIRST
      final snap = await tx.get(reqRef);
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      final oldStatus = data['status'] as String? ?? '';
      
      // Idempotency: skip if status is already the same
      if (oldStatus == newStatus) {
        debugPrint('ℹ Skip redundant status update: $requestId already is $newStatus');
        return;
      }

      final driverId = data['driverId']?.toString();
      final DocumentReference? driverRef = driverId != null ? _firestore.collection('drivers').doc(driverId) : null;
      
      DocumentSnapshot? driverSnap;
      if (driverRef != null && terminalStatuses.contains(newStatus)) {
        driverSnap = await tx.get(driverRef);
      }

      // 2. PREPARE ALL MUTATIONS
      final Map<String, dynamic> driverUpdates = {};

      // Calculation for completed trips
      if (newStatus == 'completed') {
        String pStr = data['price']?.toString() ?? '0';
        pStr = pStr.replaceAll(RegExp(r'[^0-9.]'), '');
        final double rawPrice = double.tryParse(pStr) ?? 0.0;
        final double commission = (rawPrice * (commissionPercent / 100.0)).roundToDouble();
        final double netProfit = rawPrice - commission;
        final String paymentMethod = (data['paymentMethod'] ?? 'cash').toString().toLowerCase();
        final bool isWalletPayment = paymentMethod.contains('wallet') || paymentMethod.contains('محفظ') || paymentMethod.contains('electronic');

        updates['commission'] = commission;
        updates['commissionPercent'] = commissionPercent;
        updates['netProfit'] = netProfit;
        updates['isWalletPayment'] = isWalletPayment;
        
        // المحاسبة المالية الدقيقة وتفادي ازدواجية أرباح الكاش:
        driverUpdates['totalCommission'] = FieldValue.increment(commission);
        driverUpdates['totalEarnings'] = FieldValue.increment(rawPrice);
        driverUpdates['totalTrips'] = FieldValue.increment(1);

        if (isWalletPayment) {
          // دفع إلكتروني من محفظة الراكب: المنصة استلمت المبلغ كاملاً مسبقاً، لذلك نزيد رصيد الكابتن القابل للسحب
          driverUpdates['balance'] = FieldValue.increment(netProfit);
          driverUpdates['walletEarnings'] = FieldValue.increment(netProfit);
        } else {
          // دفع نقدي (Cash): الكابتن استلم كامل المبلغ كاش بيده، لذلك نُسجل عليه عمولة المنصة كدين
          // ولا نزيد حقل balance حتى لا يُصرف له المبلغ مرتين عند طلب السحب!
          driverUpdates['appDebt'] = FieldValue.increment(commission);
          driverUpdates['cashEarnings'] = FieldValue.increment(rawPrice);
        }
      }

      if (driverId != null && terminalStatuses.contains(newStatus)) {
        final driverData = (driverSnap != null && driverSnap.exists) 
            ? driverSnap.data() as Map<String, dynamic>? ?? {} 
            : {};
        final bool isOnlineMode = (driverData['availability'] ?? 'offline') == 'online';

        driverUpdates['available'] = isOnlineMode;
        driverUpdates['onTripSince'] = FieldValue.delete();
        driverUpdates['lastStatusUpdate'] = FieldValue.serverTimestamp();
      }

      // 3. ALL WRITES AFTER ALL READS (NO READS BELOW THIS LINE)
      tx.update(reqRef, updates);

      if (driverRef != null && driverUpdates.isNotEmpty) {
        tx.update(driverRef, driverUpdates);

        final userRef = _firestore.collection('users').doc(driverId);
        final userUpdates = Map<String, dynamic>.from(driverUpdates)
          ..remove('balance')
          ..remove('totalEarnings')
          ..remove('appDebt')
          ..remove('totalCommission');
        if (userUpdates.isNotEmpty) {
          tx.update(userRef, userUpdates);
        }
      }
    });

    // إرسال إشعار للعميل بحسب الحالة الجديدة
    try {
      String notifTitle = 'تحديث حالة المشوار';
      String notifBody = 'تم تحديث حالة الرحلة';
      if (newStatus == 'arrived') {
        notifTitle = 'الكابتن وصل!';
        notifBody = 'الكابتن بانتظارك عند نقطة الانطلاق، يرجى الخروج لبدء المشوار';
      } else if (newStatus == 'in_progress') {
        notifTitle = 'بدأت الرحلة';
        notifBody = 'نتمنى لك مشواراً آمناً وممتعاً مع تاكسي مدار';
      } else if (newStatus == 'completed') {
        notifTitle = 'وصلنا بالسلامة';
        notifBody = 'شكراً لاختيارك تاكسي مدار. نتمنى لك يوماً سعيداً!';
      } else if (newStatus == 'rejected' || newStatus == 'cancelled' || newStatus == 'driver_cancelled') {
        notifTitle = 'تم إلغاء المشوار';
        notifBody = reason ?? 'تم إلغاء طلب التاكسي';
      }

      await NotificationService.emitEvent(
        type: 'ride_status_updated',
        payload: {
          'ride_id': requestId,
          'status': newStatus,
          'title': notifTitle,
          'body': notifBody,
        },
      );
    } catch (e) {
      debugPrint('Failed to notify customer on status update: $e');
    }
  }

  // --- Statistics Logic (New & Real) ---

  // حساب إحصائيات اليوم (رحلات مكتملة فقط بناءً على completedAt)
  Future<Map<String, dynamic>> getDailyStats(String driverId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      final query =
          await _firestore
              .collection('ride_requests')
              .where('driverId', isEqualTo: driverId)
              .where('status', isEqualTo: 'completed')
              .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .get();

      double dailyEarnings = 0.0;
      final completedTrips = query.docs.length;

      for (var doc in query.docs) {
        final data = doc.data();
        String p = data['price']?.toString() ?? '0';
        p = p.replaceAll(RegExp(r'[^0-9.]'), '');
        dailyEarnings += (double.tryParse(p) ?? 0);
      }

      return {'earnings': dailyEarnings, 'trips': completedTrips};
    } catch (e) {
      debugPrint('Stats Error: $e');
      return {'earnings': 0.0, 'trips': 0};
    }
  }

  // حساب إحصائيات لفترة محددة (أسبوع، شهر)
  Future<Map<String, dynamic>> getPeriodicStats(String driverId, int days) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));

    try {
      final query =
          await _firestore
              .collection('ride_requests')
              .where('driverId', isEqualTo: driverId)
              .where('status', isEqualTo: 'completed')
              .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
              .get();

      double earnings = 0.0;
      final trips = query.docs.length;

      for (var doc in query.docs) {
        final data = doc.data();
        String p = data['price']?.toString() ?? '0';
        p = p.replaceAll(RegExp(r'[^0-9.]'), '');
        earnings += (double.tryParse(p) ?? 0);
      }

      return {'earnings': earnings, 'trips': trips};
    } catch (e) {
      debugPrint('Periodic Stats Error: $e');
      return {'earnings': 0.0, 'trips': 0};
    }
  }

  // إرسال تنبيه طوارئ SOS
  Future<void> sendSOSAlert(String driverId, Map<String, dynamic> driverData) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      await _firestore.collection('emergency_alerts').add({
        'driverId': driverId,
        'driverName': driverData['name'],
        'driverPhone': driverData['phone'],
        'location': GeoPoint(pos.latitude, pos.longitude),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'taxi_driver_sos',
      });
    }
  }

  // دالة مساعدة لإرسال الرسائل
  Future<void> sendChatMessage(String rideId, String text, String uid, String name) async {
    await _firestore.collection('ride_requests').doc(rideId).collection('messages').add({
      'text': text,
      'senderId': uid,
      'senderName': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // جلب إجمالي الرحلات المكتملة (All-time - Combined for Taxi & Delivery)
  Future<int> getTotalTrips(String driverId) async {
    try {
      final collections = [
        'ride_requests',
        'mersal_requests',
        'parcel_delivery_requests',
        'delegate_requests',
        'orders',
        'madar_orders'
      ];
      int total = 0;
      for (var coll in collections) {
        final query = coll == 'madar_orders'
            ? await _firestore
                .collectionGroup(coll)
                .where('driverId', isEqualTo: driverId)
                .get()
            : await _firestore
                .collection(coll)
                .where('driverId', isEqualTo: driverId)
                .get();
        for (var doc in query.docs) {
          final status = doc.data()['status'] as String?;
          if (status == 'completed' || status == 'delivered') {
            total++;
          }
        }
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  // جلب أرباح آخر 7 أيام (Combined for Taxi & Delivery)
  Future<List<double>> getWeeklyChartData(String driverId) async {
    List<double> dailyEarnings = List.filled(7, 0.0);
    final now = DateTime.now();
    final collections = [
      'ride_requests',
      'mersal_requests',
      'parcel_delivery_requests',
      'delegate_requests',
      'orders',
      'madar_orders'
    ];

    try {
      for (var coll in collections) {
        final query = coll == 'madar_orders'
            ? await _firestore
                .collectionGroup(coll)
                .where('driverId', isEqualTo: driverId)
                .get()
            : await _firestore
                .collection(coll)
                .where('driverId', isEqualTo: driverId)
                .get();

        for (var doc in query.docs) {
          final data = doc.data();
          final status = data['status'] as String?;
          if (status == 'completed' || status == 'delivered') {
            final dateField = (coll == 'orders' || coll == 'madar_orders') ? 'createdAt' : 'completedAt';
            final timestamp = data[dateField] as Timestamp?;
            if (timestamp != null) {
              final date = timestamp.toDate();
              final dayDifference = DateTime(now.year, now.month, now.day).difference(DateTime(date.year, date.month, date.day)).inDays;
              if (dayDifference >= 0 && dayDifference < 7) {
                final dayIndex = 6 - dayDifference;
                String p = '0';
                if (coll == 'orders' || coll == 'madar_orders') {
                  p = (data['totalPrice'] ?? data['deliveryFee'] ?? '0').toString();
                } else {
                  p = data['price']?.toString() ?? '0';
                }
                p = p.replaceAll(RegExp(r'[^0-9.]'), '');
                dailyEarnings[dayIndex] += (double.tryParse(p) ?? 0.0);
              }
            }
          }
        }
      }
      return dailyEarnings;
    } catch (e) {
      debugPrint('Combined Weekly Stats Error: $e');
      return dailyEarnings;
    }
  }

  // دالة لإصلاح الحالة المعلقة إذا لم توجد رحلة
  Future<void> fixStuckStatus(String driverId) async {
    try {
      final doc = await _firestore.collection('drivers').doc(driverId).get();
      if (!doc.exists) return;

      final data = doc.data() ?? {};
      final String currentStatus = data['availability'] ?? '';

      // مصلح الحالة الآن يركز على مزامنة available مع availability
      final bool hasActive = await _hasActiveTasks(driverId);

      if (!hasActive) {
        final bool shouldBeAvailable = currentStatus == 'online';
        final Map<String, dynamic> syncData = {
          'available': shouldBeAvailable,
          'onTripSince': FieldValue.delete(),
          'lastStatusUpdate': FieldValue.serverTimestamp(),
        };
        await _firestore.collection('drivers').doc(driverId).update(syncData);
        await _firestore.collection('users').doc(driverId).update(syncData);
        debugPrint(" Sync state fixed for driver: $driverId");
      }
    } catch (e) {
      debugPrint(" Error fixing stuck status: $e");
    }
  }

  // تصفير الحالة يدوياً في حال حدوث خطأ برمجي
  Future<void> forceResetStatus(String driverId) async {
    final Map<String, dynamic> reset = {
      'availability': 'online',
      'available': true,
      'onTripSince': FieldValue.delete(),
      'lastStatusUpdate': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('drivers').doc(driverId).update(reset);
    await _firestore.collection('users').doc(driverId).update(reset);
  }

  // التحقق الشامل من وجود أي مهام نشطة عبر جميع الأقسام
  Future<bool> _hasActiveTasks(String driverId) async {
    try {
      // 1. Taxi
      final taxiActive =
          await _firestore
              .collection('ride_requests')
              .where('driverId', isEqualTo: driverId)
              .where('status', whereIn: ['accepted', 'arrived', 'in_progress'])
              .limit(1)
              .get();

      if (taxiActive.docs.isNotEmpty) return true;
    } catch (e) {
      debugPrint("Error checking active taxi: $e");
    }

    try {
      // 2. Mersal
      final mersalActive =
          await _firestore
              .collection('mersal_requests')
              .where('driverId', isEqualTo: driverId)
              .where(
                'status',
                whereIn: ['accepted', 'arrived_at_pickup', 'on_the_way', 'picked_up'],
              )
              .limit(1)
              .get();

      if (mersalActive.docs.isNotEmpty) return true;
    } catch (e) {
      debugPrint("Error checking active Mersal: $e");
    }

    try {
      // 3. Parcel
      final parcelActive =
          await _firestore
              .collection('parcel_delivery_requests')
              .where('driverId', isEqualTo: driverId)
              .where(
                'status',
                whereIn: ['accepted', 'arrived_at_pickup', 'on_the_way', 'picked_up'],
              )
              .limit(1)
              .get();

      if (parcelActive.docs.isNotEmpty) return true;
    } catch (e) {
      debugPrint("Error checking active Parcel: $e");
    }

    try {
      // 4. Delegate
      final delegateActive =
          await _firestore
              .collection('delegate_requests')
              .where('driverId', isEqualTo: driverId)
              .where(
                'status',
                whereIn: ['accepted', 'arrived_at_pickup', 'on_the_way', 'picked_up'],
              )
              .limit(1)
              .get();

      if (delegateActive.docs.isNotEmpty) return true;
    } catch (e) {
      debugPrint("Error checking active Delegate: $e");
    }

    try {
      // 5. Food Orders
      final foodActive =
          await _firestore
              .collection('orders')
              .where('driverId', isEqualTo: driverId)
              .where('status', isEqualTo: 'delivering')
              .limit(1)
              .get();

      return foodActive.docs.isNotEmpty;
    } catch (e) {
      debugPrint("Error checking active Food: $e");
      return true; // Safety
    }
  }

  // تحديث بيانات السائق (الملف الشخصي والمركبة)
  Future<void> updateDriverData(String driverId, Map<String, dynamic> data) async {
    await _firestore.collection('drivers').doc(driverId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getDriverData(String driverId) async {
    try {
      final doc = await _firestore.collection('drivers').doc(driverId).get();
      return doc.data();
    } catch (e) {
      debugPrint('Error getting driver data: $e');
      return null;
    }
  }

  Future<void> checkAndSetAvailable(String driverId) async {
    try {
      final hasActive = await _hasActiveTasks(driverId);
      if (!hasActive) {
        // Double check they are "online" before setting available=true
        final doc = await _firestore.collection('drivers').doc(driverId).get();
        final status = doc.data()?['availability'] ?? 'offline';
        if (status == 'online') {
          await _firestore.collection('drivers').doc(driverId).update({'available': true});
        }
      }
    } catch (e) {
      debugPrint('Error checking availability: $e');
    }
  }

  // بلاغ عن عطل في المركبة
  Future<void> reportBreakdown(String driverId, String description) async {
    await _firestore.collection('breakdown_reports').add({
      'driverId': driverId,
      'description': description,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // جلب نقاط المكافئات (تجريبي حالياً)
  Future<int> getRewardsPoints(String driverId) async {
    try {
      final doc = await _firestore.collection('drivers').doc(driverId).get();
      return (doc.data()?['rewardsPoints'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Error getting rewards points: $e');
      return 0;
    }
  }

  // جلب أرباح التطبيق (العمولات) لليوم
  Future<double> getAppEarningsToday(String driverId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      final query = await _firestore
          .collection('ride_requests')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      double commission = 0.0;
      for (var doc in query.docs) {
        commission += (doc.data()['commission'] as num?)?.toDouble() ?? 0.0;
      }
      return commission;
    } catch (e) {
      return 0.0;
    }
  }

  // ─── دوال إدارة العمولات والمديونية للآدمن ───

  // تسوية مديونية الكابتن واستلام العمولة
  Future<void> settleDriverCommission({
    required String driverId,
    required double amountPaid,
    String? adminId,
    String? adminNotes,
  }) async {
    try {
      final driverRef = _firestore.collection('drivers').doc(driverId);
      final snap = await driverRef.get();
      final currentDebt = (snap.data()?['appDebt'] as num?)?.toDouble() ?? 0.0;
      final newDebt = (currentDebt - amountPaid).clamp(0.0, double.infinity);

      final batch = _firestore.batch();
      batch.update(driverRef, {
        'appDebt': newDebt,
        'isCommissionBlocked': newDebt >= 5000.0,
        'lastSettledAt': FieldValue.serverTimestamp(),
        'lastSettledAmount': amountPaid,
        'lastSettledBy': adminId,
      });

      // حفظ العملية في سجل التسويات للتدقيق
      final settlementRef = _firestore.collection('commission_settlements').doc();
      batch.set(settlementRef, {
        'driverId': driverId,
        'amountPaid': amountPaid,
        'previousDebt': currentDebt,
        'remainingDebt': newDebt,
        'adminId': adminId,
        'notes': adminNotes ?? 'تسوية مستحقات نقدية من قبل الإدارة',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // إرسال إشعار داخلي للكابتن بالتسوية
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': driverId,
        'title': 'تم تسديد عمولة من محفظتك',
        'body': 'تم استلام وتسوية مبلغ ${amountPaid.toStringAsFixed(0)} د.ع من عمولة التطبيق. المتبقي: ${newDebt.toStringAsFixed(0)} د.ع.',
        'type': 'wallet_settlement',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Error in settleDriverCommission: $e');
      rethrow;
    }
  }

  // تصفير محفظة الكابتن بالكامل (Zero Out Wallet)
  Future<void> resetDriverWalletCompletely({
    required String driverId,
    String? adminId,
    String? reason,
  }) async {
    try {
      final driverRef = _firestore.collection('drivers').doc(driverId);
      final snap = await driverRef.get();
      final currentDebt = (snap.data()?['appDebt'] as num?)?.toDouble() ?? 0.0;

      final batch = _firestore.batch();
      batch.update(driverRef, {
        'appDebt': 0.0,
        'isCommissionBlocked': false,
        'lastSettledAt': FieldValue.serverTimestamp(),
        'lastSettledAmount': currentDebt,
        'lastSettledBy': adminId,
      });

      // حفظ التصفير في سجل العمليات
      final settlementRef = _firestore.collection('commission_settlements').doc();
      batch.set(settlementRef, {
        'driverId': driverId,
        'amountPaid': currentDebt,
        'previousDebt': currentDebt,
        'remainingDebt': 0.0,
        'isFullReset': true,
        'adminId': adminId,
        'notes': reason ?? 'تصفير شامل لمحفظة الكابتن وفك الحظر بالكامل',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // إرسال إشعار فوري للكابتن
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': driverId,
        'title': 'تم تصفير محفظتك بنجاح!',
        'body': 'تم تصفير مديونية عمولة التطبيق بالكامل لحسابك، وأصبح بإمكانك استقبال كافة المشاوير والطلبات الآن.',
        'type': 'wallet_reset',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint(' [DriverService] Driver $driverId wallet completely zeroed out.');
    } catch (e) {
      debugPrint(' [DriverService] Error in resetDriverWalletCompletely: $e');
      rethrow;
    }
  }

  // تفعيل / إلغاء الاستثناء للكابتن (السماح باستقبال الطلبات حتى لو تجاوز الحد)
  Future<void> toggleDriverCommissionException({
    required String driverId,
    required bool allowException,
  }) async {
    try {
      await _firestore.collection('drivers').doc(driverId).update({
        'commissionException': allowException,
        'exceptionUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error in toggleDriverCommissionException: $e');
      rethrow;
    }
  }

  // تعديل الحد الأقصى للمديونية المسموحة لكابتن معين
  Future<void> updateDriverCommissionLimit({
    required String driverId,
    required double newLimit,
  }) async {
    try {
      await _firestore.collection('drivers').doc(driverId).update({
        'customCommissionLimit': newLimit,
        'limitUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error in updateDriverCommissionLimit: $e');
      rethrow;
    }
  }

  // إرسال بلاغ طارئ مشفر (SOS Emergency Alert)
  Future<String> sendEmergencySos({
    required String driverId,
    required String driverName,
    required String driverPhone,
    required double latitude,
    required double longitude,
    String? activeRideId,
    Map<String, dynamic>? activeRideData,
  }) async {
    try {
      final docRef = await _firestore.collection('emergency_sos_alerts').add({
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'latitude': latitude,
        'longitude': longitude,
        'activeRideId': activeRideId,
        'passengerName': activeRideData?['passengerName'] ?? activeRideData?['customerName'],
        'passengerPhone': activeRideData?['passengerPhone'] ?? activeRideData?['customerPhone'],
        'pickupAddress': activeRideData?['pickupAddress'],
        'dropoffAddress': activeRideData?['dropoffAddress'],
        'status': 'urgent_open',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // إشعار فوري لغرفة العمليات
      try {
        await NotificationService.emitEvent(
          type: 'sos_emergency_alert',
          payload: {
            'alertId': docRef.id,
            'driverId': driverId,
            'driverName': driverName,
            'title': 'إنذار طوارئ SOS عاجل!',
            'body': 'الكابتن $driverName أطلق نداء استغاثة فوري، يرجى التدخل!',
            'lat': latitude,
            'lng': longitude,
          },
        );
      } catch (_) {}

      return docRef.id;
    } catch (e) {
      debugPrint('Error sending emergency SOS: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ── منظومة التقييمات والمراجعات (Rating & Reviews Engine) ──
  // ════════════════════════════════════════════════════════════════════════════

  // 1. تسجيل تقييم الراكب للكابتن
  Future<void> submitPassengerReviewForDriver({
    required String rideId,
    required String driverId,
    required String passengerId,
    required String passengerName,
    required double rating,
    List<String>? compliments,
    List<String>? issues,
    String? comment,
    String? driverName,
  }) async {
    try {
      final reviewDoc = {
        'rideId': rideId,
        'driverId': driverId,
        'driverName': driverName ?? 'كابتن مدار',
        'passengerId': passengerId,
        'passengerName': passengerName,
        'rating': rating,
        'compliments': compliments ?? [],
        'issues': issues ?? [],
        'comment': comment?.trim() ?? '',
        'type': 'passenger_to_driver',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // إضافة المراجعة لمجموعة التقييمات
      await _firestore.collection('driver_reviews').add(reviewDoc);

      // تحديث ذري لمعدل تقييم الكابتن في حسابه
      await _firestore.runTransaction((tx) async {
        final driverRef = _firestore.collection('drivers').doc(driverId);
        final snap = await tx.get(driverRef);
        if (snap.exists) {
          final data = snap.data() ?? {};
          final currentSum = (data['ratingSum'] as num?)?.toDouble() ?? ((data['rating'] as num?)?.toDouble() ?? 5.0);
          final currentCount = (data['ratingCount'] as num?)?.toInt() ?? 1;

          final newSum = currentSum + rating;
          final newCount = currentCount + 1;
          final newAvg = double.parse((newSum / newCount).toStringAsFixed(2));

          final Map<String, dynamic> updateData = {
            'ratingSum': newSum,
            'ratingCount': newCount,
            'rating': newAvg,
            'lastRatedAt': FieldValue.serverTimestamp(),
          };

          // زيادة عداد الأوسمة الإيجابية للكابتن
          if (compliments != null) {
            for (var tag in compliments) {
              updateData['complimentCounts.$tag'] = FieldValue.increment(1);
            }
          }

          tx.update(driverRef, updateData);
        }
      });

      // تحديث مستند الرحلة
      await _firestore.collection('ride_requests').doc(rideId).update({
        'isRated': true,
        'passengerRated': true,
        'passengerRating': rating,
        'passengerComment': comment?.trim() ?? '',
        'passengerCompliments': compliments ?? [],
        'passengerIssues': issues ?? [],
        'ratedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error submitting passenger review: $e');
      rethrow;
    }
  }

  // 2. تسجيل تقييم الكابتن للراكب
  Future<void> submitDriverReviewForPassenger({
    required String rideId,
    required String passengerId,
    required String driverId,
    required String driverName,
    required double rating,
    List<String>? tags,
    String? comment,
    String? passengerName,
  }) async {
    try {
      final reviewDoc = {
        'rideId': rideId,
        'passengerId': passengerId,
        'passengerName': passengerName ?? 'الراكب',
        'driverId': driverId,
        'driverName': driverName,
        'rating': rating,
        'tags': tags ?? [],
        'comment': comment?.trim() ?? '',
        'type': 'driver_to_passenger',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('passenger_reviews').add(reviewDoc);

      // تحديث تقييم الراكب في حسابه
      if (passengerId.isNotEmpty) {
        await _firestore.runTransaction((tx) async {
          final userRef = _firestore.collection('users').doc(passengerId);
          final snap = await tx.get(userRef);
          if (snap.exists) {
            final data = snap.data() ?? {};
            final currentSum = (data['passengerRatingSum'] as num?)?.toDouble() ?? 5.0;
            final currentCount = (data['passengerRatingCount'] as num?)?.toInt() ?? 1;

            final newSum = currentSum + rating;
            final newCount = currentCount + 1;
            final newAvg = double.parse((newSum / newCount).toStringAsFixed(2));

            tx.update(userRef, {
              'passengerRatingSum': newSum,
              'passengerRatingCount': newCount,
              'passengerRating': newAvg,
            });
          }
        });
      }

      // تحديث مستند الرحلة
      await _firestore.collection('ride_requests').doc(rideId).update({
        'driverRated': true,
        'driverRating': rating,
        'driverRatingComment': comment?.trim() ?? '',
        'driverRatingTags': tags ?? [],
      });
    } catch (e) {
      debugPrint('Error submitting driver review: $e');
      rethrow;
    }
  }

  // 3. دفق مراجعات الكابتن (Reviews Feed)
  Stream<QuerySnapshot<Map<String, dynamic>>> getDriverReviewsStream(String driverId) {
    return _firestore
        .collection('driver_reviews')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // 4. دفق كافة المراجعات للوحة الأدمن
  Stream<QuerySnapshot<Map<String, dynamic>>> getAllReviewsStream() {
    return _firestore
        .collection('driver_reviews')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  // 5. إجراءات الإدارة على التقييمات (شكر / تنبيه / حذف)
  Future<void> sendAdminReviewAction({
    required String reviewId,
    required String driverId,
    required String actionType, // 'warn_driver' | 'thank_driver' | 'delete_review'
    String? note,
  }) async {
    try {
      if (actionType == 'delete_review') {
        await _firestore.collection('driver_reviews').doc(reviewId).delete();
      } else {
        await _firestore.collection('driver_reviews').doc(reviewId).update({
          'adminAction': actionType,
          'adminNote': note,
          'adminActionAt': FieldValue.serverTimestamp(),
        });

        // إشعار للكابتن
        final title = actionType == 'thank_driver' ? 'شكر وتقدير من الإدارة!' : 'تنبيه إداري بشأن تقييم رحلة';
        final body = note ?? (actionType == 'thank_driver' ? 'أحسنت! الإدارة تشكرك على أدائك الممتاز وحصولك على تقييمات عالية.' : 'يرجى مراجعة ملاحظات الركاب والحرص على جودة الخدمة.');

        await _firestore.collection('drivers').doc(driverId).collection('notifications').add({
          'title': title,
          'body': body,
          'type': actionType,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (e) {
      debugPrint('Error handling admin review action: $e');
      rethrow;
    }
  }
}
