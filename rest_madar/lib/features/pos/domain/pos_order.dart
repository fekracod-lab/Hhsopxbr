import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pos_cart_item.dart';

/// نموذج طلب الكاشير ونقطة البيع المرتبط بمنظومة مدار
class PosOrder {
  final String orderId;
  final String restaurantId;
  final String orderType; // 'dine_in', 'takeaway', 'delivery'
  final String? tableNumber;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final List<PosCartItem> items;
  final double subtotal;
  final double discountAmount;
  final double taxOrService;
  final double totalAmount;
  final String paymentMethod; // 'cash', 'card', 'zain_cash', 'debit'
  final double amountPaid;
  final double changeAmount;
  final String status;
  final DateTime createdAt;
  final String cashierName;
  final String? notes;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverImage;
  final String? deliveryStatus;
  final double deliveryFee;
  final String? cancellationReason;
  final DateTime? acceptedAt;
  final DateTime? preparingAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? updatedAt;

  PosOrder({
    required this.orderId,
    required this.restaurantId,
    required this.orderType,
    this.tableNumber,
    this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    required this.items,
    required this.subtotal,
    this.discountAmount = 0.0,
    this.taxOrService = 0.0,
    required this.totalAmount,
    this.paymentMethod = 'cash',
    this.amountPaid = 0.0,
    this.changeAmount = 0.0,
    this.status = 'completed',
    required this.createdAt,
    this.cashierName = 'كاشير رئيسي',
    this.notes,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverImage,
    this.deliveryStatus,
    this.deliveryFee = 0.0,
    this.cancellationReason,
    this.acceptedAt,
    this.preparingAt,
    this.readyAt,
    this.completedAt,
    this.cancelledAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'restaurantId': restaurantId,
      'orderType': orderType,
      'tableNumber': tableNumber,
      'customerName': customerName ?? 'زبون مباشر',
      'customerPhone': customerPhone ?? '',
      'deliveryAddress': deliveryAddress ?? '',
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'total': totalAmount,
      'totalAmount': totalAmount,
      'totalPrice': totalAmount,
      'discountAmount': discountAmount,
      'taxOrService': taxOrService,
      'deliveryFee': deliveryFee,
      'paymentMethod': paymentMethod,
      'amountPaid': amountPaid,
      'changeAmount': changeAmount,
      'paymentStatus': 'paid',
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'cashierName': cashierName,
      'notes': notes,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverImage': driverImage,
      'deliveryStatus': deliveryStatus,
      'source': 'pos_windows',
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      if (acceptedAt != null) 'acceptedAt': Timestamp.fromDate(acceptedAt!),
      if (preparingAt != null) 'preparingAt': Timestamp.fromDate(preparingAt!),
      if (readyAt != null) 'readyAt': Timestamp.fromDate(readyAt!),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (cancelledAt != null) 'cancelledAt': Timestamp.fromDate(cancelledAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  factory PosOrder.fromMap(Map<String, dynamic> map, String id) {
    DateTime date = DateTime.now();
    final rawDate = map['createdAt'] ?? map['date'] ?? map['timestamp'] ?? map['orderDate'];
    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is DateTime) {
      date = rawDate;
    } else if (rawDate is String) {
      date = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is int) {
      date = DateTime.fromMillisecondsSinceEpoch(rawDate);
    }

    final rawItems = map['items'] as List<dynamic>? ?? [];
    final List<PosCartItem> itemsList = [];
    for (final it in rawItems) {
      if (it is Map) {
        itemsList.add(PosCartItem.fromMap(Map<String, dynamic>.from(it)));
      }
    }

    double parseNum(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    final total = parseNum(map['totalAmount'] ?? map['total'] ?? map['totalPrice'] ?? map['grandTotal']);
    final subtotal = parseNum(map['subtotal'] ?? map['subTotal'] ?? total);
    final discount = parseNum(map['discountAmount'] ?? map['discount']);
    final tax = parseNum(map['taxOrService'] ?? map['tax'] ?? map['serviceFee']);
    final paid = parseNum(map['amountPaid'] ?? map['paidAmount'] ?? total);
    final change = parseNum(map['changeAmount'] ?? map['change']);
    final delivery = parseNum(map['deliveryFee'] ?? map['deliveryCost'] ?? map['deliveryPrice']);

    return PosOrder(
      orderId: id,
      restaurantId: (map['restaurantId'] ?? map['storeId'] ?? '').toString(),
      orderType: (map['orderType'] ?? map['type'] ?? 'takeaway').toString(),
      tableNumber: map['tableNumber']?.toString() ?? map['table']?.toString(),
      customerName: map['customerName']?.toString() ?? map['buyerName']?.toString() ?? map['userName']?.toString(),
      customerPhone: map['customerPhone']?.toString() ?? map['buyerPhone']?.toString() ?? map['phone']?.toString(),
      deliveryAddress: map['deliveryAddress']?.toString() ?? map['address']?.toString(),
      items: itemsList,
      subtotal: subtotal,
      discountAmount: discount,
      taxOrService: tax,
      totalAmount: total,
      paymentMethod: (map['paymentMethod'] ?? map['paymentType'] ?? 'cash').toString(),
      amountPaid: paid,
      changeAmount: change,
      status: (map['status'] ?? 'completed').toString(),
      createdAt: date,
      cashierName: (map['cashierName'] ?? 'كاشير رئيسي').toString(),
      notes: map['notes']?.toString() ?? map['note']?.toString() ?? map['customerNotes']?.toString(),
      driverId: map['driverId']?.toString(),
      driverName: map['driverName']?.toString() ?? map['captainName']?.toString(),
      driverPhone: map['driverPhone']?.toString() ?? map['captainPhone']?.toString(),
      driverImage: map['driverImage']?.toString() ?? map['captainImage']?.toString(),
      deliveryStatus: map['deliveryStatus']?.toString(),
      deliveryFee: delivery,
      cancellationReason: map['cancellationReason']?.toString() ?? map['cancelReason']?.toString(),
      acceptedAt: map['acceptedAt'] != null ? parseDate(map['acceptedAt']) : null,
      preparingAt: map['preparingAt'] != null ? parseDate(map['preparingAt']) : null,
      readyAt: map['readyAt'] != null ? parseDate(map['readyAt']) : null,
      completedAt: map['completedAt'] != null ? parseDate(map['completedAt']) : null,
      cancelledAt: map['cancelledAt'] != null ? parseDate(map['cancelledAt']) : null,
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }

  static DateTime parseDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    final s = raw.toString().trim();
    final parsed = DateTime.tryParse(s);
    if (parsed != null) return parsed;
    if (s.startsWith('Timestamp(')) {
      final match = RegExp(r'seconds=(\d+)').firstMatch(s);
      if (match != null) {
        final sec = int.tryParse(match.group(1)!);
        if (sec != null) return DateTime.fromMillisecondsSinceEpoch(sec * 1000);
      }
    }
    return DateTime.now();
  }

  factory PosOrder.fromSqlite(Map<String, dynamic> row) {
    List<PosCartItem> items = [];
    try {
      final raw = row['items_json'] as String? ?? '[]';
      final decoded = jsonDecode(raw) as List<dynamic>? ?? [];
      for (final it in decoded) {
        if (it is Map) {
          items.add(PosCartItem.fromMap(Map<String, dynamic>.from(it)));
        }
      }
    } catch (_) {}

    double parseNum(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    final id = (row['local_id'] ?? row['remote_id'] ?? '').toString();
    final total = parseNum(row['total_amount']);

    return PosOrder(
      orderId: id,
      restaurantId: (row['restaurant_id'] ?? '').toString(),
      orderType: (row['order_type'] ?? 'takeaway').toString(),
      tableNumber: row['table_number']?.toString(),
      customerName: row['customer_name']?.toString() ?? 'زبون مباشر',
      customerPhone: row['customer_phone']?.toString(),
      deliveryAddress: row['delivery_address']?.toString(),
      items: items,
      subtotal: parseNum(row['subtotal']),
      discountAmount: parseNum(row['discount_amount']),
      taxOrService: parseNum(row['tax_or_service']),
      totalAmount: total,
      paymentMethod: (row['payment_method'] ?? 'cash').toString(),
      amountPaid: parseNum(row['amount_paid']),
      changeAmount: parseNum(row['change_amount']),
      status: (row['status'] ?? 'completed').toString(),
      createdAt: parseDate(row['created_at']),
      cashierName: (row['cashier_name'] ?? 'كاشير رئيسي').toString(),
      cancellationReason: row['cancellation_reason']?.toString(),
      acceptedAt: row['accepted_at'] != null ? parseDate(row['accepted_at']) : null,
      preparingAt: row['preparing_at'] != null ? parseDate(row['preparing_at']) : null,
      readyAt: row['ready_at'] != null ? parseDate(row['ready_at']) : null,
      completedAt: row['completed_at'] != null ? parseDate(row['completed_at']) : null,
      cancelledAt: row['cancelled_at'] != null ? parseDate(row['cancelled_at']) : null,
      updatedAt: row['updated_at'] != null ? parseDate(row['updated_at']) : null,
    );
  }
}
