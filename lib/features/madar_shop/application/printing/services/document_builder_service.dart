// خدمة بناء وتجهيز وثائق الطباعة من لقطات العمليات (MADAR SHOP Document Builder Service)
// Pure Dart — Zero UI Dependencies

import '../../../domain/pos/entities/receipt_snapshot.dart';
import '../../../domain/pos/entities/sale.dart';
import '../../../domain/printing/entities/print_document.dart';
import '../../../domain/printing/entities/print_section.dart';
import '../../../domain/printing/enums/barcode_format.dart';
import '../../../domain/printing/enums/print_document_type.dart';
import '../../../domain/printing/enums/section_alignment.dart';
import '../../../domain/printing/value_objects/paper_profile.dart';
import '../../../domain/purchasing/entities/purchase_receipt.dart';
import '../../../domain/returns/entities/return_order.dart';

class DocumentBuilderService {
  const DocumentBuilderService();

  /// بناء وثيقة طباعة من لقطة إيصال البيع المجمدة (ReceiptSnapshot)
  PrintDocument buildFromReceiptSnapshot(
    ReceiptSnapshot snapshot, {
    PaperProfile? preferredProfile,
    String? footerMessage,
  }) {
    final sections = <PrintSection>[];

    // 1. ترويسة المتجر
    sections.add(PrintSection.header(snapshot.businessName));
    sections.add(PrintSection.branchInfo(
      branchName: snapshot.branchName,
      terminalId: snapshot.terminalId,
      cashierName: snapshot.cashierName,
    ));

    // 2. بيانات الفاتورة
    sections.add(PrintSection(
      type: PrintSectionType.keyValue,
      keyValues: [
        PrintKeyValueData(key: 'رقم الفاتورة', value: snapshot.saleNumber, isBold: true),
        PrintKeyValueData(
          key: 'التاريخ',
          value: snapshot.printedOrCreatedAt.toIso8601String().substring(0, 19).replaceAll('T', ' '),
        ),
      ],
    ));

    // 3. بيانات العميل إذا وجدت
    if (snapshot.customerName != null && snapshot.customerName!.isNotEmpty) {
      sections.add(PrintSection.customerInfo(name: snapshot.customerName!));
    }

    sections.add(PrintSection.divider());

    // 4. عناصر الفاتورة
    final items = snapshot.lines.map((l) {
      return PrintItemRowData(
        name: l.productName,
        sku: l.sku,
        quantity: l.quantity,
        unitPriceFormatted: '${l.unitPriceAmount.toStringAsFixed(2)} ${snapshot.currencySymbol}',
        totalPriceFormatted: '${l.lineTotalAmount.toStringAsFixed(2)} ${snapshot.currencySymbol}',
        discountFormatted: l.discountAmount > 0
            ? '${l.discountAmount.toStringAsFixed(2)} ${snapshot.currencySymbol}'
            : null,
      );
    }).toList();
    sections.add(PrintSection.items(items));

    sections.add(PrintSection.divider());

    // 5. الإجماليات
    final totals = <PrintKeyValueData>[
      PrintKeyValueData(
        key: 'المجموع الفرعي',
        value: '${snapshot.subtotalAmount.toStringAsFixed(2)} ${snapshot.currencySymbol}',
      ),
      if (snapshot.discountTotalAmount > 0)
        PrintKeyValueData(
          key: 'إجمالي الخصم',
          value: '-${snapshot.discountTotalAmount.toStringAsFixed(2)} ${snapshot.currencySymbol}',
        ),
      if (snapshot.taxTotalAmount > 0)
        PrintKeyValueData(
          key: 'ضريبة القيمة المضافة',
          value: '${snapshot.taxTotalAmount.toStringAsFixed(2)} ${snapshot.currencySymbol}',
        ),
      PrintKeyValueData(
        key: 'المجموع الإجمالي',
        value: '${snapshot.grandTotalAmount.toStringAsFixed(2)} ${snapshot.currencySymbol}',
        isBold: true,
      ),
    ];
    sections.add(PrintSection.totals(totals));

    // 6. الدفعات والمتبقي
    if (snapshot.payments.isNotEmpty) {
      final payments = snapshot.payments.map((p) {
        return PrintKeyValueData(
          key: 'طريقة الدفع (${p.methodDisplayName})',
          value: '${p.amount.toStringAsFixed(2)} ${snapshot.currencySymbol}',
        );
      }).toList();

      if (snapshot.paidTotalAmount > 0) {
        payments.add(PrintKeyValueData(
          key: 'المدفوع',
          value: '${snapshot.paidTotalAmount.toStringAsFixed(2)} ${snapshot.currencySymbol}',
        ));
      }
      if (snapshot.changeTotalAmount > 0) {
        payments.add(PrintKeyValueData(
          key: 'المتبقي (فكة)',
          value: '${snapshot.changeTotalAmount.toStringAsFixed(2)} ${snapshot.currencySymbol}',
        ));
      }
      sections.add(PrintSection.payments(payments));
    }

    sections.add(PrintSection.divider());

    // 7. رمز التحقق / QR
    final qrData = 'SALE:${snapshot.saleNumber}|TOTAL:${snapshot.grandTotalAmount}|DATE:${snapshot.printedOrCreatedAt.toIso8601String()}';
    sections.add(PrintSection.qrCode(qrData));

    // 8. التذييل
    sections.add(PrintSection.footer(footerMessage ?? 'شكراً لزيارتكم! نتشرف بخدمتكم دائماً'));

    // 9. أمر فتح درج النقود إذا وجد دفع نقدي
    final hasCash = snapshot.payments.any((p) =>
        p.methodDisplayName.contains('نقد') ||
        p.methodDisplayName.toLowerCase().contains('cash'));
    if (hasCash) {
      sections.add(PrintSection.cashDrawerKick());
    }

    // 10. أمر قطع الورق
    sections.add(PrintSection.paperCut());

    return PrintDocument(
      documentType: PrintDocumentType.saleReceipt,
      documentId: snapshot.saleId,
      title: 'إيصال بيع #${snapshot.saleNumber}',
      businessId: 'snapshot_business',
      branchId: 'snapshot_branch',
      sections: sections,
      preferredPaperProfile: preferredProfile ?? PaperProfile.thermal80mm(),
      metadata: {
        'saleNumber': snapshot.saleNumber,
        'grandTotal': snapshot.grandTotalAmount,
        'currencyCode': snapshot.currencyCode,
      },
      createdAt: snapshot.printedOrCreatedAt,
    );
  }

