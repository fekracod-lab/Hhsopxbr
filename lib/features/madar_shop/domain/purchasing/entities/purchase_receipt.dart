// إيصال استلام بضاعة المشتريات (MADAR SHOP Purchase Receipt Entity)
// Pure Dart — Zero UI Dependencies

import '../../pos/value_objects/currency.dart';
import '../../pos/value_objects/money.dart';
import 'purchase_receipt_item.dart';

class PurchaseReceipt {
  final String id;
  final String businessId;
  final String branchId;
  final String purchaseOrderId;
  final String supplierId;
  final List<PurchaseReceiptItem> items;
  final Money totalCost;
  final Currency currency;
  final String receivedBy;
  final DateTime receivedAt;
  final String? reference;
  final String idempotencyKey;
  final String? notes;

  PurchaseReceipt({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.purchaseOrderId,
    required this.supplierId,
    required this.items,
    Money? totalCost,
    Currency? currency,
    required this.receivedBy,
    required this.receivedAt,
    this.reference,
    required this.idempotencyKey,
    this.notes,
  })  : currency = currency ?? (items.isNotEmpty ? items.first.unitCost.currency : Currency.iqd),
        totalCost = totalCost ??
            (items.isEmpty
                ? Money.zero(currency ?? Currency.iqd)
                : items.map((i) => i.lineTotal).reduce((a, b) => a + b));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseReceipt &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'PurchaseReceipt(id: $id, po: $purchaseOrderId, totalCost: $totalCost, by: $receivedBy)';
}
