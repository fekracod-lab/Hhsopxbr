// مستودع بيانات لوحة تحكم مندوب التوصيل (Delivery Dashboard Repository)
// Clean Architecture Data Layer — Zero UI / Widget Dependencies

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/delivery_dashboard_models.dart';
import '../datasources/delivery_dashboard_remote_datasource.dart';

/// مستودع البيانات الدفاعي للوحة تحكم المندوب
class DeliveryDashboardRepository {
  final DeliveryDashboardRemoteDatasource _datasource;

  DeliveryDashboardRepository({DeliveryDashboardRemoteDatasource? datasource})
      : _datasource = datasource ?? DeliveryDashboardRemoteDatasource();

  // ────────────────────────────────────────────
  // 1. تدفقات وثائق السائق وحالة التوفر
  // ────────────────────────────────────────────

  /// تدفق بيانات السائق المدمجة (users + drivers)
  Stream<Map<String, dynamic>> watchDriverProfile(String uid) {
    return _datasource.watchDriverDocument(uid).map((doc) {
      if (!doc.exists) return <String, dynamic>{};
      final data = doc.data() ?? {};
      data['id'] = doc.id;
      data['uid'] = doc.id;
      return data;
    });
  }

  /// حفظ حالة اتصال وتوفر السائق
  Future<void> setDriverAvailability({
    required String driverId,
    required DriverAvailabilityState availabilityState,
  }) async {
    await _datasource.setDriverAvailability(
      driverId: driverId,
      status: availabilityState.toDbString(),
    );
  }

  // ────────────────────────────────────────────
  // 2. تدفقات طلبات مرسال (Mersal Requests)
  // ────────────────────────────────────────────

  /// تدفق طلبات مرسال المعلقة
  Stream<List<DeliveryOrderEntity>> watchPendingMersalOrders() {
    return _datasource.watchPendingMersalRequests().map((snapshot) {
      return snapshot.docs
          .map((doc) => mapMersalDocToEntity(doc.data(), doc.id))
          .toList();
    });
  }

  /// تدفق طلبات مرسال النشطة للسائق
  Stream<List<DeliveryOrderEntity>> watchActiveMersalOrders(String driverId) {
    return _datasource.watchActiveMersalRequests(driverId).map((snapshot) {
      return snapshot.docs
          .map((doc) => mapMersalDocToEntity(doc.data(), doc.id))
          .toList();
    });
  }

  /// تدفق سجل طلبات مرسال المكتملة للسائق
  Stream<List<DeliveryOrderEntity>> watchHistoryMersalOrders(String driverId) {
    return _datasource.watchHistoryMersalRequests(driverId).map((snapshot) {
      return snapshot.docs
          .map((doc) => mapMersalDocToEntity(doc.data(), doc.id))
          .toList();
    });
  }

  /// قبول طلب مرسال وتحديد الأجرة المتفق عليها
  Future<bool> acceptMersalOrder({
    required String requestId,
    required String driverId,
    required Map<String, dynamic> driverData,
    required String agreedPrice,
  }) async {
    return await _datasource.acceptMersalRequestAtomic(
      requestId: requestId,
      driverId: driverId,
      driverData: driverData,
      agreedPrice: agreedPrice,
    );
  }

  // ────────────────────────────────────────────
  // 3. تدفقات طلبات وجبات المطاعم (Food Orders)
  // ────────────────────────────────────────────

