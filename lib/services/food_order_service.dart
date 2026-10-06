import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class FoodOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionPath = 'orders';

  // 1. الطلبات المتاحة للتوصيل (Available Food Orders)
  Stream<List<Map<String, dynamic>>> getPendingReadyOrders() {
    const allowedStatuses = ['ready', 'pending', 'accepted', 'preparing'];
    return _firestore
        .collection(collectionPath)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final list = snapshot.docs
              .where((doc) {
                final data = doc.data();
                final status = data['status']?.toString() ?? '';
                final driverId = data['driverId']?.toString();
                // Filter only unassigned orders with active valid status
                return allowedStatuses.contains(status) && (driverId == null || driverId.isEmpty);
              })
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                data['type'] = 'food_order';
                return data;
              })
              .where((order) {
                final createdAt = (order['createdAt'] as Timestamp?)?.toDate();
                if (createdAt == null) return true;
                return now.difference(createdAt).inMinutes < 60;
              })
              .toList();

          // Sort by createdAt descending
          list.sort((a, b) {
            final t1 = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final t2 = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return t2.compareTo(t1);
          });

          return list;
        });
  }

  // 2. طلبات السائق النشطة (Active)
  Stream<List<Map<String, dynamic>>> getDriverActiveOrders(String driverId) {
    return _firestore
        .collection(collectionPath)
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'delivering')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['type'] = 'food_order';
            return data;
          }).toList();
        });
  }

  // 3. سجل السائق (History)
  Stream<List<Map<String, dynamic>>> getDriverHistoryStream(String driverId) {
    return _firestore
        .collection(collectionPath)
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['completed', 'delivered'])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['type'] = 'food_order';
            return data;
          }).toList();
        });
  }

  // 4. إحصائيات الأرباح اليومية
  Stream<Map<String, dynamic>> getDriverDailyStatsStream(String driverId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return _firestore
        .collection(collectionPath)
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['completed', 'delivered'])
        .snapshots()
        .map((snapshot) {
          double totalEarnings = 0;
          int count = 0;

          // Filter by date client-side to act independently of Firestore indexes
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

            if (createdAt != null && createdAt.isAfter(startOfDay)) {
              count++;
              // ربح السائق من طلب المطعم (ثابت حالياً 1000 د.ع أو حسب الحقل)
              totalEarnings += (data['deliveryFee'] ?? 1000.0).toDouble();
            }
          }

          return {'count': count, 'earnings': totalEarnings};
        });
  }

  // 5. قبول الطلب
  Future<bool> acceptOrder(String orderId, String driverId, Map<String, dynamic> driverData) async {
    try {
      final docRef = _firestore.collection(collectionPath).doc(orderId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return false;

        final data = snapshot.data() as Map<String, dynamic>;
        final currentStatus = data['status']?.toString();
        const acceptableStatuses = ['ready', 'pending', 'accepted', 'preparing'];
        if (!acceptableStatuses.contains(currentStatus)) return false;

        transaction.update(docRef, {
          'status': 'delivering',
          'driverId': driverId,
          'driverName': driverData['name'] ?? 'كابتن',
          'driverPhone': driverData['phone'] ?? '',
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // إشعار للزبون
      await NotificationService.emitEvent(
        type: 'order_status_updated',
        payload: {
          'order_id': orderId,
          'status': 'delivering',
          'driver_name': driverData['name'] ?? 'كابتن',
          'driver_phone': driverData['phone'] ?? '',
          'title': 'طلبيتك بالطريق إلك!',
          'body': 'الكابتن ${driverData['name'] ?? 'كابتن'} استلم الأكل من المطعم وهسة بالطريق لعندك ',
        },
      );

      return true;
    } catch (e) {
      debugPrint('Error accepting food order: $e');
      return false;
    }
  }

  // 6. تحديث حالة طلب المطعم (مع نظام المحاسبة)
  Future<void> updateOrderStatus(String orderId, String status) async {
    final docRef = _firestore.collection(collectionPath).doc(orderId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final String oldStatus = data['status'] ?? 'pending';
        if (oldStatus == status) return;

        final updates = {
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (status == 'completed' || status == 'delivered') {
          updates['completedAt'] = FieldValue.serverTimestamp();
          
          final double deliveryFee = (data['deliveryFee'] ?? 1000.0).toDouble();
          final double platformCommission = deliveryFee >= 500.0 ? 500.0 : 0.0; // عمولة المنصة ثابتة للتطبيق (500 د.ع)
          final double captainEarning = deliveryFee - platformCommission;
          final double merchantAmount = (data['total'] ?? 0.0).toDouble();
          final int customerPoints = (data['pointsEarned'] ?? 0).toInt();

          updates['platformCommission'] = platformCommission;
          updates['captainEarning'] = captainEarning;
          updates['merchantAmount'] = merchantAmount;
          updates['customerPoints'] = customerPoints;

          final String paymentStatus = data['paymentStatus'] ?? 'cash_on_delivery';
          final bool isCash = paymentStatus == 'cash_on_delivery' || paymentStatus == 'cash';
          final double cashCollected = isCash ? (merchantAmount + deliveryFee) : 0.0;
          final double merchantSettlement = isCash ? merchantAmount : 0.0;

          updates['cashCollected'] = cashCollected;
          updates['deliveryEarnings'] = deliveryFee;
          updates['merchantSettlement'] = merchantSettlement;

          final String? driverId = data['driverId']?.toString();
          if (driverId != null && driverId.isNotEmpty) {
            final driverRef = _firestore.collection('drivers').doc(driverId);
            final userRef = _firestore.collection('users').doc(driverId);

            transaction.update(driverRef, {
              'balance': FieldValue.increment(captainEarning),
              'totalEarnings': FieldValue.increment(captainEarning),
            });
            transaction.update(userRef, {
              'balance': FieldValue.increment(captainEarning),
              'totalEarnings': FieldValue.increment(captainEarning),
            });
          }
        } else if (status == 'picked_up') {
          updates['pickedUpAt'] = FieldValue.serverTimestamp();
        } else if (status == 'delivering') {
          updates['driverAssignedAt'] = FieldValue.serverTimestamp();
          updates['assignedAt'] = FieldValue.serverTimestamp();
        } else if (status == 'cancelled') {
          updates['cancelledAt'] = FieldValue.serverTimestamp();
        }

        transaction.update(docRef, updates);

        // تحديث سجل الزبون
        final String? customerId = data['customerId'] ?? data['userId'];
        if (customerId != null && customerId.isNotEmpty) {
          final userHistoryRef = _firestore
              .collection('madar_orders')
              .doc(customerId)
              .collection('orders')
              .doc(orderId);
          transaction.set(userHistoryRef, updates, SetOptions(merge: true));
        }
      });

      // إرسال إشعار
      await NotificationService.emitEvent(
        type: 'order_status_updated',
        payload: {'order_id': orderId, 'status': status},
      );
    } catch (e) {
      debugPrint('Error updating food order status: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getPendingReadyStoreOrders() {
    return _firestore
        .collectionGroup('madar_orders')
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          const allowedStatuses = ['pending', 'ready', 'accepted'];
          final list = snapshot.docs
              .where((doc) => allowedStatuses.contains(doc.data()['status']))
              .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['type'] = 'store_order';
            if (data['storeId'] == null) {
              final pathSegments = doc.reference.path.split('/');
              if (pathSegments.length >= 2 && pathSegments[0] == 'stores') {
                data['storeId'] = pathSegments[1];
              }
            }
            return data;
          }).where((order) {
            final createdAt = (order['createdAt'] as Timestamp?)?.toDate();
            if (createdAt == null) return true;
            return now.difference(createdAt).inMinutes < 60;
          }).toList();

          list.sort((a, b) {
            final t1 = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final t2 = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return t2.compareTo(t1);
          });

          return list;
        });
  }

  // --- 8. طلبات المتاجر النشطة للسائق ---
  Stream<List<Map<String, dynamic>>> getDriverActiveStoreOrders(String driverId) {
    return _firestore
        .collectionGroup('madar_orders')
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                data['type'] = 'store_order';
                if (data['storeId'] == null) {
                  final pathSegments = doc.reference.path.split('/');
                  if (pathSegments.length >= 2 && pathSegments[0] == 'stores') {
                    data['storeId'] = pathSegments[1];
                  }
                }
                return data;
              })
              .where((data) => data['status'] == 'delivering' || data['status'] == 'picked_up')
              .toList();
        });
  }

  // --- 9. قبول طلب المتجر ---
  Future<bool> acceptStoreOrder(String storeId, String orderId, String driverId, Map<String, dynamic> driverData) async {
    try {
      final storeOrderRef = _firestore
          .collection('stores')
          .doc(storeId)
          .collection('madar_orders')
          .doc(orderId);

      String? ownerId;

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(storeOrderRef);
        if (!snapshot.exists) return false;

        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status']?.toString();
        if (status != 'pending' && status != 'ready' && status != 'accepted') return false;

        ownerId = data['ownerId']?.toString();
        final customerId = data['customerId'] ?? data['userId'] ?? '';

        final driverUpdate = {
          'status': 'delivering',
          'driverId': driverId,
          'driverName': driverData['name'] ?? 'كابتن',
          'driverPhone': driverData['phone'] ?? '',
          'driverCar': '${driverData['carType'] ?? ''} - ${driverData['carNumber'] ?? ''}',
          'driverImage': driverData['imageUrl'] ?? driverData['photoUrl'] ?? '',
          'driverRating': (driverData['rating'] ?? 5.0).toDouble(),
          'assignedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        transaction.update(storeOrderRef, driverUpdate);

        // مزامنة سجل الزبون
        if (customerId.isNotEmpty) {
          final userHistoryRef = _firestore
              .collection('madar_orders')
              .doc(customerId)
              .collection('store_orders')
              .doc(orderId);
          transaction.set(userHistoryRef, driverUpdate, SetOptions(merge: true));
        }
      });

      // إشعار
      await NotificationService.emitEvent(
        type: 'store_order_status_updated',
        payload: {
          'order_id': orderId,
          'status': 'delivering',
          'ownerId': ownerId,
          'driver_name': driverData['name'] ?? 'كابتن',
          'driver_phone': driverData['phone'] ?? '',
          'title': 'طلب المتجر في الطريق!',
          'body': 'تم قبول طلبك بواسطة الكابتن ${driverData['name'] ?? 'كابتن'}. للتواصل: ${driverData['phone'] ?? ''}',
        },
      );

      return true;
    } catch (e) {
      debugPrint('Error accepting store order: $e');
      return false;
    }
  }

  // --- 10. تحديث حالة طلب المتجر (مع المحاسبة والنقاط) ---
  Future<void> updateStoreOrderStatus(String storeId, String orderId, String status) async {
    final storeOrderRef = _firestore
        .collection('stores')
        .doc(storeId)
        .collection('madar_orders')
        .doc(orderId);

    try {
      String? ownerId;

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(storeOrderRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final String oldStatus = data['status'] ?? 'pending';
        if (oldStatus == status) return;

        ownerId = data['ownerId']?.toString();

        final updates = {
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (status == 'completed' || status == 'delivered') {
          updates['completedAt'] = FieldValue.serverTimestamp();
          
          final double deliveryFee = (data['deliveryFee'] ?? 1000.0).toDouble();
          final double platformCommission = deliveryFee >= 500.0 ? 500.0 : 0.0; // عمولة المنصة ثابتة للتطبيق (500 د.ع)
          final double captainEarning = deliveryFee - platformCommission;
          final double merchantAmount = (data['total'] ?? 0.0).toDouble();
          final int customerPoints = (data['pointsEarned'] ?? 0).toInt();

          updates['platformCommission'] = platformCommission;
          updates['captainEarning'] = captainEarning;
          updates['merchantAmount'] = merchantAmount;
          updates['customerPoints'] = customerPoints;

          final String paymentStatus = data['paymentStatus'] ?? 'cash_on_delivery';
          final bool isCash = paymentStatus == 'cash_on_delivery' || paymentStatus == 'cash';
          final double cashCollected = isCash ? (merchantAmount + deliveryFee) : 0.0;
          final double merchantSettlement = isCash ? merchantAmount : 0.0;

          updates['cashCollected'] = cashCollected;
          updates['deliveryEarnings'] = deliveryFee;
          updates['merchantSettlement'] = merchantSettlement;

          final String? driverId = data['driverId']?.toString();
          if (driverId != null && driverId.isNotEmpty) {
            final driverRef = _firestore.collection('drivers').doc(driverId);
            final userRef = _firestore.collection('users').doc(driverId);

            transaction.update(driverRef, {
              'balance': FieldValue.increment(captainEarning),
              'totalEarnings': FieldValue.increment(captainEarning),
            });
            transaction.update(userRef, {
              'balance': FieldValue.increment(captainEarning),
              'totalEarnings': FieldValue.increment(captainEarning),
            });
          }

          // إضافة النقاط للزبون عند اكتمال الطلب
          final String? customerId = data['customerId'] ?? data['userId'];
          if (customerId != null && customerId.isNotEmpty && customerPoints > 0) {
            final customerRef = _firestore.collection('users').doc(customerId);
            transaction.update(customerRef, {
              'points': FieldValue.increment(customerPoints),
            });
          }
        } else if (status == 'picked_up') {
          updates['pickedUpAt'] = FieldValue.serverTimestamp();
        } else if (status == 'delivering') {
          updates['driverAssignedAt'] = FieldValue.serverTimestamp();
          updates['assignedAt'] = FieldValue.serverTimestamp();
        } else if (status == 'cancelled') {
          updates['cancelledAt'] = FieldValue.serverTimestamp();
        }

        transaction.update(storeOrderRef, updates);

        // مزامنة سجل الزبون
        final String? customerId = data['customerId'] ?? data['userId'];
        if (customerId != null && customerId.isNotEmpty) {
          final userHistoryRef = _firestore
              .collection('madar_orders')
              .doc(customerId)
              .collection('store_orders')
              .doc(orderId);
          transaction.set(userHistoryRef, updates, SetOptions(merge: true));
        }
      });

      // إشعار
      await NotificationService.emitEvent(
        type: 'store_order_status_updated',
        payload: {
          'order_id': orderId,
          'status': status,
          'ownerId': ownerId,
        },
      );
    } catch (e) {
      debugPrint('Error updating store order status: $e');
    }
  }

  // --- 11. سجل السائق لطلبات المتاجر (Store Order History) ---
  Stream<List<Map<String, dynamic>>> getDriverStoreHistoryStream(String driverId) {
    return _firestore
        .collectionGroup('madar_orders')
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['type'] = 'store_order';
            if (data['storeId'] == null) {
              final pathSegments = doc.reference.path.split('/');
              if (pathSegments.length >= 2 && pathSegments[0] == 'stores') {
                data['storeId'] = pathSegments[1];
              }
            }
            return data;
          })
          .where((data) => data['status'] == 'completed' || data['status'] == 'delivered')
          .toList();
        });
  }

  // --- 12. إحصائيات أرباح المتاجر اليومية ---
  Stream<Map<String, dynamic>> getDriverStoreDailyStatsStream(String driverId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return _firestore
        .collectionGroup('madar_orders')
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) {
          double totalEarnings = 0;
          int count = 0;

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status'] as String?;
            if (status == 'completed' || status == 'delivered') {
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

              if (createdAt != null && createdAt.isAfter(startOfDay)) {
                count++;
                totalEarnings += (data['deliveryFee'] ?? 1000.0).toDouble();
              }
            }
          }

          return {'count': count, 'earnings': totalEarnings};
        });
  }
}
