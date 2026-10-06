import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mersal_request.dart';
import 'notification_service.dart';

class MersalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionPath = 'mersal_requests';

  Future<String> createRequest(MersalRequest request) async {
    final docRef = await _firestore.collection(collectionPath).add(request.toMap());
    
    // ℹ لا حاجة لـ emitEvent هنا — Cloud Function (notifyDriversOnNewMersal)
    // يتعامل مع الإشعار تلقائياً عبر mersal_requests onCreate trigger

    
    return docRef.id;
  }

  Stream<List<MersalRequest>> getUserActiveOrders(String userId) {
    return _firestore
        .collection(collectionPath)
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['pending', 'accepted', 'arrived_at_pickup', 'picked_up', 'on_the_way'])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => MersalRequest.fromMap(doc.data(), doc.id)).toList();
        });
  }

  Stream<List<MersalRequest>> getPendingRequestsStream() {
    return _firestore
        .collection(collectionPath)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final list = snapshot.docs
              .map((doc) => MersalRequest.fromMap(doc.data(), doc.id))
              .where((req) => req.createdAt == null || now.difference(req.createdAt!).inMinutes < 30)
              .toList();
          list.sort(
            (a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()),
          );
          return list;
        });
  }

  Stream<MersalRequest?> getRequestStream(String requestId) {
    return _firestore.collection(collectionPath).doc(requestId).snapshots().map((doc) {
      if (doc.exists) {
        return MersalRequest.fromMap(doc.data()!, doc.id);
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
              'driverImage': driverData['imageUrl'] ?? '',
              'price': agreedPrice,
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
                type: 'mersal_status_updated',
                payload: {
                  'request_id': requestId,
                  'status': 'accepted',
                  'price': agreedPrice,
                  'driver_name': driverData['name'] ?? 'مندوب مدار',
                  'driver_phone': driverData['phone'] ?? '',
                },
              );
            }
            return result;
          });
    } catch (e) {
      debugPrint('Error accepting mersal request: $e');
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
      const terminalStatuses = {'completed', 'cancelled', 'delivered'};

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
      type: 'mersal_status_updated',
      payload: {'request_id': requestId, 'status': status},
    );
  }

  Future<bool> cancelRequest(String requestId, {String? reason}) async {
    try {
      await updateStatus(
        requestId,
        'cancelled',
        extraData: {
          'cancelReason': reason ?? 'إلغاء من قبل الزبون',
          'cancelledAt': FieldValue.serverTimestamp(),
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error cancelling mersal request: $e');
      return false;
    }
  }

  Stream<List<MersalRequest>> getDriverActiveOrders(String driverId) {
    return _firestore
        .collection(collectionPath)
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['accepted', 'arrived_at_pickup', 'picked_up', 'on_the_way'])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => MersalRequest.fromMap(doc.data(), doc.id)).toList();
        });
  }

  Stream<List<MersalRequest>> getDriverHistoryStream(String driverId) {
    return _firestore
        .collection(collectionPath)
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'delivered')
        .snapshots()
        .map((snapshot) {
          final list =
              snapshot.docs.map((doc) => MersalRequest.fromMap(doc.data(), doc.id)).toList();
          list.sort(
            (a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()),
          );
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
            final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate() ?? 
                              (data['createdAt'] as Timestamp?)?.toDate();
            if (updatedAt != null && updatedAt.isAfter(startOfDay)) {
              count++;
              String p = data['price']?.toString() ?? '0';
              p = p.replaceAll(RegExp(r'[^0-9.]'), '');
              totalEarnings += (double.tryParse(p) ?? 0.0);
            }
          }

          return {'count': count, 'earnings': totalEarnings};
        });
  }
}
