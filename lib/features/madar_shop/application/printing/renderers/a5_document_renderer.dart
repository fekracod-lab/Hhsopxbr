// مصيّر مستندات A5 المصغرة (MADAR SHOP A5 Compact Document Renderer)
// Pure Dart — Zero UI Dependencies

import 'dart:convert';

import '../../../domain/printing/entities/print_document.dart';
import '../../../domain/printing/entities/print_section.dart';
import '../../../domain/printing/enums/section_alignment.dart';
import '../../../domain/printing/value_objects/paper_profile.dart';
import '../../../domain/printing/value_objects/printer_capabilities.dart';
import '../../../domain/printing/value_objects/rendered_payload.dart';
import 'print_renderer.dart';

class A5DocumentRenderer implements PrintRenderer {
  const A5DocumentRenderer();

  static const int defaultLinesPerPage = 38;

  @override
  RenderedPayload render({
    required PrintDocument document,
    required PaperProfile profile,
    PrinterCapabilities capabilities = const PrinterCapabilities(),
  }) {
    final cols = profile.maxCharsPerLine > 0 ? profile.maxCharsPerLine : 60;
    final lines = <String>[];

    for (final section in document.sections) {
      switch (section.type) {
        case PrintSectionType.header:
          lines.add('=' * cols);
          lines.add(_alignText(section.text ?? '', cols, section.alignment));
          lines.add('=' * cols);
          break;

        case PrintSectionType.businessInfo:
        case PrintSectionType.branchInfo:
        case PrintSectionType.customerInfo:
          if (section.keyValues != null) {
            for (final kv in section.keyValues!) {
              lines.add(_formatTwoColumn('${kv.key}:', kv.value, cols));
            }
            lines.add('-' * cols);
          }
          break;

        case PrintSectionType.divider:
          final char = (section.text != null && section.text!.isNotEmpty) ? section.text![0] : '-';
          lines.add(char * cols);
          break;

        case PrintSectionType.itemRow:
          if (section.items != null) {
            lines.add(_formatA5ItemRow('الصنف', 'الكمية', 'السعر', 'المجموع', cols));
            lines.add('-' * cols);

            for (final it in section.items!) {
              final qtyStr = it.quantity == it.quantity.toInt()
                  ? it.quantity.toInt().toString()
                  : it.quantity.toStringAsFixed(2);

              lines.add(_formatA5ItemRow(
                it.name,
                qtyStr,
                it.unitPriceFormatted,
                it.totalPriceFormatted,
                cols,
              ));
            }
            lines.add('-' * cols);
          }
          break;

        case PrintSectionType.totals:
        case PrintSectionType.paymentRow:
        case PrintSectionType.keyValue:
          if (section.keyValues != null) {
            for (final kv in section.keyValues!) {
              lines.add(_formatTwoColumn(kv.key, kv.value, cols));
            }
          }
          break;

        case PrintSectionType.barcode:
          if (capabilities.barcode && section.barcodeData != null) {
            lines.add(_alignText('[BARCODE A5: ${section.barcodeData}]', cols, SectionAlignment.center));
          }
          break;

        case PrintSectionType.qrCode:
          if (capabilities.qr && section.barcodeData != null) {
            lines.add(_alignText('[QR CODE A5: ${section.barcodeData}]', cols, SectionAlignment.center));
          }
          break;

        case PrintSectionType.footer:
        case PrintSectionType.customText:
          final txt = section.text ?? '';
          lines.add(_alignText(txt, cols, section.alignment));
          break;

        case PrintSectionType.cashDrawerKick:
        case PrintSectionType.paperCut:
          break;
      }
    }

    final plainText = lines.join('\n');
    final rawBytes = utf8.encode(plainText);

    return RenderedPayload(
      rawBytes: rawBytes,
      plainText: plainText,
      linesCount: lines.length,
      maxColumns: cols,
      paperProfile: profile,
      hasCutCommand: false,
      hasDrawerKickCommand: false,
      metadata: {
        'renderer': 'A5DocumentRenderer',
        'documentId': document.documentId,
        'documentType': document.documentType.name,
      },
    );
  }

  String _alignText(String text, int width, SectionAlignment alignment) {
    if (text.length >= width) return text;
    final remaining = width - text.length;

    switch (alignment) {
      case SectionAlignment.left:
        return text.padRight(width);
      case SectionAlignment.right:
        return text.padLeft(width);
      case SectionAlignment.center:
        final leftPad = remaining ~/ 2;
        final rightPad = remaining - leftPad;
        return ' ' * leftPad + text + ' ' * rightPad;
    }
  }

  String _formatTwoColumn(String left, String right, int width) {
    final available = width - right.length;
    if (available <= 0) return '$left $right';

    if (left.length > available - 1) {
      final truncatedLeft = '${left.substring(0, available - 2)}..';
      return truncatedLeft.padRight(available) + right;
    }

    return left.padRight(available) + right;
  }

  String _formatA5ItemRow(String name, String qty, String price, String total, int width) {
    const qtyWidth = 6;
    const priceWidth = 10;
    const totalWidth = 12;
    final nameWidth = width - (qtyWidth + priceWidth + totalWidth);

    final pName = name.length > nameWidth
        ? '${name.substring(0, nameWidth - 2)}..'
        : name.padRight(nameWidth);
    final pQty = qty.padLeft(qtyWidth);
    final pPrice = price.padLeft(priceWidth);
    final pTotal = total.padLeft(totalWidth);

    return '$pName$pQty$pPrice$pTotal';
  }
}
