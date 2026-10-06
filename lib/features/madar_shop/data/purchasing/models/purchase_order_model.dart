// نموذج بيانات أمر الشراء وبنوده (MADAR SHOP Purchase Order Data Models)
// Pure Dart — Zero UI Dependencies

import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/inventory/value_objects/stock_unit.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/purchasing/entities/purchase_item.dart';
import '../../../domain/purchasing/entities/purchase_order.dart';
import '../../../domain/purchasing/enums/purchase_order_status.dart';
import '../../../domain/purchasing/value_objects/cost_snapshot.dart';

class PurchaseItemModel {
  static Map<String, dynamic> toMap(PurchaseItem item) {
    return {
      'id': item.id,
      'productId': item.productId,
      'variantId': item.variantId,
      'descriptionSnapshot': item.descriptionSnapshot,
      'skuSnapshot': item.skuSnapshot,
      'barcodeSnapshot': item.barcodeSnapshot,
      'quantityOrderedMilli': item.quantityOrdered.milliUnits,
      'quantityReceivedMilli': item.quantityReceived.milliUnits,
      'unit': item.unit.name,
      'unitCostMinorUnits': item.unitCost.minorUnits,
      'discountMinorUnits': item.discount.minorUnits,
      'taxMinorUnits': item.tax.minorUnits,
      'currency': item.unitCost.currency.code,
      'costSnapshot': {
        'unitCostMinor': item.costSnapshot.unitCost.minorUnits,
        'discountPerUnitMinor': item.costSnapshot.discountPerUnit.minorUnits,
        'taxPerUnitMinor': item.costSnapshot.taxPerUnit.minorUnits,
        'effectiveAt': item.costSnapshot.effectiveAt.toIso8601String(),
      },
    };
  }

  static PurchaseItem fromMap(Map<String, dynamic> map) {
    final currency = Currency.fromCode(map['currency'] as String?);
    final unit = StockUnit.fromString(map['unit'] as String?);
    final unitCost = Money.fromMinorUnits(map['unitCostMinorUnits'] as int, currency);
    final discount = Money.fromMinorUnits(map['discountMinorUnits'] as int? ?? 0, currency);
    final tax = Money.fromMinorUnits(map['taxMinorUnits'] as int? ?? 0, currency);

    CostSnapshot? costSnapshot;
    if (map['costSnapshot'] != null) {
      final csMap = Map<String, dynamic>.from(map['costSnapshot'] as Map);
      costSnapshot = CostSnapshot(
        unitCost: Money.fromMinorUnits(csMap['unitCostMinor'] as int, currency),
        discountPerUnit: Money.fromMinorUnits(csMap['discountPerUnitMinor'] as int? ?? 0, currency),
        taxPerUnit: Money.fromMinorUnits(csMap['taxPerUnitMinor'] as int? ?? 0, currency),
        effectiveAt: DateTime.parse(csMap['effectiveAt'] as String),
      );
    }

    return PurchaseItem(
      id: map['id'] as String,
      productId: map['productId'] as String,
      variantId: map['variantId'] as String?,
      descriptionSnapshot: map['descriptionSnapshot'] as String,
      skuSnapshot: map['skuSnapshot'] as String,
      barcodeSnapshot: map['barcodeSnapshot'] as String?,
      quantityOrdered: StockQuantity.fromMilliUnits(map['quantityOrderedMilli'] as int, unit),
      quantityReceived: StockQuantity.fromMilliUnits(map['quantityReceivedMilli'] as int? ?? 0, unit),
      unit: unit,
      unitCost: unitCost,
      discount: discount,
      tax: tax,
      costSnapshot: costSnapshot,
    );
  }
}

class PurchaseOrderModel {
  static Map<String, dynamic> toMap(PurchaseOrder order) {
    return {
      'id': order.id,
      'businessId': order.businessId,
      'branchId': order.branchId,
      'supplierId': order.supplierId,
      'orderNumber': order.orderNumber,
      'status': order.status.name,
      'items': order.items.map(PurchaseItemModel.toMap).toList(),
      'subtotalMinorUnits': order.subtotal.minorUnits,
      'discountTotalMinorUnits': order.discountTotal.minorUnits,
      'taxTotalMinorUnits': order.taxTotal.minorUnits,
      'grandTotalMinorUnits': order.grandTotal.minorUnits,
      'currency': order.currency.code,
      'createdBy': order.createdBy,
      'approvedBy': order.approvedBy,
      'cancelledBy': order.cancelledBy,
      'cancellationReason': order.cancellationReason,
      'createdAt': order.createdAt.toIso8601String(),
      'updatedAt': order.updatedAt.toIso8601String(),
      'version': order.version,
      'idempotencyKey': order.idempotencyKey,
      'notes': order.notes,
    };
  }

  static PurchaseOrder fromMap(Map<String, dynamic> map) {
    final currency = Currency.fromCode(map['currency'] as String?);
    final rawItems = (map['items'] as List?) ?? [];
    final items = rawItems
        .map((i) => PurchaseItemModel.fromMap(Map<String, dynamic>.from(i as Map)))
        .toList();

    return PurchaseOrder(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      branchId: map['branchId'] as String,
      supplierId: map['supplierId'] as String,
      orderNumber: map['orderNumber'] as String,
      status: PurchaseOrderStatus.fromString(map['status'] as String?),
      items: items,
      subtotal: Money.fromMinorUnits(map['subtotalMinorUnits'] as int, currency),
      discountTotal: Money.fromMinorUnits(map['discountTotalMinorUnits'] as int? ?? 0, currency),
      taxTotal: Money.fromMinorUnits(map['taxTotalMinorUnits'] as int? ?? 0, currency),
      grandTotal: Money.fromMinorUnits(map['grandTotalMinorUnits'] as int, currency),
      currency: currency,
      createdBy: map['createdBy'] as String,
      approvedBy: map['approvedBy'] as String?,
      cancelledBy: map['cancelledBy'] as String?,
      cancellationReason: map['cancellationReason'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      version: map['version'] as int? ?? 1,
      idempotencyKey: map['idempotencyKey'] as String,
      notes: map['notes'] as String?,
    );
  }
}
