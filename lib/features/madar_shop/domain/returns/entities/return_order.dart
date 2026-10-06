// الكيان الكلي لأمر المرتجع للزبون (MADAR SHOP Customer Return Order Aggregate)
// Pure Dart — Zero UI Dependencies

import '../../pos/value_objects/currency.dart';
import '../../pos/value_objects/money.dart';
import '../enums/return_order_status.dart';
import '../enums/return_type.dart';
import 'return_item.dart';

class ReturnOrder {
  final String id;
  final String businessId;
  final String branchId;
  final String originalSaleId;
  final String returnNumber;
  final ReturnType type;
  final ReturnOrderStatus status;
  final List<ReturnItem> items;
  final Currency currency;
  final String? customerId;
  final String? customerName;
  final String createdBy;
  final String? approvedBy;
  final String? receivedBy;
  final String? refundedBy;
  final String? closedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final String idempotencyKey;
  final Map<String, dynamic> metadata;

  const ReturnOrder({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.originalSaleId,
    required this.returnNumber,
    required this.type,
    required this.status,
    required this.items,
    this.currency = Currency.iqd,
    this.customerId,
    this.customerName,
    required this.createdBy,
    this.approvedBy,
    this.receivedBy,
    this.refundedBy,
    this.closedBy,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    required this.idempotencyKey,
    this.metadata = const {},
  });

  /// إجمالي المبالغ المستردة قبل الخصومات والضرائب
  Money get subtotalRefund {
    if (items.isEmpty) return Money.zero(currency);
    return items.fold(
      Money.zero(currency),
      (sum, item) => sum + (item.unitRefundPrice * item.quantity.toDouble()),
    );
  }

  /// إجمالي الخصومات المقتطعة من المرتجع
  Money get discountDeductionTotal {
    if (items.isEmpty) return Money.zero(currency);
    return items.fold(
      Money.zero(currency),
      (sum, item) => sum + (item.unitDiscountDeduction * item.quantity.toDouble()),
    );
  }

  /// إجمالي الضرائب المستردة
  Money get taxRefundTotal {
    if (items.isEmpty) return Money.zero(currency);
    return items.fold(
      Money.zero(currency),
      (sum, item) => sum + (item.unitTaxRefund * item.quantity.toDouble()),
    );
  }

  /// الصافي النهائي للمبلغ المسترد للزبون
  Money get grandTotalRefund {
    if (items.isEmpty) return Money.zero(currency);
    return items.fold(
      Money.zero(currency),
      (sum, item) => sum + item.lineRefundTotal,
    );
  }

  /// إجمالي تكلفة البضاعة المباعة المعكوسة (Reversible COGS) للأصناف الصالحة لإعادة التخزين
  Money get totalReversibleCogs {
    if (items.isEmpty) return Money.zero(currency);
    return items.fold(
      Money.zero(currency),
      (sum, item) {
        if (!item.isRestockable) return sum;
        return sum + item.totalCostBasis;
      },
    );
  }

  /// إجمالي الخسارة الناتجة عن الأصناف التالفة / منتهية الصلاحية
  Money get damagedOrExpiredLoss {
    if (items.isEmpty) return Money.zero(currency);
    return items.fold(
      Money.zero(currency),
      (sum, item) {
        if (item.isRestockable) return sum;
        return sum + item.totalCostBasis;
      },
    );
  }

  ReturnOrder copyWith({
    String? id,
    String? businessId,
    String? branchId,
    String? originalSaleId,
    String? returnNumber,
    ReturnType? type,
    ReturnOrderStatus? status,
    List<ReturnItem>? items,
    Currency? currency,
    String? customerId,
    String? customerName,
    String? createdBy,
    String? approvedBy,
    String? receivedBy,
    String? refundedBy,
    String? closedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    String? idempotencyKey,
    Map<String, dynamic>? metadata,
  }) {
    return ReturnOrder(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      originalSaleId: originalSaleId ?? this.originalSaleId,
      returnNumber: returnNumber ?? this.returnNumber,
      type: type ?? this.type,
      status: status ?? this.status,
      items: items ?? this.items,
      currency: currency ?? this.currency,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      createdBy: createdBy ?? this.createdBy,
      approvedBy: approvedBy ?? this.approvedBy,
      receivedBy: receivedBy ?? this.receivedBy,
      refundedBy: refundedBy ?? this.refundedBy,
      closedBy: closedBy ?? this.closedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      metadata: metadata ?? this.metadata,
    );
  }
}