  /// بناء وثيقة من كيان البيع (Sale) عبر تحويله إلى ReceiptSnapshot مجمد أولاً
  PrintDocument buildFromSale(
    Sale sale, {
    required String businessName,
    required String branchName,
    PaperProfile? preferredProfile,
    String? footerMessage,
  }) {
    final snapshot = ReceiptSnapshot.fromSale(
      sale: sale,
      businessName: businessName,
      branchName: branchName,
    );

    final doc = buildFromReceiptSnapshot(
      snapshot,
      preferredProfile: preferredProfile,
      footerMessage: footerMessage,
    );

    return doc.copyWith(
      businessId: sale.businessId,
      branchId: sale.branchId,
    );
  }

  /// بناء وثيقة إشعار مرتجع (Return Receipt)
  PrintDocument buildFromReturn(
    ReturnOrder order, {
    required String businessName,
    required String branchName,
    PaperProfile? preferredProfile,
    String? footerMessage,
  }) {
    final sections = <PrintSection>[];

    sections.add(PrintSection.header('$businessName - إشعار مرتجع'));
    sections.add(PrintSection.branchInfo(
      branchName: branchName,
      cashierName: order.createdBy,
    ));

    sections.add(PrintSection(
      type: PrintSectionType.keyValue,
      keyValues: [
        PrintKeyValueData(key: 'رقم المرتجع', value: order.returnNumber, isBold: true),
        PrintKeyValueData(key: 'رقم الفاتورة الأصلية', value: order.originalSaleId),
        PrintKeyValueData(
          key: 'التاريخ',
          value: order.createdAt.toIso8601String().substring(0, 19).replaceAll('T', ' '),
        ),
      ],
    ));

    if (order.customerName != null && order.customerName!.isNotEmpty) {
      sections.add(PrintSection.customerInfo(name: order.customerName!));
    }

    sections.add(PrintSection.divider());

    // عناصر الإرجاع
    final items = order.items.map((it) {
      return PrintItemRowData(
        name: it.descriptionSnapshot,
        sku: it.skuSnapshot,
        quantity: it.quantity.toDouble(),
        unitPriceFormatted: it.unitRefundPrice.toString(),
        totalPriceFormatted: it.lineRefundTotal.toString(),
        discountFormatted: it.unitDiscountDeduction.isPositive ? it.unitDiscountDeduction.toString() : null,
        notes: it.reason.name,
      );
    }).toList();
    sections.add(PrintSection.items(items));

    sections.add(PrintSection.divider());

    // الإجماليات
    final totals = <PrintKeyValueData>[
      PrintKeyValueData(
        key: 'إجمالي المرتجع المسترد',
        value: order.grandTotalRefund.toString(),
        isBold: true,
      ),
    ];
    sections.add(PrintSection.totals(totals));

    sections.add(PrintSection.divider());
    sections.add(PrintSection.footer(footerMessage ?? 'تمت عملية الإرجاع بنجاح'));
    sections.add(PrintSection.paperCut());

    return PrintDocument(
      documentType: PrintDocumentType.returnReceipt,
      documentId: order.id,
      title: 'إشعار إرجاع #${order.returnNumber}',
      businessId: order.businessId,
      branchId: order.branchId,
      sections: sections,
      preferredPaperProfile: preferredProfile ?? PaperProfile.thermal80mm(),
      metadata: {
        'returnNumber': order.returnNumber,
        'originalSaleId': order.originalSaleId,
        'totalRefund': order.grandTotalRefund.toAmount(),
      },
      createdAt: order.createdAt,
    );
  }

