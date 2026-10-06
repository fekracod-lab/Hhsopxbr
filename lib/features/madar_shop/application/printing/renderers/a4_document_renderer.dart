// مصيّر مستندات وفواتير A4 (MADAR SHOP A4 Document Renderer)
// Pure Dart — Zero UI Dependencies

import 'dart:convert';

import '../../../domain/printing/entities/print_document.dart';
import '../../../domain/printing/entities/print_section.dart';
import '../../../domain/printing/enums/section_alignment.dart';
import '../../../domain/printing/value_objects/paper_profile.dart';
import '../../../domain/printing/value_objects/printer_capabilities.dart';
import '../../../domain/printing/value_objects/rendered_payload.dart';
import 'print_renderer.dart';

class A4DocumentRenderer implements PrintRenderer {
  const A4DocumentRenderer();

  static const int defaultLinesPerPage = 55;

  @override
  RenderedPayload render({
    required PrintDocument document,
    required PaperProfile profile,
    PrinterCapabilities capabilities = const PrinterCapabilities(),
  }) {
    final cols = profile.maxCharsPerLine > 0 ? profile.maxCharsPerLine : 80;
    final lines = <String>[];

    // Build raw document lines
    for (final section in document.sections) {
      switch (section.type) {
        case PrintSectionType.header:
          lines.add('=' * cols);
          lines.add(_alignText(section.text ?? '', cols, section.alignment));
          lines.add('=' * cols);
          lines.add('');
          break;

        case PrintSectionType.businessInfo:
        case PrintSectionType.branchInfo:
        case PrintSectionType.customerInfo:
          if (section.keyValues != null) {
            lines.add('+${'-' * (cols - 2)}+');
            for (final kv in section.keyValues!) {
              lines.add('| ${_formatTwoColumn('${kv.key}:', kv.value, cols - 4)} |');
            }
            lines.add('+${'-' * (cols - 2)}+');
            lines.add('');
          }
          break;

        case PrintSectionType.divider:
          final char = (section.text != null && section.text!.isNotEmpty) ? section.text![0] : '-';
          lines.add(char * cols);
          break;

        case PrintSectionType.itemRow:
          if (section.items != null) {
            lines.add('+${'-' * (cols - 2)}+');
            lines.add('| ${_formatA4ItemRow('م', 'اسم الصنف / البند', 'الكمية', 'سعر الوحدة', 'المجموع', cols - 4)} |');
            lines.add('+${'=' * (cols - 2)}+');

            int idx = 1;
            for (final it in section.items!) {
              final qtyStr = it.quantity == it.quantity.toInt()
                  ? it.quantity.toInt().toString()
                  : it.quantity.toStringAsFixed(2);

              lines.add('| ${_formatA4ItemRow(
                idx.toString(),
                it.name,
                qtyStr,
                it.unitPriceFormatted,
                it.totalPriceFormatted,
                cols - 4,
              )} |');
              idx++;
            }
            lines.add('+${'-' * (cols - 2)}+');
            lines.add('');
          }
          break;

        case PrintSectionType.totals:
        case PrintSectionType.paymentRow:
        case PrintSectionType.keyValue:
          if (section.keyValues != null) {
            for (final kv in section.keyValues!) {
              lines.add(_alignText(_formatTwoColumn(kv.key, kv.value, 40), cols, SectionAlignment.right));
            }
            lines.add('');
          }
          break;

        case PrintSectionType.barcode:
          if (capabilities.barcode && section.barcodeData != null) {
            lines.add(_alignText('[BARCODE A4: ${section.barcodeData}]', cols, SectionAlignment.center));
            lines.add('');
          }
          break;

        case PrintSectionType.qrCode:
          if (capabilities.qr && section.barcodeData != null) {
            lines.add(_alignText('[QR CODE A4: ${section.barcodeData}]', cols, SectionAlignment.center));
            lines.add('');
          }
          break;

        case PrintSectionType.footer:
        case PrintSectionType.customText:
          final txt = section.text ?? '';
          lines.add(_alignText(txt, cols, section.alignment));
          lines.add('');
          break;

        case PrintSectionType.cashDrawerKick:
        case PrintSectionType.paperCut:
          // Not applicable for A4 laser/inkjet
          break;
      }
    }

    // Paginate with page numbers
    final paginatedText = _paginate(lines, cols, defaultLinesPerPage);
    final rawBytes = utf8.encode(paginatedText);
    final totalLines = paginatedText.split('\n').length;

    return RenderedPayload(
      rawBytes: rawBytes,
      plainText: paginatedText,
      linesCount: totalLines,
      maxColumns: cols,
      paperProfile: profile,
      hasCutCommand: false,
      hasDrawerKickCommand: false,
      metadata: {
        'renderer': 'A4DocumentRenderer',
        'documentId': document.documentId,
        'documentType': document.documentType.name,
      },
    );
  }

  String _paginate(List<String> lines, int cols, int linesPerPage) {
    if (lines.isEmpty) return '';

    final pages = <List<String>>[];
    var currentPage = <String>[];

    for (final line in lines) {
      if (currentPage.length >= linesPerPage - 3) {
        pages.add(currentPage);
        currentPage = [];
      }
      currentPage.add(line);
    }
    if (currentPage.isNotEmpty) {
      pages.add(currentPage);
    }

    final totalPages = pages.length;
    final buffer = StringBuffer();

    for (int p = 0; p < totalPages; p++) {
      final pageLines = pages[p];
      for (final l in pageLines) {
        buffer.writeln(l);
      }
      // Fill remaining page lines up to linesPerPage - 2
      final remaining = (linesPerPage - 2) - pageLines.length;
      for (int i = 0; i < remaining; i++) {
        buffer.writeln();
      }
      // Footer page numbering
      final pageNumStr = '--- صفحة ${p + 1} من $totalPages ---';
      buffer.writeln(_alignText(pageNumStr, cols, SectionAlignment.center));
      if (p < totalPages - 1) {
        buffer.writeln('\f'); // Form feed page break
      }
    }

    return buffer.toString();
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

  String _formatA4ItemRow(String idx, String name, String qty, String price, String total, int width) {
    // Column widths: idx (4), name (available), qty (8), price (12), total (14)
    const idxWidth = 4;
    const qtyWidth = 8;
    const priceWidth = 12;
    const totalWidth = 14;
    final nameWidth = width - (idxWidth + qtyWidth + priceWidth + totalWidth);

    final pIdx = idx.padRight(idxWidth);
    final pName = name.length > nameWidth
        ? '${name.substring(0, nameWidth - 2)}..'
        : name.padRight(nameWidth);
    final pQty = qty.padLeft(qtyWidth);
    final pPrice = price.padLeft(priceWidth);
    final pTotal = total.padLeft(totalWidth);

    return '$pIdx$pName$pQty$pPrice$pTotal';
  }
}
