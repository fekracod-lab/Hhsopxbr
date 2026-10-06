// نوع وثيقة الطباعة (MADAR SHOP Print Document Type Enum)
// Pure Dart — Zero UI Dependencies

enum PrintDocumentType {
  saleReceipt,
  returnReceipt,
  purchaseReceipt,
  invoice,
  label,
  report;

  static PrintDocumentType fromString(String? val) {
    if (val == null) return PrintDocumentType.saleReceipt;
    switch (val.trim().toLowerCase()) {
      case 'sale':
      case 'sale_receipt':
        return PrintDocumentType.saleReceipt;
      case 'return':
      case 'return_receipt':
        return PrintDocumentType.returnReceipt;
      case 'purchase':
      case 'purchase_receipt':
        return PrintDocumentType.purchaseReceipt;
      case 'invoice':
      case 'tax_invoice':
        return PrintDocumentType.invoice;
      case 'label':
      case 'barcode_label':
        return PrintDocumentType.label;
      case 'report':
      case 'financial_report':
        return PrintDocumentType.report;
      default:
        return PrintDocumentType.saleReceipt;
    }
  }

  String toDbString() {
    switch (this) {
      case PrintDocumentType.saleReceipt:
        return 'sale_receipt';
      case PrintDocumentType.returnReceipt:
        return 'return_receipt';
      case PrintDocumentType.purchaseReceipt:
        return 'purchase_receipt';
      case PrintDocumentType.invoice:
        return 'invoice';
      case PrintDocumentType.label:
        return 'label';
      case PrintDocumentType.report:
        return 'report';
    }
  }

  String get displayNameAr {
    switch (this) {
      case PrintDocumentType.saleReceipt:
        return 'إيصال مبيعات (فاتورة زبون)';
      case PrintDocumentType.returnReceipt:
        return 'إيصال مرتجع مبيعات';
      case PrintDocumentType.purchaseReceipt:
        return 'إيصال استلام مشتريات';
      case PrintDocumentType.invoice:
        return 'فاتورة ضريبية رسمية';
      case PrintDocumentType.label:
        return 'ملصق صنف / باركود';
      case PrintDocumentType.report:
        return 'تقرير مالي / تقييم مخزني';
    }
  }
}
