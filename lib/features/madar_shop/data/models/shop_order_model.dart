// نموذج تسلسل بيانات الطلبات (MADAR SHOP Order DTO)
// Data Layer — Serialization / Deserialization

import '../../domain/orders/entities/shop_order.dart';
import '../../domain/orders/entities/shop_order_item.dart';
import '../../domain/orders/entities/shop_order_status.dart';

class ShopOrderModel extends ShopOrder {
  const ShopOrderModel({
    required super.orderId,
    required super.orderNumber,
    required super.businessId,
    required super.branchId,
    super.source,
    super.channel,
    super.fulfillment,
    required super.status,
    super.version,
    super.idempotencyKey,
    required super.customerName,
    required super.customerPhone,
    super.deliveryAddress,
    required super.items,
    super.cartDiscountAmount,
    super.deliveryFee,
    super.taxAmount,
    super.isPaid,
    super.paymentMethod,
    super.cashierUserId,
    super.driverId,
    super.cancelOrRejectReason,
    super.internalNotes,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ShopOrderModel.fromJson(Map<String, dynamic> json, {String? id}) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    double parseDouble(dynamic val, [double defaultVal = 0.0]) {
      if (val == null) return defaultVal;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? defaultVal;
    }

    int parseInt(dynamic val, [int defaultVal = 1]) {
      if (val == null) return defaultVal;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? defaultVal;
    }

    List<ShopOrderItem> parseItems(dynamic list) {
      if (list is! List) return const [];
      return list.map((item) {
        if (item is! Map<String, dynamic>) return null;
        return ShopOrderItem(
          itemId: (item['itemId'] ?? item['id'] ?? '').toString(),
          productId: (item['productId'] ?? '').toString(),
          variantId: item['variantId']?.toString(),
          productName: (item['productName'] ?? item['name'] ?? item['title'] ?? '').toString(),
          sku: (item['sku'] ?? '').toString(),
          barcode: item['barcode']?.toString(),
          unitPrice: parseDouble(item['unitPrice'] ?? item['price']),
          unitCostPrice: parseDouble(item['unitCostPrice'] ?? item['costPrice']),
          quantity: parseDouble(item['quantity'], 1.0),
          discountAmount: parseDouble(item['discountAmount']),
          notes: item['notes']?.toString(),
        );
      }).whereType<ShopOrderItem>().toList();
    }

    final oId = id ?? (json['orderId'] ?? json['id'] ?? '').toString();

    return ShopOrderModel(
      orderId: oId,
      orderNumber: (json['orderNumber'] ?? json['orderNum'] ?? 'ORD-$oId').toString(),
      businessId: (json['businessId'] ?? json['storeId'] ?? '').toString(),
      branchId: (json['branchId'] ?? json['storeId'] ?? '').toString(),
      source: ShopOrderSource.fromString(json['source']?.toString()),
      channel: ShopOrderChannel.fromString(json['channel']?.toString()),
      fulfillment: ShopOrderFulfillment.fromString(json['fulfillment']?.toString()),
      status: ShopOrderStatus.fromString(json['status']?.toString()),
      version: parseInt(json['version'], 1),
      idempotencyKey: json['idempotencyKey']?.toString(),
      customerName: (json['customerName'] ?? json['userName'] ?? 'عميل').toString(),
      customerPhone: (json['customerPhone'] ?? json['userPhone'] ?? '').toString(),
      deliveryAddress: json['deliveryAddress']?.toString() ?? json['address']?.toString(),
      items: parseItems(json['items']),
      cartDiscountAmount: parseDouble(json['cartDiscountAmount'] ?? json['discount']),
      deliveryFee: parseDouble(json['deliveryFee']),
      taxAmount: parseDouble(json['taxAmount'] ?? json['tax']),
      isPaid: json['isPaid'] == true,
      paymentMethod: (json['paymentMethod'] ?? 'cash').toString(),
      cashierUserId: json['cashierUserId']?.toString(),
      driverId: json['driverId']?.toString(),
      cancelOrRejectReason: json['cancelOrRejectReason']?.toString() ?? json['cancelReason']?.toString(),
      internalNotes: json['internalNotes']?.toString(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'orderNumber': orderNumber,
      'businessId': businessId,
      'branchId': branchId,
      'source': source.toDbString(),
      'channel': channel.toDbString(),
      'fulfillment': fulfillment.toDbString(),
      'status': status.toDbString(),
      'version': version,
      'idempotencyKey': idempotencyKey,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'items': items
          .map((item) => {
                'itemId': item.itemId,
                'productId': item.productId,
                'variantId': item.variantId,
                'productName': item.productName,
                'sku': item.sku,
                'barcode': item.barcode,
                'unitPrice': item.unitPrice,
                'unitCostPrice': item.unitCostPrice,
                'quantity': item.quantity,
                'discountAmount': item.discountAmount,
                'notes': item.notes,
              })
          .toList(),
      'cartDiscountAmount': cartDiscountAmount,
      'deliveryFee': deliveryFee,
      'taxAmount': taxAmount,
      'grandTotal': grandTotal,
      'isPaid': isPaid,
      'paymentMethod': paymentMethod,
      'cashierUserId': cashierUserId,
      'driverId': driverId,
      'cancelOrRejectReason': cancelOrRejectReason,
      'internalNotes': internalNotes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
