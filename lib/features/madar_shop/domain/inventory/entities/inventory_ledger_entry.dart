// قيد دفتر أستاذ المخزون التاريخي غير القابل للتعديل (MADAR SHOP Inventory Ledger Entry)
// Pure Dart — Zero UI Dependencies

import '../enums/inventory_movement_type.dart';
import '../value_objects/stock_quantity.dart';
import '../value_objects/stock_unit.dart';

class InventoryLedgerEntry {
  final String id;
  final String businessId;
  final String branchId;
  final String productId;
  final String? variantId;
  final InventoryMovementType movementType;
  final StockQuantity quantityDelta; // التغير في الرصيد الفعلي (موجب أو سالب)
  final StockQuantity reservedDelta; // التغير في المحجوز (موجب أو سالب)
  final StockUnit unit;
  final StockQuantity beforeOnHand;
  final StockQuantity afterOnHand;
  final StockQuantity beforeReserved;
  final StockQuantity afterReserved;
  final StockQuantity beforeAvailable;
  final StockQuantity afterAvailable;
  final String referenceType; // e.g. "SALE", "PURCHASE", "RETURN", "TRANSFER", "ADJUSTMENT"
  final String referenceId;
  final String actorId;
  final String? terminalId;
  final String? sessionId;
  final String reason;
  final DateTime createdAt;
  final int version;
  final String idempotencyKey;
  final Map<String, dynamic> metadata;

  const InventoryLedgerEntry({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.productId,
    this.variantId,
    required this.movementType,
    required this.quantityDelta,
    required this.reservedDelta,
    required this.unit,
    required this.beforeOnHand,
    required this.afterOnHand,
    required this.beforeReserved,
    required this.afterReserved,
    required this.beforeAvailable,
    required this.afterAvailable,
    required this.referenceType,
    required this.referenceId,
    required this.actorId,
    this.terminalId,
    this.sessionId,
    required this.reason,
    required this.createdAt,
    required this.version,
    required this.idempotencyKey,
    this.metadata = const {},
  });
}
