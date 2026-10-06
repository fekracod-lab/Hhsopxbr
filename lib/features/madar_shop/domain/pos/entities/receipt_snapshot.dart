// لقطة إيصال البيع التاريخية غير القابلة للتغيير للطباعة (MADAR SHOP Receipt Snapshot)
// Pure Dart — Zero UI Dependencies

import 'sale.dart';

class ReceiptLineSnapshot {
  final String productName;
  final String? variantTitle;
  final String sku;
  final double quantity;
  final String unitOfMeasure;
  final double unitPriceAmount;
  final double discountAmount;
  final double lineTotalAmount;

  const ReceiptLineSnapshot({
    required this.productName,
    this.variantTitle,
    required this.sku,
    required this.quantity,
    required this.unitOfMeasure,
    required this.unitPriceAmount,
    required this.discountAmount,
    required this.lineTotalAmount,
  });
}

class ReceiptPaymentSnapshot {
  final String methodDisplayName;
  final double amount;
  final String? reference;

  const ReceiptPaymentSnapshot({
    required this.methodDisplayName,
    required this.amount,
    this.reference,
  });
}

class ReceiptSnapshot {
  final String saleId;
  final String saleNumber;
  final String businessName;
  final String branchName;
  final String terminalId;
  final String cashierName;
  final String? customerName;
  final List<ReceiptLineSnapshot> lines;
  final double subtotalAmount;
  final double discountTotalAmount;
  final double taxTotalAmount;
  final double grandTotalAmount;
  final double paidTotalAmount;
  final double changeTotalAmount;
  final double remainingTotalAmount;
  final List<ReceiptPaymentSnapshot> payments;
  final String currencyCode;
  final String currencySymbol;
  final DateTime printedOrCreatedAt;

  const ReceiptSnapshot({
    required this.saleId,
    required this.saleNumber,
    required this.businessName,
    required this.branchName,
    required this.terminalId,
    required this.cashierName,
    this.customerName,
    required this.lines,
    required this.subtotalAmount,
    required this.discountTotalAmount,
    required this.taxTotalAmount,
    required this.grandTotalAmount,
    required this.paidTotalAmount,
    required this.changeTotalAmount,
    required this.remainingTotalAmount,
    required this.payments,
    required this.currencyCode,
    required this.currencySymbol,
    required this.printedOrCreatedAt,
  });

  /// توليد لقطة إيصال فورية وثابتة من معاملة البيع المكتملة
  factory ReceiptSnapshot.fromSale({
    required Sale sale,
    required String businessName,
    required String branchName,
  }) {
    final currency = sale.currency;

    final lines = sale.items.map((it) {
      return ReceiptLineSnapshot(
        productName: it.name,
        variantTitle: it.variantTitle,
        sku: it.sku,
        quantity: it.quantity,
        unitOfMeasure: it.unitOfMeasure,
        unitPriceAmount: it.pricingSnapshot.unitPrice.toAmount(),
        discountAmount: it.lineDiscount.toAmount(),
        lineTotalAmount: it.lineTotal.toAmount(),
      );
    }).toList();

    final payments = sale.payments.map((p) {
      return ReceiptPaymentSnapshot(
        methodDisplayName: p.method.displayNameAr,
        amount: p.amount.toAmount(),
        reference: p.reference,
      );
    }).toList();

    return ReceiptSnapshot(
      saleId: sale.id,
      saleNumber: sale.saleNumber,
      businessName: businessName,
      branchName: branchName,
      terminalId: sale.terminalId,
      cashierName: sale.cashierName,
      customerName: sale.customerName,
      lines: lines,
      subtotalAmount: sale.subtotal.toAmount(),
      discountTotalAmount: sale.discountTotal.toAmount(),
      taxTotalAmount: sale.taxTotal.toAmount(),
      grandTotalAmount: sale.grandTotal.toAmount(),
      paidTotalAmount: sale.paidTotal.toAmount(),
      changeTotalAmount: sale.changeTotal.toAmount(),
      remainingTotalAmount: sale.remainingTotal.toAmount(),
      payments: payments,
      currencyCode: currency.code,
      currencySymbol: currency.symbol,
      printedOrCreatedAt: DateTime.now(),
    );
  }
}