  /// تدفق طلبات المطاعم المتاحة للتوصيل
  Stream<List<DeliveryOrderEntity>> watchAvailableFoodOrders() {
    const allowedStatuses = ['ready', 'pending', 'accepted', 'preparing'];
    return _datasource.watchAvailableFoodOrders().map((snapshot) {
      final list = <DeliveryOrderEntity>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase().trim() ?? '';
        final driverId = data['driverId']?.toString();

        if (allowedStatuses.contains(status) && (driverId == null || driverId.isEmpty)) {
          list.add(mapFoodDocToEntity(data, doc.id));
        }
      }
      return list;
    });
  }

  /// تدفق طلبات المطاعم النشطة للسائق
  Stream<List<DeliveryOrderEntity>> watchActiveFoodOrders(String driverId) {
    return _datasource.watchActiveFoodOrders(driverId).map((snapshot) {
      return snapshot.docs
          .map((doc) => mapFoodDocToEntity(doc.data(), doc.id))
          .toList();
    });
  }

  /// تدفق سجل طلبات المطاعم المكتملة للسائق
  Stream<List<DeliveryOrderEntity>> watchHistoryFoodOrders(String driverId) {
    return _datasource.watchHistoryFoodOrders(driverId).map((snapshot) {
      return snapshot.docs
          .map((doc) => mapFoodDocToEntity(doc.data(), doc.id))
          .toList();
    });
  }

  /// قبول طلب وجبة مطعم
  Future<bool> acceptFoodOrder({
    required String orderId,
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    return await _datasource.acceptFoodOrderAtomic(
      orderId: orderId,
      driverId: driverId,
      driverData: driverData,
    );
  }

  // ────────────────────────────────────────────
  // 4. تدفقات طلبات المتاجر والمسواك (Store Orders)
  // ────────────────────────────────────────────

  /// تدفق طلبات المتاجر المتاحة للتوصيل
  Stream<List<DeliveryOrderEntity>> watchAvailableStoreOrders() {
    const allowedStatuses = ['pending', 'ready', 'accepted'];
    return _datasource.watchAvailableStoreOrders().map((snapshot) {
      final list = <DeliveryOrderEntity>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase().trim() ?? '';
        final driverId = data['driverId']?.toString();

        if (allowedStatuses.contains(status) && (driverId == null || driverId.isEmpty)) {
          final storeId = _extractStoreIdFromPath(doc.reference.path, data['storeId']);
          list.add(mapStoreDocToEntity(data, doc.id, storeId: storeId));
        }
      }
      return list;
    });
  }

  /// تدفق طلبات المتاجر النشطة للسائق
  Stream<List<DeliveryOrderEntity>> watchActiveStoreOrders(String driverId) {
    return _datasource.watchActiveStoreOrders(driverId).map((snapshot) {
      final list = <DeliveryOrderEntity>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase().trim();
        if (status == 'delivering' || status == 'picked_up') {
          final storeId = _extractStoreIdFromPath(doc.reference.path, data['storeId']);
          list.add(mapStoreDocToEntity(data, doc.id, storeId: storeId));
        }
      }
      return list;
    });
  }

  /// تدفق سجل طلبات المتاجر المكتملة للسائق
  Stream<List<DeliveryOrderEntity>> watchHistoryStoreOrders(String driverId) {
    return _datasource.watchHistoryStoreOrders(driverId).map((snapshot) {
      final list = <DeliveryOrderEntity>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase().trim();
        if (status == 'completed' || status == 'delivered') {
          final storeId = _extractStoreIdFromPath(doc.reference.path, data['storeId']);
          list.add(mapStoreDocToEntity(data, doc.id, storeId: storeId));
        }
      }
      return list;
    });
  }

  /// قبول طلب متجر
  Future<bool> acceptStoreOrder({
    required String storeId,
    required String orderId,
    required String driverId,
    required Map<String, dynamic> driverData,
  }) async {
    return await _datasource.acceptStoreOrderAtomic(
      storeId: storeId,
      orderId: orderId,
      driverId: driverId,
      driverData: driverData,
    );
  }

  // ────────────────────────────────────────────
  // 5. دوال التحويل الدفاعية الصافية (Defensive Mappers)
  // ────────────────────────────────────────────

  /// تحويل بيانات وثيقة مرسال إلى كيان النطاق
  static DeliveryOrderEntity mapMersalDocToEntity(Map<String, dynamic> data, String id) {
    final rawPrice = data['price']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '';
    final parsedFee = double.tryParse(rawPrice) ?? 0.0;
    final bool isCustom = parsedFee <= 0;
    final estCost = (data['estimatedCost'] as num?)?.toDouble() ?? 0.0;

    return DeliveryOrderEntity(
      id: id,
      source: DeliveryOrderSource.mersal,
      status: DeliveryOrderStatus.fromString(data['status']?.toString()),
      sourceName: data['storeName'] ?? data['requestDescription'] ?? 'طلب شراء / أمانة',
      dropoffName: data['dropoffAddress'] ?? data['userAddress'] ?? 'نقطة التسليم',
      deliveryFee: parsedFee > 0 ? parsedFee : 0.0,
      isCustomPrice: isCustom,
      orderTotal: estCost > 0 ? estCost : 0.0,
      customerId: data['userId'] ?? data['customerId'] ?? '',
      customerName: data['userName'] ?? data['customerName'] ?? '',
      customerPhone: data['userPhone'] ?? data['customerPhone'] ?? '',
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? '',
      createdAt: _parseDateTime(data['createdAt']),
      acceptedAt: _parseDateTime(data['acceptedAt']),
      completedAt: _parseDateTime(data['completedAt'] ?? data['deliveredAt'] ?? data['updatedAt']),
      rawData: data,
    );
  }

  /// تحويل بيانات وثيقة طلب المطعم إلى كيان النطاق
  static DeliveryOrderEntity mapFoodDocToEntity(Map<String, dynamic> data, String id) {
    final fee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;

    return DeliveryOrderEntity(
      id: id,
      source: DeliveryOrderSource.food,
      status: DeliveryOrderStatus.fromString(data['status']?.toString()),
      sourceName: data['restaurantName'] ?? data['merchantName'] ?? 'المطعم',
      dropoffName: data['userAddress'] ?? data['deliveryAddress'] ?? 'موقع الزبون',
      deliveryFee: fee > 0 ? fee : 0.0,
      isCustomPrice: false,
      orderTotal: total > 0 ? total : 0.0,
      customerId: data['customerId'] ?? data['userId'] ?? '',
      customerName: data['customerName'] ?? data['userName'] ?? '',
      customerPhone: data['customerPhone'] ?? data['userPhone'] ?? '',
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? '',
      createdAt: _parseDateTime(data['createdAt']),
      acceptedAt: _parseDateTime(data['acceptedAt'] ?? data['driverAssignedAt']),
      completedAt: _parseDateTime(data['completedAt'] ?? data['deliveredAt'] ?? data['updatedAt']),
      rawData: data,
    );
  }

  /// تحويل بيانات وثيقة طلب المتجر إلى كيان النطاق
  static DeliveryOrderEntity mapStoreDocToEntity(
    Map<String, dynamic> data,
    String id, {
    String? storeId,
  }) {
    final fee = (data['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;

    return DeliveryOrderEntity(
      id: id,
      source: DeliveryOrderSource.store,
      status: DeliveryOrderStatus.fromString(data['status']?.toString()),
      sourceName: data['storeName'] ?? data['merchantName'] ?? 'المتجر',
      dropoffName: data['userAddress'] ?? data['deliveryAddress'] ?? 'موقع الزبون',
      deliveryFee: fee > 0 ? fee : 0.0,
      isCustomPrice: false,
      orderTotal: total > 0 ? total : 0.0,
      customerId: data['customerId'] ?? data['userId'] ?? '',
      customerName: data['customerName'] ?? data['userName'] ?? '',
      customerPhone: data['customerPhone'] ?? data['userPhone'] ?? '',
      driverId: data['driverId'] ?? '',
      driverName: data['driverName'] ?? '',
      createdAt: _parseDateTime(data['createdAt']),
      acceptedAt: _parseDateTime(data['acceptedAt'] ?? data['driverAssignedAt'] ?? data['assignedAt']),
      completedAt: _parseDateTime(data['completedAt'] ?? data['deliveredAt'] ?? data['updatedAt']),
      rawData: {
        ...data,
        if (storeId != null && !data.containsKey('storeId')) 'storeId': storeId,
      },
    );
  }

  /// استخراج آمن للتاريخ والوقت من مختلف الصيغ الممكنة
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  /// استخراج معرف المتجر من مسار وثيقة Firestore
  static String? _extractStoreIdFromPath(String path, dynamic fallback) {
    if (fallback != null && fallback.toString().isNotEmpty) {
      return fallback.toString();
    }
    final segments = path.split('/');
    if (segments.length >= 2 && segments[0] == 'stores') {
      return segments[1];
    }
    return null;
  }
}
