// نموذج بيانات مرتجع المشتريات للمورد للتخزين (MADAR SHOP Supplier Return Model)
// Pure Dart — Zero UI Dependencies

import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/returns/entities/supplier_return.dart';
import '../../../domain/returns/entities/supplier_return_item.dart';
import '../../../domain/returns/enums/supplier_return_status.dart';

class SupplierReturnItemModel {
  const SupplierReturnItemModel._();

  static Map<String, dynamic> toMap(SupplierReturnItem item) {
    return {
      'id': item.id,
      'purchaseReceiptItemId': item.purchaseReceiptItemId,
      'productId': item.productId,
      'variantId': item.variantId,
      'quantityMilli': item.quantity.milliUnits,
      'unit': item.quantity.unit.name,
      'unitCostUnits': item.unitCost.minorUnits,
      'currency': item.unitCost.currency.code,
      'reason': item.reason,
    };
  }

  static SupplierReturnItem fromMap(Map<String, dynamic> map, [Currency defaultCurrency = Currency.iqd]) {
    final currency = Currency.fromCode(map['currency'] as String?);
    return SupplierReturnItem(
      id: map['id'] as String,
      purchaseReceiptItemId: map['purchaseReceiptItemId'] as String,
      productId: map['productId'] as String,
      variantId: map['variantId'] as String?,
      quantity: StockQuantity.fromMilliUnits(map['quantityMilli'] as int? ?? 1000),
      unitCost: Money.fromMinorUnits(map['unitCostUnits'] as int? ?? 0, currency),
      reason: map['reason'] as String? ?? '',
    );
  }
}

class SupplierReturnModel {
  const SupplierReturnModel._();

  static Map<String, dynamic> toMap(SupplierReturn ret) {
    return {
      'id': ret.id,
      'businessId': ret.businessId,
      'branchId': ret.branchId,
      'supplierId': ret.supplierId,
      'originalPurchaseId': ret.originalPurchaseId,
      'originalReceiptId': ret.originalReceiptId,
      'returnNumber': ret.returnNumber,
      'status': ret.status.name,
      'items': ret.items.map(SupplierReturnItemModel.toMap).toList(),
      'currency': ret.currency.code,
      'reason': ret.reason,
      'actorId': ret.actorId,
      'createdAt': ret.createdAt.toIso8601String(),
      'updatedAt': ret.updatedAt.toIso8601String(),
      'version': ret.version,
      'idempotencyKey': ret.idempotencyKey,
      'metadata': ret.metadata,
    };
  }

  static SupplierReturn fromMap(Map<String, dynamic> map) {
    final currency = Currency.fromCode(map['currency'] as String?);
    final itemsRaw = map['items'] as List<dynamic>? ?? const [];
    final items = itemsRaw
        .map((it) => SupplierReturnItemModel.fromMap(it as Map<String, dynamic>, currency))
        .toList();

    return SupplierReturn(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      branchId: map['branchId'] as String,
      supplierId: map['supplierId'] as String,
      originalPurchaseId: map['originalPurchaseId'] as String,
      originalReceiptId: map['originalReceiptId'] as String,
      returnNumber: map['returnNumber'] as String,
      status: SupplierReturnStatus.fromString(map['status'] as String?),
      items: items,
      currency: currency,
      reason: map['reason'] as String? ?? '',
      actorId: map['actorId'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      version: map['version'] as int? ?? 1,
      idempotencyKey: map['idempotencyKey'] as String? ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? const {}),
    );
  }
}
