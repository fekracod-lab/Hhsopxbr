import 'package:flutter/foundation.dart';
import '../enums/order_enums.dart';
import 'order_item.dart';
import 'order_pricing.dart';

/// كيان الطلب الموحد في منظومة مدار (Unified Order Entity)
@immutable
class UnifiedOrder {
  final String orderId;
  final OrderType orderType;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double deliveryLatitude;
  final double deliveryLongitude;
  final String? merchantId;
  final String? merchantName;
  final String? driverId;
  final String? driverName;
  final UnifiedOrderStatus status;
  final OrderPaymentMethod paymentMethod;
  final bool isPaid;
  final List<OrderItem> items;
  final OrderPricing pricing;
  final String idempotencyKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  const UnifiedOrder({
    required this.orderId,
    required this.orderType,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.deliveryLatitude = 0.0,
    this.deliveryLongitude = 0.0,
    this.merchantId,
    this.merchantName,
    this.driverId,
    this.driverName,
    this.status = UnifiedOrderStatus.pending,
    this.paymentMethod = OrderPaymentMethod.cash,
    this.isPaid = false,
    required this.items,
    required this.pricing,
    required this.idempotencyKey,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  /// إجمالي عدد القطع في الطلب
  int get totalItemsCount => items.fold<int>(0, (sum, it) => sum + it.quantity);

  UnifiedOrder copyWith({
    String? orderId,
    OrderType? orderType,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? merchantId,
    String? merchantName,
    String? driverId,
    String? driverName,
    UnifiedOrderStatus? status,
    OrderPaymentMethod? paymentMethod,
    bool? isPaid,
    List<OrderItem>? items,
    OrderPricing? pricing,
    String? idempotencyKey,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return UnifiedOrder(
      orderId: orderId ?? this.orderId,
      orderType: orderType ?? this.orderType,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      merchantId: merchantId ?? this.merchantId,
      merchantName: merchantName ?? this.merchantName,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
      items: items ?? this.items,
      pricing: pricing ?? this.pricing,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'orderType': orderType.key,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'merchantId': merchantId,
      'merchantName': merchantName,
      'driverId': driverId,
      'driverName': driverName,
      'status': status.key,
      'paymentMethod': paymentMethod.key,
      'isPaid': isPaid,
      'items': items.map((e) => e.toMap()).toList(),
      'pricing': pricing.toMap(),
      'idempotencyKey': idempotencyKey,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory UnifiedOrder.fromMap(Map<String, dynamic> map, String docId) {
    final rawItems = map['items'] as List? ?? [];
    final items = rawItems
        .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    final pricingData = map['pricing'] is Map
        ? Map<String, dynamic>.from(map['pricing'] as Map)
        : map;

    return UnifiedOrder(
      orderId: docId,
      orderType: OrderType.fromString(map['orderType']?.toString()),
      customerId: map['customerId']?.toString() ?? map['userId']?.toString() ?? map['ownerId']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? map['fullName']?.toString() ?? '',
      customerPhone: map['customerPhone']?.toString() ?? map['phone']?.toString() ?? '',
      deliveryAddress: map['deliveryAddress']?.toString() ?? map['address']?.toString() ?? '',
      deliveryLatitude: (map['deliveryLatitude'] as num?)?.toDouble() ?? (map['latitude'] as num?)?.toDouble() ?? 0.0,
      deliveryLongitude: (map['deliveryLongitude'] as num?)?.toDouble() ?? (map['longitude'] as num?)?.toDouble() ?? 0.0,
      merchantId: map['merchantId']?.toString() ?? map['restaurantId']?.toString() ?? map['storeId']?.toString(),
      merchantName: map['merchantName']?.toString() ?? map['restaurantName']?.toString() ?? map['storeName']?.toString(),
      driverId: map['driverId']?.toString(),
      driverName: map['driverName']?.toString(),
      status: UnifiedOrderStatus.fromString(map['status']?.toString()),
      paymentMethod: OrderPaymentMethod.fromString(map['paymentMethod']?.toString() ?? map['paymentStatus']?.toString()),
      isPaid: map['isPaid'] == true || map['paymentStatus'] == 'paid_wallet' || map['paymentStatus'] == 'paid_online',
      items: items,
      pricing: OrderPricing.fromMap(pricingData),
      idempotencyKey: map['idempotencyKey']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      metadata: map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata'] as Map) : {},
    );
  }
}
