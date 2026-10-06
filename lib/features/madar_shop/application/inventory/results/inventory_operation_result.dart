// نتيجة تنفيذ عمليات المخزون (MADAR SHOP Inventory Operation Result)
// Pure Dart — Zero UI Dependencies

import '../../../domain/inventory/entities/inventory_item.dart';
import '../../../domain/inventory/entities/inventory_ledger_entry.dart';

class InventoryOperationResult {
  final bool isSuccess;
  final InventoryItem item;
  final InventoryLedgerEntry? ledgerEntry;
  final bool isIdempotentReplay;
  final String? message;

  const InventoryOperationResult({
    required this.isSuccess,
    required this.item,
    this.ledgerEntry,
    this.isIdempotentReplay = false,
    this.message,
  });
}
