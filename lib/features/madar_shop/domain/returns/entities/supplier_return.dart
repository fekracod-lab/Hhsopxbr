// الكيان الكلي لأمر إرجاع بضاعة إلى المورد (MADAR SHOP Supplier Return Aggregate)
// Pure Dart — Zero UI Dependencies

import '../../pos/value_objects/currency.dart';
import '../../pos/value_objects/money.dart';
import '../enums/supplier_return_status.dart';
import 'supplier_return_item.dart';

class SupplierReturn {
  final String id;
  final String businessId;
  final String branchId;
  final String supplierId;
  final String originalPurchaseId;
  final String originalReceiptId;
  final String returnNumber;
  final SupplierReturnStatus status;
  final List<SupplierReturnItem> items;
  final Currency currency;
  final String reason;
  final String actorId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final String idempotencyKey;
  final Map<String, dynamic> metadata;

  const SupplierReturn({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.supplierId,
    required this.originalPurchaseId,
    required this.originalReceiptId,
    required this.returnNumber,
    required this.status,
    required this.items,
    this.currency = Currency.iqd,
    required this.reason,
    required this.actorId,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    required this.idempotencyKey,
    this.metadata = const {},
  });

  /// إجمالي قيمة المرتجع للمورد
  Money get totalAmount {
    if (items.isEmpty) return Money.zero(currency);
    return items.fold(Money.zero(currency), (sum, it) => sum + it.lineTotal);
  }

  SupplierReturn copyWith({
    String? id,
    String? businessId,
    String? branchId,
    String? supplierId,
    String? originalPurchaseId,
    String? originalReceiptId,
    String? returnNumber,
    SupplierReturnStatus? status,
    List<SupplierReturnItem>? items,
    Currency? currency,
    String? reason,
    String? actorId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    String? idempotencyKey,
    Map<String, dynamic>? metadata,
  }) {
    return SupplierReturn(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      supplierId: supplierId ?? this.supplierId,
      originalPurchaseId: originalPurchaseId ?? this.originalPurchaseId,
      originalReceiptId: originalReceiptId ?? this.originalReceiptId,
      returnNumber: returnNumber ?? this.returnNumber,
      status: status ?? this.status,
      items: items ?? this.items,
      currency: currency ?? this.currency,
      reason: reason ?? this.reason,
      actorId: actorId ?? this.actorId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      metadata: metadata ?? this.metadata,
    );
  }
}
