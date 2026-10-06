// نتيجة تنفيذ معاملة البيع والدفع (MADAR SHOP POS Checkout Result)
// Pure Dart — Zero UI Dependencies

import '../../../domain/pos/entities/customer_ledger_entry.dart';
import '../../../domain/pos/entities/inventory_movement_intent.dart';
import '../../../domain/pos/entities/receipt_snapshot.dart';
import '../../../domain/pos/entities/sale.dart';

class CheckoutResult {
  final Sale sale;
  final ReceiptSnapshot receipt;
  final List<InventoryMovementIntent> inventoryIntents;
  final CustomerLedgerEntry? customerLedgerEntry;
  final bool isIdempotentReplay;
  final DateTime processedAt;

  const CheckoutResult({
    required this.sale,
    required this.receipt,
    required this.inventoryIntents,
    this.customerLedgerEntry,
    this.isIdempotentReplay = false,
    required this.processedAt,
  });
}
