// نموذج بيانات أمر المرتجع للتخزين والـ Firestore (MADAR SHOP Return Order Model)
// Pure Dart — Zero UI Dependencies

import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/returns/entities/return_order.dart';
import '../../../domain/returns/enums/return_order_status.dart';
import '../../../domain/returns/enums/return_type.dart';
import 'return_item_model.dart';

class ReturnOrderModel {
  const ReturnOrderModel._();

  static Map<String, dynamic> toMap(ReturnOrder order) {
    return {
      'id': order.id,
      'businessId': order.businessId,
      'branchId': order.branchId,
      'originalSaleId': order.originalSaleId,
      'returnNumber': order.returnNumber,
      'type': order.type.name,
      'status': order.status.name,
      'items': order.items.map(ReturnItemModel.toMap).toList(),
      'currency': order.currency.code,
      'customerId': order.customerId,
      'customerName': order.customerName,
      'createdBy': order.createdBy,
      'approvedBy': order.approvedBy,
      'receivedBy': order.receivedBy,
      'refundedBy': order.refundedBy,
      'closedBy': order.closedBy,
      'createdAt': order.createdAt.toIso8601String(),
      'updatedAt': order.updatedAt.toIso8601String(),
      'version': order.version,
      'idempotencyKey': order.idempotencyKey,
      'metadata': order.metadata,
    };
  }

  static ReturnOrder fromMap(Map<String, dynamic> map) {
    final currency = Currency.fromCode(map['currency'] as String?);
    final itemsRaw = map['items'] as List<dynamic>? ?? const [];
    final items = itemsRaw
        .map((it) => ReturnItemModel.fromMap(it as Map<String, dynamic>, currency))
        .toList();

    return ReturnOrder(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      branchId: map['branchId'] as String,
      originalSaleId: map['originalSaleId'] as String,
      returnNumber: map['returnNumber'] as String,
      type: ReturnType.fromString(map['type'] as String?),
      status: ReturnOrderStatus.fromString(map['status'] as String?),
      items: items,
      currency: currency,
      customerId: map['customerId'] as String?,
      customerName: map['customerName'] as String?,
      createdBy: map['createdBy'] as String,
      approvedBy: map['approvedBy'] as String?,
      receivedBy: map['receivedBy'] as String?,
      refundedBy: map['refundedBy'] as String?,
      closedBy: map['closedBy'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      version: map['version'] as int? ?? 1,
      idempotencyKey: map['idempotencyKey'] as String? ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? const {}),
    );
  }
}
