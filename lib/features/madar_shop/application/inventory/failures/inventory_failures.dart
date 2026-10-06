// أخطاء وإخفاقات محرك المخزون المعرفة برمجياً (MADAR SHOP Typed Inventory Failures)
// Pure Dart — Zero UI Dependencies

abstract class InventoryFailure implements Exception {
  final String message;
  final String? code;

  const InventoryFailure(this.message, [this.code]);

  @override
  String toString() => message;
}

class InsufficientStockFailure extends InventoryFailure {
  const InsufficientStockFailure(super.message, [super.code = 'INSUFFICIENT_STOCK']);
}

class InventoryConflictFailure extends InventoryFailure {
  const InventoryConflictFailure(super.message, [super.code = 'INVENTORY_CONFLICT']);
}

class DuplicateInventoryOperationFailure extends InventoryFailure {
  const DuplicateInventoryOperationFailure(super.message, [super.code = 'DUPLICATE_OPERATION']);
}

class UnauthorizedInventoryOperationFailure extends InventoryFailure {
  const UnauthorizedInventoryOperationFailure(super.message, [super.code = 'UNAUTHORIZED_INVENTORY_OPERATION']);
}

class InvalidStockQuantityFailure extends InventoryFailure {
  const InvalidStockQuantityFailure(super.message, [super.code = 'INVALID_QUANTITY']);
}

class InventoryBranchMismatchFailure extends InventoryFailure {
  const InventoryBranchMismatchFailure(super.message, [super.code = 'BRANCH_MISMATCH']);
}

class InventoryItemNotFoundFailure extends InventoryFailure {
  const InventoryItemNotFoundFailure(super.message, [super.code = 'ITEM_NOT_FOUND']);
}

class ReservationExceededFailure extends InventoryFailure {
  const ReservationExceededFailure(super.message, [super.code = 'RESERVATION_EXCEEDED']);
}

class NegativeStockBlockedFailure extends InventoryFailure {
  const NegativeStockBlockedFailure(super.message, [super.code = 'NEGATIVE_STOCK_BLOCKED']);
}
