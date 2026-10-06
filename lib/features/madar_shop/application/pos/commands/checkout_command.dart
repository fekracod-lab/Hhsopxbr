// أمر تنفيذ عملية البيع والتحصيل (MADAR SHOP POS Checkout Command)
// Pure Dart — Zero UI Dependencies

import '../../../domain/pos/calculators/tax_policy.dart';
import '../../../domain/pos/entities/cart.dart';
import '../../../domain/pos/entities/payment.dart';

class CheckoutCommand {
  final String commandId;
  final String businessId;
  final String branchId;
  final String terminalId;
  final String sessionId;
  final String idempotencyKey;
  final Cart cart;
  final List<Payment> payments;
  final String? customerId;
  final String? customerName;
  final TaxPolicy taxPolicy;
  final String? notes;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  CheckoutCommand({
    required this.commandId,
    required this.businessId,
    required this.branchId,
    required this.terminalId,
    required this.sessionId,
    required this.idempotencyKey,
    required this.cart,
    required this.payments,
    this.customerId,
    this.customerName,
    TaxPolicy? taxPolicy,
    this.notes,
    DateTime? createdAt,
    this.metadata = const {},
  })  : taxPolicy = taxPolicy ?? TaxPolicy.none(),
        createdAt = createdAt ?? DateTime.now();
}
