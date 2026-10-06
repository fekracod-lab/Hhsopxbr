// أجزاء ومكونات وثيقة الطباعة المجردة (MADAR SHOP Print Section Entity)
// Pure Dart — Zero UI Dependencies

import '../enums/barcode_format.dart';
import '../enums/section_alignment.dart';

enum PrintSectionType {
  header,
  businessInfo,
  branchInfo,
  divider,
  keyValue,
  itemRow,
  totals,
  paymentRow,
  barcode,
  qrCode,
  customerInfo,
  footer,
  customText,
  cashDrawerKick,
  paperCut,
}

class PrintItemRowData {
  final String name;
  final String? sku;
  final double quantity;
  final String unitPriceFormatted;
  final String totalPriceFormatted;
  final String? discountFormatted;
  final String? taxFormatted;
  final String? notes;
  final String? variant;
  final String? batch;
  final String? expiry;

  const PrintItemRowData({
    required this.name,
    this.sku,
    required this.quantity,
    required this.unitPriceFormatted,
    required this.totalPriceFormatted,
    this.discountFormatted,
    this.taxFormatted,
    this.notes,
    this.variant,
    this.batch,
    this.expiry,
  });

  String get priceFormatted => unitPriceFormatted;
}

class PrintKeyValueData {
  final String key;
  final String value;
  final bool isBold;

  const PrintKeyValueData({
    required this.key,
    required this.value,
    this.isBold = false,
  });
}

class PrintSection {
  final PrintSectionType type;
  final String? text;
  final SectionAlignment alignment;
  final bool isBold;
  final bool isDoubleHeight;
  final bool isDoubleWidth;
  final List<PrintItemRowData>? items;
  final List<PrintKeyValueData>? keyValues;
  final String? barcodeData;
  final BarcodeFormat? barcodeFormat;
  final Map<String, dynamic> metadata;

  const PrintSection({
    required this.type,
    this.text,
    this.alignment = SectionAlignment.left,
    this.isBold = false,
    this.isDoubleHeight = false,
    this.isDoubleWidth = false,
    this.items,
    this.keyValues,
    this.barcodeData,
    this.barcodeFormat,
    this.metadata = const {},
  });

  String? get qrData => barcodeData;

  factory PrintSection.header(String text, {SectionAlignment alignment = SectionAlignment.center}) {
    return PrintSection(
      type: PrintSectionType.header,
      text: text,
      alignment: alignment,
      isBold: true,
      isDoubleHeight: true,
      isDoubleWidth: true,
    );
  }

  factory PrintSection.businessInfo({
    required String businessName,
    String? taxNumber,
    String? phone,
    String? address,
  }) {
    return PrintSection(
      type: PrintSectionType.businessInfo,
      alignment: SectionAlignment.center,
      keyValues: [
        PrintKeyValueData(key: 'المتجر', value: businessName, isBold: true),
        if (taxNumber != null) PrintKeyValueData(key: 'الرقم الضريبي', value: taxNumber),
        if (phone != null) PrintKeyValueData(key: 'الهاتف', value: phone),
        if (address != null) PrintKeyValueData(key: 'العنوان', value: address),
      ],
    );
  }

  factory PrintSection.branchInfo({
    required String branchName,
    String? branchCode,
    String? cashierName,
    String? terminalId,
  }) {
    return PrintSection(
      type: PrintSectionType.branchInfo,
      alignment: SectionAlignment.left,
      keyValues: [
        PrintKeyValueData(key: 'الفرع', value: branchName),
        if (branchCode != null) PrintKeyValueData(key: 'كود الفرع', value: branchCode),
        if (cashierName != null) PrintKeyValueData(key: 'الكاشير', value: cashierName),
        if (terminalId != null) PrintKeyValueData(key: 'نقطة البيع', value: terminalId),
      ],
    );
  }

  factory PrintSection.divider([String char = '-']) {
    return PrintSection(
      type: PrintSectionType.divider,
      text: char,
      alignment: SectionAlignment.center,
    );
  }

  factory PrintSection.items(List<PrintItemRowData> items) {
    return PrintSection(
      type: PrintSectionType.itemRow,
      items: items,
    );
  }

  factory PrintSection.totals(List<PrintKeyValueData> totals) {
    return PrintSection(
      type: PrintSectionType.totals,
      keyValues: totals,
      alignment: SectionAlignment.right,
      isBold: true,
    );
  }

  factory PrintSection.payments(List<PrintKeyValueData> payments) {
    return PrintSection(
      type: PrintSectionType.paymentRow,
      keyValues: payments,
    );
  }

  factory PrintSection.customerInfo({
    required String name,
    String? phone,
    String? customerId,
  }) {
    return PrintSection(
      type: PrintSectionType.customerInfo,
      keyValues: [
        PrintKeyValueData(key: 'العميل', value: name, isBold: true),
        if (phone != null) PrintKeyValueData(key: 'الهاتف', value: phone),
        if (customerId != null) PrintKeyValueData(key: 'رقم العميل', value: customerId),
      ],
    );
  }

  factory PrintSection.footer(String text) {
    return PrintSection(
      type: PrintSectionType.footer,
      text: text,
      alignment: SectionAlignment.center,
    );
  }

  factory PrintSection.qrCode(String data) {
    return PrintSection(
      type: PrintSectionType.qrCode,
      barcodeData: data,
      barcodeFormat: BarcodeFormat.qrCode,
      alignment: SectionAlignment.center,
    );
  }

  factory PrintSection.barcode(String data, {BarcodeFormat format = BarcodeFormat.code128}) {
    return PrintSection(
      type: PrintSectionType.barcode,
      barcodeData: data,
      barcodeFormat: format,
      alignment: SectionAlignment.center,
    );
  }

  factory PrintSection.cashDrawerKick() {
    return const PrintSection(type: PrintSectionType.cashDrawerKick);
  }

  factory PrintSection.paperCut() {
    return const PrintSection(type: PrintSectionType.paperCut);
  }
}
