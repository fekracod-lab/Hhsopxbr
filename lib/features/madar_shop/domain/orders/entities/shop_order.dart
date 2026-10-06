// كيان الطلب المركزي متعدد الأبعاد لمتجر مدار (MADAR SHOP Core Order Entity)
// Pure Dart — Zero UI Dependencies

import 'shop_order_item.dart';
import 'shop_order_status.dart';

class ShopOrder {
  final String orderId;
  final String orderNumber;
  final String businessId;
  final String branchId;
  final ShopOrderSource source;
  final ShopOrderChannel channel;
  final ShopOrderFulfillment fulfillment;
  final ShopOrderStatus status;
  final int version; // للتحكم في التزامن المتفائل ومنع تضارب التعديلات
  final String? idempotencyKey; // لمنع تكرار معالجة الطلبات
  final String customerName;
  final String customerPhone;
  final String? deliveryAddress;
  final List<ShopOrderItem> items;
  final double cartDiscountAmount;
  final double deliveryFee;
  final double taxAmount;
  final bool isPaid;
  final String paymentMethod; // e.g. "cash", "pos_card", "zain_cash"
  final String? cashierUserId;
  final String? driverId;
  final String? cancelOrRejectReason;
  final String? internalNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShopOrder({
    required this.orderId,
    required this.orderNumber,
    required this.businessId,
    required this.branchId,
    this.source = ShopOrderSource.pos,
    this.channel = ShopOrderChannel.desktopPos,
    this.fulfillment = ShopOrderFulfillment.inStorePickup,
    required this.status,
    this.version = 1,
    this.idempotencyKey,
    required this.customerName,
    required this.customerPhone,
    this.deliveryAddress,
    required this.items,
    this.cartDiscountAmount = 0.0,
    this.deliveryFee = 0.0,
    this.taxAmount = 0.0,
    this.isPaid = false,
    this.paymentMethod = 'cash',
    this.cashierUserId,
    this.driverId,
    this.cancelOrRejectReason,
    this.internalNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// المجموع الفرعي لكافة بنود الطلب
  double get itemsSubtotal =>
      items.fold(0.0, (acc, item) => acc + item.lineTotal);

  /// إجمالي قيمة الفاتورة النهائية بعد الخصم وإضافة التوصيل والضريبة
  double get grandTotal {
    final net = itemsSubtotal - cartDiscountAmount + deliveryFee + taxAmount;
    return net > 0 ? net : 0.0;
  }

  /// إجمالي التكلفة الحقيقية لبضائع الطلب
  double get totalOrderCost =>
      items.fold(0.0, (acc, item) => acc + item.totalCost);

  /// صافي الربح المحقق من الطلب
  double get netProfit =>
      (itemsSubtotal - cartDiscountAmount) - totalOrderCost;

  /// إجمالي عدد القطع في الطلب
  double get totalUnitsCount =>
      items.fold(0.0, (acc, item) => acc + item.quantity);

  ShopOrder copyWith({
    String? orderId,
    String? orderNumber,
    String? businessId,
    String? branchId,
    ShopOrderSource? source,
    ShopOrderChannel? channel,
    ShopOrderFulfillment? fulfillment,
    ShopOrderStatus? status,
    int? version,
    String? idempotencyKey,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    List<ShopOrderItem>? items,
    double? cartDiscountAmount,
    double? deliveryFee,
    double? taxAmount,
    bool? isPaid,
    String? paymentMethod,
    String? cashierUserId,
    String? driverId,
    String? cancelOrRejectReason,
    String? internalNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopOrder(
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      source: source ?? this.source,
      channel: channel ?? this.channel,
      fulfillment: fulfillment ?? this.fulfillment,
      status: status ?? this.status,
      version: version ?? this.version,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      items: items ?? this.items,
      cartDiscountAmount: cartDiscountAmount ?? this.cartDiscountAmount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      taxAmount: taxAmount ?? this.taxAmount,
      isPaid: isPaid ?? this.isPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cashierUserId: cashierUserId ?? this.cashierUserId,
      driverId: driverId ?? this.driverId,
      cancelOrRejectReason: cancelOrRejectReason ?? this.cancelOrRejectReason,
      internalNotes: internalNotes ?? this.internalNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