  /// بناء وثيقة استلام مشتريات (Purchase Receipt)
  PrintDocument buildFromPurchaseReceipt(
    PurchaseReceipt receipt, {
    required String businessName,
    required String branchName,
    PaperProfile? preferredProfile,
    String? footerMessage,
  }) {
    final sections = <PrintSection>[];
    final receiptNum = receipt.reference ?? receipt.id;

    sections.add(PrintSection.header('$businessName - إشعار استلام مشتريات'));
    sections.add(PrintSection.branchInfo(
      branchName: branchName,
      cashierName: receipt.receivedBy,
    ));

    sections.add(PrintSection(
      type: PrintSectionType.keyValue,
      keyValues: [
        PrintKeyValueData(key: 'رقم إذن الاستلام', value: receiptNum, isBold: true),
        PrintKeyValueData(key: 'أمر الشراء', value: receipt.purchaseOrderId),
        PrintKeyValueData(key: 'المورد', value: receipt.supplierId),
        PrintKeyValueData(
          key: 'تاريخ الاستلام',
          value: receipt.receivedAt.toIso8601String().substring(0, 19).replaceAll('T', ' '),
        ),
      ],
    ));

    sections.add(PrintSection.divider());

    final items = receipt.items.map((it) {
      return PrintItemRowData(
        name: it.productId,
        sku: it.productId,
        quantity: it.quantityReceived.toDouble(),
        unitPriceFormatted: it.unitCost.toString(),
        totalPriceFormatted: it.lineTotal.toString(),
        batch: it.batchId ?? it.lotNumber,
        expiry: it.expiryDate?.toIso8601String().substring(0, 10),
      );
    }).toList();
    sections.add(PrintSection.items(items));

    sections.add(PrintSection.divider());
    sections.add(PrintSection.footer(footerMessage ?? 'قسم المشتريات والمخازن'));
    sections.add(PrintSection.paperCut());

    return PrintDocument(
      documentType: PrintDocumentType.purchaseReceipt,
      documentId: receipt.id,
      title: 'إشعار استلام مشتريات #$receiptNum',
      businessId: receipt.businessId,
      branchId: receipt.branchId,
      sections: sections,
      preferredPaperProfile: preferredProfile ?? PaperProfile.a4(),
      metadata: {
        'receiptNumber': receiptNum,
        'purchaseOrderId': receipt.purchaseOrderId,
        'supplierId': receipt.supplierId,
      },
      createdAt: receipt.receivedAt,
    );
  }

