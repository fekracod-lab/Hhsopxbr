// نموذج بيانات دفعة سداد المورد (MADAR SHOP Supplier Payment Data Model)
// Pure Dart — Zero UI Dependencies

import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/purchasing/entities/supplier_payment.dart';
import '../../../domain/purchasing/enums/supplier_payment_method.dart';
import '../../../domain/purchasing/enums/supplier_payment_status.dart';

class SupplierPaymentModel {
  static Map<String, dynamic> toMap(SupplierPayment payment) {
    return {
      'id': payment.id,
      'supplierId': payment.supplierId,
      'businessId': payment.businessId,
      'amountMinorUnits': payment.amount.minorUnits,
      'currency': payment.currency.code,
      'method': payment.method.name,
      'reference': payment.reference,
      'status': payment.status.name,
      'createdAt': payment.createdAt.toIso8601String(),
      'actorId': payment.actorId,
      'idempotencyKey': payment.idempotencyKey,
      'purchaseOrderId': payment.purchaseOrderId,
      'notes': payment.notes,
    };
  }

  static SupplierPayment fromMap(Map<String, dynamic> map) {
    final currency = Currency.fromCode(map['currency'] as String?);
    return SupplierPayment(
      id: map['id'] as String,
      supplierId: map['supplierId'] as String,
      businessId: map['businessId'] as String,
      amount: Money.fromMinorUnits(map['amountMinorUnits'] as int, currency),
      currency: currency,
      method: SupplierPaymentMethod.fromString(map['method'] as String?),
      reference: map['reference'] as String?,
      status: SupplierPaymentStatus.fromString(map['status'] as String?),
      createdAt: DateTime.parse(map['createdAt'] as String),
      actorId: map['actorId'] as String,
      idempotencyKey: map['idempotencyKey'] as String,
      purchaseOrderId: map['purchaseOrderId'] as String?,
      notes: map['notes'] as String?,
    );
  }
}
