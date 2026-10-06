import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/delivery_execution_models.dart';
import '../../domain/repositories/i_delivery_execution_repository.dart';
import '../datasources/delivery_execution_remote_datasource.dart';
import '../datasources/delivery_location_datasource.dart';
import '../datasources/osrm_route_datasource.dart';

/// مستودع تنفيذ التوصيل الميداني (Delivery Execution Repository Implementation)
class DeliveryExecutionRepository implements IDeliveryExecutionRepository {
  final DeliveryExecutionRemoteDatasource _remoteDatasource;
  final DeliveryLocationDatasource _locationDatasource;
  final OsrmRouteDatasource _routeDatasource;

  DeliveryExecutionRepository({
    DeliveryExecutionRemoteDatasource? remoteDatasource,
    DeliveryLocationDatasource? locationDatasource,
    OsrmRouteDatasource? routeDatasource,
  }) : _remoteDatasource = remoteDatasource ?? DeliveryExecutionRemoteDatasource(),
        _locationDatasource = locationDatasource ?? DeliveryLocationDatasource(),
        _routeDatasource = routeDatasource ?? OsrmRouteDatasource();

  @override
  Stream<DeliveryExecutionEntity?> streamActiveDelivery(
    String orderId,
    OrderDeliverySource source,
  ) {
    return _remoteDatasource.streamOrderDoc(orderId, source).map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      final data = snap.data()!;
      data['id'] = snap.id;
      return _parseDeliveryEntity(data, source);
    });
  }

  @override
  Stream<DeliveryLocationEntity?> streamDriverLocation(String driverId) {
    return _remoteDatasource.streamDriverDoc(driverId).map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      final data = snap.data()!;
      final lat = (data['latitude'] ?? data['currentLat'] ?? data['lat'] as num?)?.toDouble();
      final lng = (data['longitude'] ?? data['currentLng'] ?? data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;
      final speed = (data['speed'] as num?)?.toDouble() ?? 0.0;
      final accuracy = (data['accuracy'] as num?)?.toDouble() ?? 0.0;
      final timestamp = (data['lastLocationUpdate'] as Timestamp?)?.toDate() ?? DateTime.now();

      return DeliveryLocationEntity(
        latitude: lat,
        longitude: lng,
        heading: heading,
        speed: speed,
        accuracy: accuracy,
        timestamp: timestamp,
      );
    });
  }

  @override
  Future<DeliveryExecutionEntity?> getDelivery(
    String orderId,
    OrderDeliverySource source,
  ) async {
    final data = await _remoteDatasource.fetchOrderData(orderId, source);
    if (data == null) return null;
    return _parseDeliveryEntity(data, source);
  }

  @override
  Future<bool> acceptDelivery({
    required String orderId,
    required OrderDeliverySource source,
    required DeliveryDriverInfo driverInfo,
  }) {
    return _remoteDatasource.acceptDelivery(
      orderId: orderId,
      source: source,
      driverInfo: driverInfo,
    );
  }

  @override
  Future<bool> updateDeliveryStatus({
    required String orderId,
    required OrderDeliverySource source,
    required DeliveryExecutionStatus newStatus,
    required String driverId,
    String cancelReason = '',
  }) {
    return _remoteDatasource.updateDeliveryStatus(
      orderId: orderId,
      source: source,
      newStatus: newStatus,
      driverId: driverId,
      cancelReason: cancelReason,
    );
  }

  @override
  Future<void> syncDriverLocation({
    required String driverId,
    required DeliveryLocationEntity location,
    String? activeOrderId,
    OrderDeliverySource? activeSource,
  }) {
    return _remoteDatasource.syncDriverLocation(
      driverId: driverId,
      location: location,
      activeOrderId: activeOrderId,
      activeSource: activeSource,
    );
  }

  @override
  Future<DeliveryRouteEntity> calculateRoute({
    required DeliveryLocationEntity start,
    required DeliveryPoint destination,
  }) {
    return _routeDatasource.calculateDrivingRoute(
      start: start,
      destination: destination,
    );
  }

  @override
  Future<bool> cancelDelivery({
    required String orderId,
    required OrderDeliverySource source,
    required String driverId,
    required String reason,
  }) {
    return _remoteDatasource.updateDeliveryStatus(
      orderId: orderId,
      source: source,
      newStatus: DeliveryExecutionStatus.cancelled,
      driverId: driverId,
      cancelReason: reason,
    );
  }

  /// تحويل وثائق Firestore المتنوعة إلى كيان نظيف وموحد (Schema Normalization)
  static DeliveryExecutionEntity _parseDeliveryEntity(
    Map<String, dynamic> data,
    OrderDeliverySource source,
  ) {
    final orderId = (data['id'] ?? data['orderId'] ?? data['requestId'] ?? '').toString();
    final statusStr = (data['status'] ?? 'pending').toString();
    final status = DeliveryExecutionStatus.fromString(statusStr);

    // 1. استخراج نقطة الاستلام (Pickup Point)
    double pickupLat = 0.0;
    double pickupLng = 0.0;
    String merchantName = '';
    String merchantAddress = '';
    String merchantPhone = '';
    String merchantId = '';

    if (source == OrderDeliverySource.restaurant) {
      merchantId = (data['restaurantId'] ?? data['restaurantDocId'] ?? data['restaurantOwnerId'] ?? '').toString();
      merchantName = (data['restaurantName'] ?? 'المطعم').toString();
      merchantAddress = (data['restaurantAddress'] ?? 'موقع المطعم').toString();
      merchantPhone = (data['restaurantPhone'] ?? '').toString();
      pickupLat = (data['restaurantLatitude'] ?? data['pickupLatitude'] as num?)?.toDouble() ?? 0.0;
      pickupLng = (data['restaurantLongitude'] ?? data['pickupLongitude'] as num?)?.toDouble() ?? 0.0;
    } else if (source == OrderDeliverySource.store) {
      merchantId = (data['storeId'] ?? '').toString();
      merchantName = (data['storeName'] ?? 'المتجر').toString();
      merchantAddress = (data['storeAddress'] ?? 'موقع المتجر').toString();
      merchantPhone = (data['storePhone'] ?? '').toString();
      pickupLat = (data['storeLatitude'] ?? data['pickupLatitude'] as num?)?.toDouble() ?? 0.0;
      pickupLng = (data['storeLongitude'] ?? data['pickupLongitude'] as num?)?.toDouble() ?? 0.0;
    } else {
      // Mersal / Parcel
      merchantId = (data['userId'] ?? '').toString();
      merchantName = (data['senderName'] ?? data['pickupName'] ?? 'نقطة الاستلام').toString();
      merchantAddress = (data['pickupAddress'] ?? data['fromAddress'] ?? 'موقع الاستلام').toString();
      merchantPhone = (data['senderPhone'] ?? data['pickupPhone'] ?? '').toString();
      pickupLat = (data['pickupLatitude'] ?? data['senderLatitude'] as num?)?.toDouble() ?? 0.0;
      pickupLng = (data['pickupLongitude'] ?? data['senderLongitude'] as num?)?.toDouble() ?? 0.0;
    }

    final pickupPoint = DeliveryPoint(
      latitude: pickupLat,
      longitude: pickupLng,
      name: merchantName,
      address: merchantAddress,
      phone: merchantPhone,
    );

    // 2. استخراج نقطة التسليم للزبون (Dropoff Point)
    final customerId = (data['customerId'] ?? data['userId'] ?? '').toString();
    final customerName = (data['customerName'] ?? data['receiverName'] ?? data['userName'] ?? 'زبون مدار').toString();
    final customerPhone = (data['customerPhone'] ?? data['receiverPhone'] ?? data['phone'] ?? '').toString();
    final deliveryAddress = (data['deliveryAddress'] ?? data['address'] ?? data['toAddress'] ?? 'عنوان التوصيل').toString();
    final dropoffLat = (data['latitude'] ?? data['deliveryLatitude'] ?? data['receiverLatitude'] as num?)?.toDouble() ?? 0.0;
    final dropoffLng = (data['longitude'] ?? data['deliveryLongitude'] ?? data['receiverLongitude'] as num?)?.toDouble() ?? 0.0;
    final instructions = (data['notes'] ?? data['specialInstructions'] ?? '').toString();

    final dropoffPoint = DeliveryPoint(
      latitude: dropoffLat,
      longitude: dropoffLng,
      name: customerName,
      address: deliveryAddress,
      phone: customerPhone,
      instructions: instructions,
    );

    // 3. استخراج العناصر (Items)
    final List<DeliveryOrderItem> items = [];
    if (data['items'] is List) {
      for (final it in (data['items'] as List)) {
        if (it is Map<String, dynamic>) {
          items.add(DeliveryOrderItem(
            id: (it['id'] ?? it['itemId'] ?? '').toString(),
            name: (it['name'] ?? '').toString(),
            quantity: (it['quantity'] as num? ?? 1).toInt(),
            price: (it['price'] as num? ?? 0.0).toDouble(),
            imageUrl: (it['imageUrl'] ?? it['image'] ?? '').toString(),
            notes: (it['notes'] ?? '').toString(),
          ));
        }
      }
    }

    // 4. استخراج الحسابات المالية
    final subtotal = (data['total'] ?? data['subtotal'] as num?)?.toDouble() ?? 0.0;
    final deliveryFee = (data['deliveryFee'] ?? data['deliveryPrice'] as num?)?.toDouble() ?? 1000.0;
    final discount = (data['discount'] as num?)?.toDouble() ?? 0.0;
    final grandTotal = (data['grandTotal'] as num?)?.toDouble() ?? (subtotal + deliveryFee - discount);
    final paymentMethod = (data['paymentMethod'] ?? data['paymentStatus'] ?? 'cash_on_delivery').toString();
    final isPaid = data['isPaid'] == true || paymentMethod == 'paid_wallet' || paymentMethod == 'card';

    // 5. استخراج بيانات الكابتن إذا كان معيناً
    DeliveryDriverInfo? driverInfo;
    final driverId = data['driverId']?.toString();
    if (driverId != null && driverId.isNotEmpty) {
      driverInfo = DeliveryDriverInfo(
        id: driverId,
        name: (data['driverName'] ?? 'كابتن مدار').toString(),
        phone: (data['driverPhone'] ?? '').toString(),
        imageUrl: (data['driverImage'] ?? '').toString(),
        vehicleType: (data['driverVehicleType'] ?? 'دراجة نارية').toString(),
        vehiclePlate: (data['driverVehiclePlate'] ?? '').toString(),
        rating: (data['driverRating'] as num?)?.toDouble() ?? 5.0,
      );
    }

    // 6. التواريخ
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return DeliveryExecutionEntity(
      orderId: orderId,
      source: source,
      merchantId: merchantId,
      merchantName: merchantName,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      status: status,
      pickupPoint: pickupPoint,
      dropoffPoint: dropoffPoint,
      items: items,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      discount: discount,
      grandTotal: grandTotal,
      paymentMethod: paymentMethod,
      isPaid: isPaid,
      driverInfo: driverInfo,
      createdAt: parseDate(data['createdAt']),
      acceptedAt: parseDate(data['acceptedAt']),
      pickedUpAt: parseDate(data['pickedUpAt']),
      deliveredAt: parseDate(data['deliveredAt'] ?? data['completedAt']),
      cancelledAt: parseDate(data['cancelledAt']),
      cancelReason: (data['cancelReason'] ?? '').toString(),
      notes: instructions,
      voiceUrl: data['voiceUrl']?.toString(),
    );
  }
}
