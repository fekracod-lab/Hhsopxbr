// واجهة مصير وثائق الطباعة (MADAR SHOP Print Renderer Base Contract)
// Pure Dart — Zero UI Dependencies

import '../../../domain/printing/entities/print_document.dart';
import '../../../domain/printing/value_objects/paper_profile.dart';
import '../../../domain/printing/value_objects/printer_capabilities.dart';
import '../../../domain/printing/value_objects/rendered_payload.dart';

abstract class PrintRenderer {
  RenderedPayload render({
    required PrintDocument document,
    required PaperProfile profile,
    PrinterCapabilities capabilities = const PrinterCapabilities(),
  });
}