  /// بناء ملصق باركود لمنتج (Product Label)
  PrintDocument buildProductLabel({
    required String businessId,
    required String branchId,
    required String productName,
    required String sku,
    required String barcode,
    required String priceFormatted,
    String? variant,
    String? batch,
    String? expiry,
    String? qrData,
    BarcodeFormat barcodeFormat = BarcodeFormat.code128,
    PaperProfile? preferredProfile,
  }) {
    final sections = <PrintSection>[];

    sections.add(PrintSection.items([
      PrintItemRowData(
        name: productName,
        sku: sku,
        quantity: 1.0,
        unitPriceFormatted: priceFormatted,
        totalPriceFormatted: priceFormatted,
        variant: variant,
        batch: batch,
        expiry: expiry,
      ),
    ]));

    if (barcode.isNotEmpty) {
      sections.add(PrintSection.barcode(barcode, format: barcodeFormat));
    }

    if (qrData != null && qrData.isNotEmpty) {
      sections.add(PrintSection.qrCode(qrData));
    }

    return PrintDocument(
      documentType: PrintDocumentType.label,
      documentId: 'LBL-$sku-${DateTime.now().millisecondsSinceEpoch}',
      title: 'ملصق $productName',
      businessId: businessId,
      branchId: branchId,
      sections: sections,
      preferredPaperProfile: preferredProfile ?? PaperProfile.label(),
      metadata: {
        'sku': sku,
        'barcode': barcode,
      },
      createdAt: DateTime.now(),
    );
  }

  /// بناء وثيقة تقرير رسمي (A4 / A5)
  PrintDocument buildReportDocument({
    required String title,
    required String reportId,
    required String businessId,
    required String branchId,
    required String businessName,
    required String branchName,
    required List<PrintSection> bodySections,
    PaperProfile? preferredProfile,
    String? footerMessage,
  }) {
    final sections = <PrintSection>[];

    sections.add(PrintSection.header(title));
    sections.add(PrintSection.businessInfo(businessName: businessName));
    sections.add(PrintSection.branchInfo(branchName: branchName));
    sections.add(PrintSection(
      type: PrintSectionType.keyValue,
      keyValues: [
        PrintKeyValueData(key: 'رقم التقرير', value: reportId),
        PrintKeyValueData(
          key: 'تاريخ الإنشاء',
          value: DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
        ),
      ],
    ));
    sections.add(PrintSection.divider('='));
    sections.addAll(bodySections);
    sections.add(PrintSection.divider('='));
    sections.add(PrintSection.footer(footerMessage ?? 'نهاية التقرير - نظام مدار'));

    return PrintDocument(
      documentType: PrintDocumentType.report,
      documentId: reportId,
      title: title,
      businessId: businessId,
      branchId: branchId,
      sections: sections,
      preferredPaperProfile: preferredProfile ?? PaperProfile.a4(),
      createdAt: DateTime.now(),
    );
  }
}
