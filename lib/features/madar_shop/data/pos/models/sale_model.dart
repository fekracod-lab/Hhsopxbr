// نموذج بيانات الفاتورة ومعاملة البيع (MADAR SHOP Sale Data Model)
// Pure Dart — Zero Flutter / Firebase SDK Dependencies

import '../../../domain/pos/entities/payment.dart';
import '../../../domain/pos/entities/sale.dart';
import '../../../domain/pos/entities/sale_item.dart';
import '../../../domain/pos/enums/sale_status.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/pos/value_objects/pricing_snapshot.dart';
import 'payment_model.dart';

class SaleModel {
  const SaleModel._();

  static Map<String, dynamic> toMap(Sale sale) {
    return {
      'id': sale.id,
      'businessId': sale.businessId,
      'branchId': sale.branchId,
      'terminalId': sale.terminalId,
      'sessionId': sale.sessionId,
      'cashierId': sale.cashierId,
      'cashierName': sale.cashierName,
      'saleNumber': sale.saleNumber,
      'source': sale.source,
      'status': sale.status.toDbString(),
      'items': sale.items.map((it) => _saleItemToMap(it)).toList(),
      'subtotalUnits': sale.subtotal.minorUnits,
      'discountTotalUnits': sale.discountTotal.minorUnits,
      'taxTotalUnits': sale.taxTotal.minorUnits,
      'grandTotalUnits': sale.grandTotal.minorUnits,
      'paidTotalUnits': sale.paidTotal.minorUnits,
      'remainingTotalUnits': sale.remainingTotal.minorUnits,
      'changeTotalUnits': sale.changeTotal.minorUnits,
      'customerId': sale.customerId,
      'customerName': sale.customerName,
      'payments': sale.payments.map((p) => PaymentModel.toMap(p)).toList(),
      'currencyCode': sale.currency.code,
      'createdAt': sale.createdAt.toIso8601String(),
      'completedAt': sale.completedAt?.toIso8601String(),
      'cancelledAt': sale.cancelledAt?.toIso8601String(),
      'version': sale.version,
      'idempotencyKey': sale.idempotencyKey,
      'metadata': sale.metadata,
    };
  }

  static Sale fromMap(Map<String, dynamic> map) {
    final currency = Currency.fromCode(map['currencyCode'] as String?);

    final rawItems = map['items'] as List? ?? [];
    final items = rawItems.map((it) => _saleItemFromMap(Map<String, dynamic>.from(it as Map), currency)).toList();

    final rawPayments = map['payments'] as List? ?? [];
    final payments = rawPayments.map((p) => PaymentModel.fromMap(Map<String, dynamic>.from(p as Map), currency)).toList();

    return Sale(
      id: map['id'] as String? ?? '',
      businessId: map['businessId'] as String? ?? '',
      branchId: map['branchId'] as String? ?? '',
      terminalId: map['terminalId'] as String? ?? '',
      sessionId: map['sessionId'] as String? ?? '',
      cashierId: map['cashierId'] as String? ?? '',
      cashierName: map['cashierName'] as String? ?? '',
      saleNumber: map['saleNumber'] as String? ?? '',
      source: map['source'] as String? ?? 'POS_DESKTOP',
      status: SaleStatus.fromString(map['status'] as String?),
      items: items,
      subtotal: Money.fromMinorUnits((map['subtotalUnits'] as num?)?.toInt() ?? 0, currency),
      discountTotal: Money.fromMinorUnits((map['discountTotalUnits'] as num?)?.toInt() ?? 0, currency),
      taxTotal: Money.fromMinorUnits((map['taxTotalUnits'] as num?)?.toInt() ?? 0, currency),
      grandTotal: Money.fromMinorUnits((map['grandTotalUnits'] as num?)?.toInt() ?? 0, currency),
      paidTotal: Money.fromMinorUnits((map['paidTotalUnits'] as num?)?.toInt() ?? 0, currency),
      remainingTotal: Money.fromMinorUnits((map['remainingTotalUnits'] as num?)?.toInt() ?? 0, currency),
      changeTotal: Money.fromMinorUnits((map['changeTotalUnits'] as num?)?.toInt() ?? 0, currency),
      customerId: map['customerId'] as String?,
      customerName: map['customerName'] as String?,
      payments: payments,
      currency: currency,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      completedAt: DateTime.tryParse(map['completedAt'] as String? ?? ''),
      cancelledAt: DateTime.tryParse(map['cancelledAt'] as String? ?? ''),
      version: (map['version'] as num?)?.toInt() ?? 1,
      idempotencyKey: map['idempotencyKey'] as String? ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  static Map<String, dynamic> _saleItemToMap(SaleItem item) {
    return {
      'itemId': item.itemId,
      'productId': item.productId,
      'variantId': item.variantId,
      'variantTitle': item.variantTitle,
      'sku': item.sku,
      'barcode': item.barcode,
      'name': item.name,
      'pricingSnapshot': item.pricingSnapshot.toMap(),
      'quantity': item.quantity,
      'unitOfMeasure': item.unitOfMeasure,
      'isWeighable': item.isWeighable,
      'lineDiscountUnits': item.lineDiscount.minorUnits,
      'lineTaxUnits': item.lineTax.minorUnits,
      'notes': item.notes,
    };
  }

  static SaleItem _saleItemFromMap(Map<String, dynamic> map, Currency currency) {
    return SaleItem(
      itemId: map['itemId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      variantId: map['variantId'] as String?,
      variantTitle: map['variantTitle'] as String?,
      sku: map['sku'] as String? ?? '',
      barcode: map['barcode'] as String?,
      name: map['name'] as String? ?? '',
      pricingSnapshot: PricingSnapshot.fromMap(
        Map<String, dynamic>.from(map['pricingSnapshot'] as Map? ?? {}),
      ),
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unitOfMeasure: map['unitOfMeasure'] as String? ?? 'piece',
      isWeighable: map['isWeighable'] as bool? ?? false,
      lineDiscount: Money.fromMinorUnits((map['lineDiscountUnits'] as num?)?.toInt() ?? 0, currency),
      lineTax: Money.fromMinorUnits((map['lineTaxUnits'] as num?)?.toInt() ?? 0, currency),
      notes: map['notes'] as String?,
    );
  }
}
