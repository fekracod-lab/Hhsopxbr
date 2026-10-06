// الكيان الكلي لمعاملة البيع المكتملة في نقطة البيع (MADAR SHOP POS Sale Aggregate)
// Pure Dart — Zero UI Dependencies

import '../enums/sale_status.dart';
import '../value_objects/currency.dart';
import '../value_objects/money.dart';
import 'payment.dart';
import 'sale_item.dart';

class Sale {
  final String id;
  final String businessId;
  final String branchId;
  final String terminalId;
  final String sessionId;
  final String cashierId;
  final String cashierName;
  final String saleNumber;
  final String source; // e.g. "POS_WINDOWS", "POS_ANDROID"
  final SaleStatus status;
  final List<SaleItem> items;
  final Money subtotal;
  final Money discountTotal;
  final Money taxTotal;
  final Money grandTotal;
  final Money paidTotal;
  final Money remainingTotal;
  final Money changeTotal;
  final String? customerId;
  final String? customerName;
  final List<Payment> payments;
  final Currency currency;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final int version;
  final String idempotencyKey;
  final Map<String, dynamic> metadata;

  const Sale({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.terminalId,
    required this.sessionId,
    required this.cashierId,
    required this.cashierName,
    required this.saleNumber,
    this.source = 'POS_DESKTOP',
    required this.status,
    required this.items,
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.paidTotal,
    required this.remainingTotal,
    required this.changeTotal,
    this.customerId,
    this.customerName,
    required this.payments,
    this.currency = Currency.iqd,
    required this.createdAt,
    this.completedAt,
    this.cancelledAt,
    this.version = 1,
    required this.idempotencyKey,
    this.metadata = const {},
  });

  /// إجمالي التكلفة التقديرية للبضاعة المباعة
  Money get totalCost {
    if (items.isEmpty) return Money.zero(currency);
    return items.fold(Money.zero(currency), (sum, it) => sum + it.totalCost);
  }

  /// صافي الربح الإجمالي المحقق من الفاتورة
  Money get netGrossProfit {
    final netSales = grandTotal - taxTotal;
    return netSales - totalCost;
  }

  /// إجمالي عدد القطع المباعة
  double get totalUnitsCount {
    return items.fold(0.0, (sum, it) => sum + it.quantity);
  }

  Sale copyWith({
    String? id,
    String? businessId,
    String? branchId,
    String? terminalId,
    String? sessionId,
    String? cashierId,
    String? cashierName,
    String? saleNumber,
    String? source,
    SaleStatus? status,
    List<SaleItem>? items,
    Money? subtotal,
    Money? discountTotal,
    Money? taxTotal,
    Money? grandTotal,
    Money? paidTotal,
    Money? remainingTotal,
    Money? changeTotal,
    String? customerId,
    String? customerName,
    List<Payment>? payments,
    Currency? currency,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    int? version,
    String? idempotencyKey,
    Map<String, dynamic>? metadata,
  }) {
    return Sale(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      terminalId: terminalId ?? this.terminalId,
      sessionId: sessionId ?? this.sessionId,
      cashierId: cashierId ?? this.cashierId,
      cashierName: cashierName ?? this.cashierName,
      saleNumber: saleNumber ?? this.saleNumber,
      source: source ?? this.source,
      status: status ?? this.status,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountTotal: discountTotal ?? this.discountTotal,
      taxTotal: taxTotal ?? this.taxTotal,
      grandTotal: grandTotal ?? this.grandTotal,
      paidTotal: paidTotal ?? this.paidTotal,
      remainingTotal: remainingTotal ?? this.remainingTotal,
      changeTotal: changeTotal ?? this.changeTotal,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      payments: payments ?? this.payments,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      version: version ?? this.version,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      metadata: metadata ?? this.metadata,
    );
  }
}
