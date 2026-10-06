import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/parcel_delivery_request.dart';
import 'notification_service.dart';

class ParcelDeliveryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionPath = 'parcel_delivery_requests';

  Future<String> createRequest(ParcelDeliveryRequest request) async {
    final docRef = await _firestore.collection(collectionPath).add(request.toMap());

    // Emit Event to Server
    if (request.vehicleType.contains('نقل') || request.vehicleType.contains('حمل')) {
      await NotificationService.emitEvent(
        type: 'freight_request_created',
        payload: {'request_id': docRef.id},
      );
    } else {
      await NotificationService.emitEvent(
        type: 'parcel_request_created',
        payload: {'request_id': docRef.id},
      );
    }

    return docRef.id;
  }

  Stream<List<ParcelDeliveryRequest>> getPendingRequestsStream() {
    return _firestore
        .collection(collectionPath)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final list = snapshot.docs
              .map((doc) => ParcelDeliveryRequest.fromMap(doc.data(), doc.id))
              .where((req) => now.difference(req.createdAt).inMinutes < 30)
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<ParcelDeliveryRequest?> getRequestStream(String requestId) {
    return _firestore.collection(collectionPath).doc(requestId).snapshots().map((doc) {
      if (doc.exists) {
        return ParcelDeliveryRequest.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  Future<bool> acceptRequest({
    required String requestId,
    required String driverId,
    required Map<String, dynamic> driverData,
    required String agreedPrice,
  }) async {
    final reqRef = _firestore.collection(collectionPath).doc(requestId);
    final driverRef = _firestore.collection('drivers').doc(driverId);
    final userRef = _firestore.collection('users').doc(driverId);

    try {
      return await _firestore
          .runTransaction<bool>((tx) async {
            final snap = await tx.get(reqRef);
            if (!snap.exists) return false;

            final status = (snap.data() ?? {})['status'] as String? ?? 'pending';
            if (status != 'pending') return false;

            // تحديث الطلب
            tx.update(reqRef, {
              'status': 'accepted',
              'driverId': driverId,
              'driverName': driverData['name'] ?? 'كابتن',
              'driverPhone': driverData['phone'] ?? '',
              'price': double.tryParse(agreedPrice) ?? 0.0,
              'acceptedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            // تحديث السائق: يبقى متصل ولكنه غير متاح لاستلام طلبات جديدة حالياً
            final Map<String, dynamic> driverStatusUpdates = {
              'available': false,
              'onTripSince': FieldValue.serverTimestamp(),
              'lastStatusUpdate': FieldValue.serverTimestamp(),
            };

            tx.update(driverRef, driverStatusUpdates);
            tx.update(userRef, driverStatusUpdates);

            return true;
          })
          .then((result) async {
            if (result == true) {
              // Emit Event to Server
              await NotificationService.emitEvent(
                type: 'parcel_status_updated',
                payload: {'request_id': requestId, 'status': 'accepted'},
              );
            }
            return result;
          });
    } catch (e) {
      debugPrint('Error accepting parcel request: $e');
      return false;
    }
  }

  Future<void> updateStatus(
    String requestId,
    String status, {
    Map<String, dynamic>? extraData,
  }) async {
    final docRef = _firestore.collection(collectionPath).doc(requestId);

    await _firestore.runTransaction((tx) async {
      // 1. ALL READS FIRST
      final snap = await tx.get(docRef);
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      final driverId = data['driverId'] as String?;

      // حالات انتهاء الرحلة
      const terminalStatuses = {'delivered', 'cancelled'};

      final DocumentReference? driverRef = driverId != null ? _firestore.collection('drivers').doc(driverId) : null;
      DocumentSnapshot? driverSnap;
      if (driverRef != null && terminalStatuses.contains(status)) {
        driverSnap = await tx.get(driverRef);
      }

      // 2. PREPARE ALL MUTATIONS
      final Map<String, dynamic> updates = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (extraData != null) updates.addAll(extraData);

      final Map<String, dynamic> resetStatus = {};
      if (driverId != null && terminalStatuses.contains(status)) {
        final driverData = (driverSnap != null && driverSnap.exists) 
            ? driverSnap.data() as Map<String, dynamic>? ?? {} 
            : {};
        final bool isOnlineMode = (driverData['availability'] ?? 'offline') == 'online';

        resetStatus['available'] = isOnlineMode;
        resetStatus['onTripSince'] = FieldValue.delete();
        resetStatus['lastStatusUpdate'] = FieldValue.serverTimestamp();
      }

      // 3. ALL WRITES AFTER ALL READS
      tx.update(docRef, updates);

      if (driverRef != null && resetStatus.isNotEmpty) {
        final userRef = _firestore.collection('users').doc(driverId);
        tx.update(driverRef, resetStatus);
        tx.update(userRef, resetStatus);
      }
    });

    // Emit Event to Server
    await NotificationService.emitEvent(
      type: 'parcel_status_updated',
      payload: {'request_id': requestId, 'status': status},
    );
  }

  Stream<List<ParcelDeliveryRequest>> getDriverActiveOrders(String driverId) {
    return _firestore
        .collection(collectionPath)
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['accepted', 'arrived_at_pickup', 'picked_up', 'on_the_way'])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ParcelDeliveryRequest.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Stream<List<ParcelDeliveryRequest>> getAllRequestsStream() {
    return _firestore
        .collection(collectionPath)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ParcelDeliveryRequest.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Stream<List<ParcelDeliveryRequest>> getUserRequestsStream(String userId) {
    return _firestore.collection(collectionPath).where('userId', isEqualTo: userId).snapshots().map(
      (snapshot) {
        final list =
            snapshot.docs.map((doc) => ParcelDeliveryRequest.fromMap(doc.data(), doc.id)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      },
    );
  }

  Stream<List<ParcelDeliveryRequest>> getDriverHistoryStream(String driverId) {
    return _firestore
        .collection(collectionPath)
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'delivered')
        .snapshots()
        .map((snapshot) {
          final list =
              snapshot.docs
                  .map((doc) => ParcelDeliveryRequest.fromMap(doc.data(), doc.id))
                  .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Stream<Map<String, dynamic>> getDriverDailyStatsStream(String driverId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return _firestore
        .collection(collectionPath)
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'delivered')
        .snapshots()
        .map((snapshot) {
          double totalEarnings = 0;
          int count = 0;

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            if (createdAt != null && createdAt.isAfter(startOfDay)) {
              count++;
              totalEarnings += (data['price'] ?? 0.0).toDouble();
            }
          }

          return {'count': count, 'earnings': totalEarnings};
        });
  }

  Stream<double> getDriverTotalEarningsStream(String driverId) {
    return _firestore
        .collection(collectionPath)
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'delivered')
        .snapshots()
        .map((snapshot) {
          double total = 0;
          for (var doc in snapshot.docs) {
            total += (doc.data()['price'] ?? 0.0).toDouble();
          }
          return total;
        });
  }

  Stream<List<int>> getDriverWeeklyActivityStream(String driverId) {
    final now = DateTime.now();
    final sevenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

    return _firestore
        .collection(collectionPath)
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'delivered')
        .where('createdAt', isGreaterThanOrEqualTo: sevenDaysAgo)
        .snapshots()
        .map((snapshot) {
          List<int> dailyCounts = List.filled(7, 0);
          for (var doc in snapshot.docs) {
            final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
            if (createdAt != null) {
              final diff = now.difference(createdAt).inDays;
              if (diff >= 0 && diff < 7) {
                dailyCounts[6 - diff]++;
              }
            }
          }
          return dailyCounts;
        });
  }

  Future<void> requestWithdrawal(String driverId, double amount, String driverName) async {
    await _firestore.collection('withdrawal_requests').add({
      'driverId': driverId,
      'driverName': driverName,
      'amount': amount,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
      'type': 'transport',
    });
  }
}
