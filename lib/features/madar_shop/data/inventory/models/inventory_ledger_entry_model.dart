// نموذج بيانات قيد دفتر الأستاذ للتحويل من وإلى التخزين (MADAR SHOP Inventory Ledger Entry Model)
// Pure Dart — Zero Flutter / Firebase SDK Dependencies

import '../../../domain/inventory/entities/inventory_ledger_entry.dart';
import '../../../domain/inventory/enums/inventory_movement_type.dart';
import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/inventory/value_objects/stock_unit.dart';

class InventoryLedgerEntryModel {
  static Map<String, dynamic> toMap(InventoryLedgerEntry entry) {
    return {
      'id': entry.id,
      'businessId': entry.businessId,
      'branchId': entry.branchId,
      'productId': entry.productId,
      'variantId': entry.variantId,
      'movementType': entry.movementType.name,
      'quantityDeltaMilliUnits': entry.quantityDelta.milliUnits,
      'reservedDeltaMilliUnits': entry.reservedDelta.milliUnits,
      'unit': entry.unit.name,
      'beforeOnHandMilliUnits': entry.beforeOnHand.milliUnits,
      'afterOnHandMilliUnits': entry.afterOnHand.milliUnits,
      'beforeReservedMilliUnits': entry.beforeReserved.milliUnits,
      'afterReservedMilliUnits': entry.afterReserved.milliUnits,
      'beforeAvailableMilliUnits': entry.beforeAvailable.milliUnits,
      'afterAvailableMilliUnits': entry.afterAvailable.milliUnits,
      'referenceType': entry.referenceType,
      'referenceId': entry.referenceId,
      'actorId': entry.actorId,
      'terminalId': entry.terminalId,
      'sessionId': entry.sessionId,
      'reason': entry.reason,
      'createdAt': entry.createdAt.toIso8601String(),
      'version': entry.version,
      'idempotencyKey': entry.idempotencyKey,
      'metadata': entry.metadata,
    };
  }

  static InventoryLedgerEntry fromMap(Map<String, dynamic> map) {
    final unit = StockUnit.values.firstWhere(
      (u) => u.name == map['unit'],
      orElse: () => StockUnit.piece,
    );

    final movementType = InventoryMovementType.values.firstWhere(
      (m) => m.name == map['movementType'],
      orElse: () => InventoryMovementType.initialBalance,
    );

    return InventoryLedgerEntry(
      id: map['id'] as String,
      businessId: map['businessId'] as String,
      branchId: map['branchId'] as String,
      productId: map['productId'] as String,
      variantId: map['variantId'] as String?,
      movementType: movementType,
      quantityDelta: StockQuantity.fromMilliUnits(
        (map['quantityDeltaMilliUnits'] as num?)?.toInt() ?? 0,
        unit,
      ),
      reservedDelta: StockQuantity.fromMilliUnits(
        (map['reservedDeltaMilliUnits'] as num?)?.toInt() ?? 0,
        unit,
      ),
      unit: unit,
      beforeOnHand: StockQuantity.fromMilliUnits(
        (map['beforeOnHandMilliUnits'] as num?)?.toInt() ?? 0,
        unit,
      ),
      afterOnHand: StockQuantity.fromMilliUnits(
        (map['afterOnHandMilliUnits'] as num?)?.toInt() ?? 0,
        unit,
      ),
      beforeReserved: StockQuantity.fromMilliUnits(
        (map['beforeReservedMilliUnits'] as num?)?.toInt() ?? 0,
        unit,
      ),
      afterReserved: StockQuantity.fromMilliUnits(
        (map['afterReservedMilliUnits'] as num?)?.toInt() ?? 0,
        unit,
      ),
      beforeAvailable: StockQuantity.fromMilliUnits(
        (map['beforeAvailableMilliUnits'] as num?)?.toInt() ?? 0,
        unit,
      ),
      afterAvailable: StockQuantity.fromMilliUnits(
        (map['afterAvailableMilliUnits'] as num?)?.toInt() ?? 0,
        unit,
      ),
      referenceType: map['referenceType'] as String? ?? '',
      referenceId: map['referenceId'] as String? ?? '',
      actorId: map['actorId'] as String? ?? '',
      terminalId: map['terminalId'] as String?,
      sessionId: map['sessionId'] as String?,
      reason: map['reason'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      version: (map['version'] as num?)?.toInt() ?? 1,
      idempotencyKey: map['idempotencyKey'] as String? ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? const {}),
    );
  }
}
