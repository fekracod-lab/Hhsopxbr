// مصيّر ملصقات الباركود والمنتجات (MADAR SHOP Label Document Renderer)
// Pure Dart — Zero UI Dependencies

import 'dart:convert';

import '../../../domain/printing/entities/print_document.dart';
import '../../../domain/printing/entities/print_section.dart';
import '../../../domain/printing/enums/barcode_format.dart';
import '../../../domain/printing/enums/section_alignment.dart';
import '../../../domain/printing/value_objects/paper_profile.dart';
import '../../../domain/printing/value_objects/printer_capabilities.dart';
import '../../../domain/printing/value_objects/rendered_payload.dart';
import 'print_renderer.dart';

class LabelDocumentRenderer implements PrintRenderer {
  const LabelDocumentRenderer();

  @override
  RenderedPayload render({
    required PrintDocument document,
    required PaperProfile profile,
    PrinterCapabilities capabilities = const PrinterCapabilities(),
  }) {
    final cols = profile.maxCharsPerLine > 0 ? profile.maxCharsPerLine : 28;
    final buffer = StringBuffer();
    bool hasCut = false;
    bool hasDrawer = false;

    for (final section in document.sections) {
      switch (section.type) {
        case PrintSectionType.header:
          final txt = section.text ?? '';
          buffer.writeln(_alignText(txt, cols, section.alignment));
          break;

        case PrintSectionType.businessInfo:
        case PrintSectionType.branchInfo:
        case PrintSectionType.customerInfo:
        case PrintSectionType.keyValue:
          if (section.keyValues != null) {
            for (final kv in section.keyValues!) {
              buffer.writeln(_alignText('${kv.key}: ${kv.value}', cols, section.alignment));
            }
          }
          break;

        case PrintSectionType.divider:
          final char = (section.text != null && section.text!.isNotEmpty) ? section.text![0] : '-';
          buffer.writeln(char * cols);
          break;

        case PrintSectionType.itemRow:
          if (section.items != null) {
            for (final it in section.items!) {
              buffer.writeln(_alignText(it.name, cols, SectionAlignment.center));
              final details = <String>[];
              if (it.sku != null && it.sku!.isNotEmpty) details.add('SKU: ${it.sku}');
              if (it.variant != null && it.variant!.isNotEmpty) details.add(it.variant!);
              if (details.isNotEmpty) {
                buffer.writeln(_alignText(details.join(' | '), cols, SectionAlignment.center));
              }

              // Price & Qty
              buffer.writeln(_alignText('السعر: ${it.priceFormatted}', cols, SectionAlignment.center));

              // Batch / Expiry if present in metadata
              final batch = it.batch;
              final expiry = it.expiry;
              if (batch != null && batch.isNotEmpty) {
                buffer.writeln(_alignText('تشغيلة: $batch', cols, SectionAlignment.center));
              }
              if (expiry != null && expiry.isNotEmpty) {
                buffer.writeln(_alignText('انتهاء: $expiry', cols, SectionAlignment.center));
              }
            }
          }
          break;

        case PrintSectionType.totals:
        case PrintSectionType.paymentRow:
          if (section.keyValues != null) {
            for (final kv in section.keyValues!) {
              buffer.writeln(_alignText('${kv.key}: ${kv.value}', cols, SectionAlignment.center));
            }
          }
          break;

        case PrintSectionType.barcode:
          if (capabilities.barcode) {
            final code = section.barcodeData ?? section.text ?? '';
            final fmt = section.barcodeFormat == BarcodeFormat.ean13 ? 'EAN13' : 'CODE128';
            buffer.writeln(_alignText('[$fmt: $code]', cols, SectionAlignment.center));
            buffer.writeln(_alignText('* $code *', cols, SectionAlignment.center));
          } else {
            // Text fallback if printer lacks barcode capability
            final code = section.barcodeData ?? section.text ?? '';
            buffer.writeln(_alignText('BARCODE: $code', cols, SectionAlignment.center));
          }
          break;

        case PrintSectionType.qrCode:
          if (capabilities.qr) {
            final qr = section.qrData ?? section.text ?? '';
            buffer.writeln(_alignText('[QR-CODE: $qr]', cols, SectionAlignment.center));
          } else {
            final qr = section.qrData ?? section.text ?? '';
            buffer.writeln(_alignText('QR: $qr', cols, SectionAlignment.center));
          }
          break;

        case PrintSectionType.footer:
        case PrintSectionType.customText:
          final txt = section.text ?? '';
          buffer.writeln(_alignText(txt, cols, section.alignment));
          break;

        case PrintSectionType.cashDrawerKick:
          if (capabilities.drawer) {
            hasDrawer = true;
          }
          break;

        case PrintSectionType.paperCut:
          if (capabilities.cut) {
            hasCut = true;
          }
          break;
      }
    }

    final plainText = buffer.toString();
    final rawBytes = utf8.encode(plainText);

    return RenderedPayload(
      rawBytes: rawBytes,
      plainText: plainText,
      characterWidth: cols,
      lineCount: plainText.split('\n').length,
      hasCutCommand: hasCut,
      hasDrawerKick: hasDrawer,
    );
  }

  String _alignText(String text, int width, SectionAlignment alignment) {
    if (text.length >= width) return text;
    final spaces = width - text.length;

    switch (alignment) {
      case SectionAlignment.left:
        return text + (' ' * spaces);
      case SectionAlignment.right:
        return (' ' * spaces) + text;
      case SectionAlignment.center:
        final leftSpaces = spaces ~/ 2;
        final rightSpaces = spaces - leftSpaces;
        return (' ' * leftSpaces) + text + (' ' * rightSpaces);
    }
  }
}
