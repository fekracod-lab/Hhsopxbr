// مصيّر إيصالات 80 ملم الحرارية المستجيبة (MADAR SHOP 80mm Thermal Responsive Renderer)
// Pure Dart — Zero UI Dependencies

import 'dart:convert';

import '../../../domain/printing/entities/print_document.dart';
import '../../../domain/printing/entities/print_section.dart';
import '../../../domain/printing/enums/section_alignment.dart';
import '../../../domain/printing/value_objects/paper_profile.dart';
import '../../../domain/printing/value_objects/printer_capabilities.dart';
import '../../../domain/printing/value_objects/rendered_payload.dart';
import 'print_renderer.dart';

class Thermal80mmRenderer implements PrintRenderer {
  const Thermal80mmRenderer();

  @override
  RenderedPayload render({
    required PrintDocument document,
    required PaperProfile profile,
    PrinterCapabilities capabilities = const PrinterCapabilities(),
  }) {
    final cols = profile.maxCharsPerLine > 0 ? profile.maxCharsPerLine : 48;
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
          if (section.keyValues != null) {
            for (final kv in section.keyValues!) {
              buffer.writeln(_formatTwoColumn('${kv.key}:', kv.value, cols));
            }
          }
          break;

        case PrintSectionType.divider:
          final char = (section.text != null && section.text!.isNotEmpty) ? section.text![0] : '=';
          buffer.writeln(char * cols);
          break;

        case PrintSectionType.itemRow:
          if (section.items != null) {
            // Responsive multi-column layout for 80mm:
            // Col 1: Item Name (22 cols)
            // Col 2: Qty (6 cols)
            // Col 3: Unit Price (10 cols)
            // Col 4: Total (10 cols)
            // Total = 48 cols
            buffer.writeln(_format4Columns('الصنف', 'الكمية', 'السعر', 'المجموع', cols));
            buffer.writeln('-' * cols);

            for (final it in section.items!) {
              final qtyStr = it.quantity == it.quantity.toInt()
                  ? it.quantity.toInt().toString()
                  : it.quantity.toStringAsFixed(2);

              buffer.writeln(_format4Columns(
                it.name,
                qtyStr,
                it.unitPriceFormatted,
                it.totalPriceFormatted,
                cols,
              ));

              if (it.discountFormatted != null && it.discountFormatted != '0') {
                buffer.writeln(_formatTwoColumn('  (خصم ترويجي للبند)', '-${it.discountFormatted}', cols));
              }
            }
          }
          break;

        case PrintSectionType.totals:
        case PrintSectionType.paymentRow:
        case PrintSectionType.keyValue:
          if (section.keyValues != null) {
            for (final kv in section.keyValues!) {
              buffer.writeln(_formatTwoColumn(kv.key, kv.value, cols));
            }
          }
          break;

        case PrintSectionType.barcode:
          if (section.barcodeData != null) {
            if (capabilities.barcode) {
              buffer.writeln(_alignText('[BARCODE: ${section.barcodeData}]', cols, SectionAlignment.center));
            } else {
              buffer.writeln(_alignText('BARCODE: ${section.barcodeData}', cols, SectionAlignment.center));
            }
          }
          break;

        case PrintSectionType.qrCode:
          if (section.barcodeData != null) {
            if (capabilities.qr) {
              buffer.writeln(_alignText('[QR-CODE: ${section.barcodeData}]', cols, SectionAlignment.center));
            } else {
              buffer.writeln(_alignText('QR: ${section.barcodeData}', cols, SectionAlignment.center));
            }
          }
          break;

        case PrintSectionType.footer:
        case PrintSectionType.customText:
          final txt = section.text ?? '';
          for (final line in _wrapText(txt, cols)) {
            buffer.writeln(_alignText(line, cols, section.alignment));
          }
          break;

        case PrintSectionType.cashDrawerKick:
          if (capabilities.drawer && profile.supportsDrawer) {
            hasDrawer = true;
          }
          break;

        case PrintSectionType.paperCut:
          if (capabilities.cut && profile.supportsCut) {
            hasCut = true;
          }
          break;
      }
    }

    buffer.writeln();
    buffer.writeln();

    final plainText = buffer.toString();
    final rawBytes = utf8.encode(plainText);
    final linesCount = plainText.split('\n').length;

    return RenderedPayload(
      rawBytes: rawBytes,
      plainText: plainText,
      linesCount: linesCount,
      maxColumns: cols,
      paperProfile: profile,
      hasCutCommand: hasCut,
      hasDrawerKickCommand: hasDrawer,
      metadata: {
        'renderer': 'Thermal80mmRenderer',
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

  String _format4Columns(String col1, String col2, String col3, String col4, int totalWidth) {
    // Dynamic width breakdown based on totalWidth (standard 48 cols):
    // Name: ~46%, Qty: ~14%, Price: ~20%, Total: ~20%
    final c2Width = 6;
    final c3Width = 10;
    final c4Width = 11;
    final c1Width = totalWidth - (c2Width + c3Width + c4Width);

    final truncatedCol1 = col1.length > c1Width
        ? '${col1.substring(0, c1Width - 2)}..'
        : col1.padRight(c1Width);

    final paddedCol2 = col2.padLeft(c2Width);
    final paddedCol3 = col3.padLeft(c3Width);
    final paddedCol4 = col4.padLeft(c4Width);

    return '$truncatedCol1$paddedCol2$paddedCol3$paddedCol4';
  }

  List<String> _wrapText(String text, int width) {
    if (text.length <= width) return [text];
    final lines = <String>[];
    final words = text.split(' ');
    var currentLine = '';

    for (final word in words) {
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if (currentLine.length + 1 + word.length <= width) {
        currentLine += ' $word';
      } else {
        lines.add(currentLine);
        currentLine = word;
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines;
  }
}
