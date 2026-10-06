// مصيّر إيصالات 58 ملم الحرارية (MADAR SHOP 58mm Thermal Renderer)
// Pure Dart — Zero UI Dependencies

import 'dart:convert';

import '../../../domain/printing/entities/print_document.dart';
import '../../../domain/printing/entities/print_section.dart';
import '../../../domain/printing/enums/section_alignment.dart';
import '../../../domain/printing/value_objects/paper_profile.dart';
import '../../../domain/printing/value_objects/printer_capabilities.dart';
import '../../../domain/printing/value_objects/rendered_payload.dart';
import 'print_renderer.dart';

class Thermal58mmRenderer implements PrintRenderer {
  const Thermal58mmRenderer();

  @override
  RenderedPayload render({
    required PrintDocument document,
    required PaperProfile profile,
    PrinterCapabilities capabilities = const PrinterCapabilities(),
  }) {
    final cols = profile.maxCharsPerLine > 0 ? profile.maxCharsPerLine : 32;
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
          final char = (section.text != null && section.text!.isNotEmpty) ? section.text![0] : '-';
          buffer.writeln(char * cols);
          break;

        case PrintSectionType.itemRow:
          if (section.items != null) {
            // Header for 58mm items
            buffer.writeln(_formatTwoColumn('الصنف / الكمية', 'الإجمالي', cols));
            buffer.writeln('-' * cols);

            for (final it in section.items!) {
              // Wrap long item names
              final nameLines = _wrapText(it.name, cols);
              for (final line in nameLines) {
                buffer.writeln(line);
              }
              // Quantity x Unit Price on left, Total on right
              final qtyStr = it.quantity == it.quantity.toInt()
                  ? it.quantity.toInt().toString()
                  : it.quantity.toStringAsFixed(2);
              final subDetail = '$qtyStr x ${it.unitPriceFormatted}';
              buffer.writeln(_formatTwoColumn('  $subDetail', it.totalPriceFormatted, cols));

              if (it.discountFormatted != null && it.discountFormatted != '0') {
                buffer.writeln(_formatTwoColumn('  (خصم)', '-${it.discountFormatted}', cols));
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
          final txt = section.text ?? '';
          for (final line in _wrapText(txt, cols)) {
            buffer.writeln(_alignText(line, cols, section.alignment));
          }
          break;

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

    // Extra line feeds at the end of thermal receipt
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
        'renderer': 'Thermal58mmRenderer',
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
      // Truncate or trim left with ellipsis to fit single line
      final truncatedLeft = '${left.substring(0, available - 2)}..';
      return truncatedLeft.padRight(available) + right;
    }

    return left.padRight(available) + right;
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
