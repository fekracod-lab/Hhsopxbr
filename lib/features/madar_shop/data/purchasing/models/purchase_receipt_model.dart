// نموذج بيانات إيصال استلام بضاعة المشتريات (MADAR SHOP Purchase Receipt Data Models)
// Pure Dart — Zero UI Dependencies

import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/inventory/value_objects/stock_unit.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/purchasing/entities/purchase_receipt.dart';
import '../../../domain/purchasing/entities/purchase_receipt_item.dart';

class PurchaseReceiptItemModel {
  static Map<String, dynamic> toMap(PurchaseReceiptItem item) {
    return {
      'purchaseItemId': item.purchaseItemId,
      'productId': item.productId,
      'variantId': item.variantId,
      'quantityReceivedMilli': item.quantityReceived.milliUnits,
      'unit': item.unit.name,
      'unitCostMinorUnits': item.unitCost.minorUnits,
      'lineTotalMinorUnits': item.lineTotal.minorUnits,
      'currency': item.unitCost.currency.code,
      'batchId': item.batchId,
      'lotNumber': item.lotNumber,
      'expiryDate': item.expiryDate?.toIso8601String(),
    };
  }

  static PurchaseReceiptItem fromMap(Map<String, dynamic> map) {
    final currency = Currency.fromCode(map['currency'] as String?);
    final unit = StockUnit.fromString(map['unit'] as String?);
    return PurchaseReceiptItem(
      purchaseItemId: map['purchaseItemId'] as String,
      productId: map['productId'] as String,
      variantId: map['variantId'] as String?,
      quantityReceived: StockQuantity.fromMilliUnits(map['quantityReceivedMilli'] as int, unit),
      unit: unit,
      unitCost: Money.fromMinorUnits(map['unitCostMinorUnits'] as int, currency),
      lineTotal: Money.fromMinorUnits(map['lineTotalMinorUnits'] as int, currency),
      batchId: map['batchId'] as String?,
      lotNumber: map['lotNumber'] as String?,
      expiryDate: map['expiryDate'] != null ? DateTime.parse(map['expiryDate'] as String) : null,
    );
  }
}

class PurchaseReceiptModel {
  static Map<String, dynamic> toMap(PurchaseReceipt receipt) {
    return {
      'id': receipt.id,
      'businessId': receipt.businessId,
      'branchId': receipt.branchId,
      'purchaseOrderId': receipt.purchaseOrderId,
      'supplierId': receipt.supplierId,
      'items': receipt.items.map(PurchaseReceiptItemModel.toMap).toList(),
      'totalCostMinorUnits': receipt.totalCost.minorUnits,
      'currency': receipt.currency.code,
      'receivedBy': receipt.receivedBy,
      'receivedAt': receipt.receivedAt.toIso8601String(),
      'reference': receipt.reference,
      'idempotencyKey': receipt.idempotencyKey,
      'notes': receipt.notes,
    };
  }

  static PurchaseReceipt fromMap(Map<String, dynamic> map) {
    final currency = Currency.fromCode(map['currency'] as String?);
    final rawItems = (map['items'] as List?) ?? [];
    final items = rawItems
        .map((i) => PurchaseReceiptItemModel.fromMap(Map<String, dynamic>.from(i as Map)))
        .toList();

    return PurchaseReceipt(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      branchId: map['branchId'] as String,
      purchaseOrderId: map['purchaseOrderId'] as String,
      supplierId: map['supplierId'] as String,
      items: items,
      totalCost: Money.fromMinorUnits(map['totalCostMinorUnits'] as int, currency),
      currency: currency,
      receivedBy: map['receivedBy'] as String,
      receivedAt: DateTime.parse(map['receivedAt'] as String),
      reference: map['reference'] as String?,
      idempotencyKey: map['idempotencyKey'] as String,
      notes: map['notes'] as String?,
    );
  }
}
