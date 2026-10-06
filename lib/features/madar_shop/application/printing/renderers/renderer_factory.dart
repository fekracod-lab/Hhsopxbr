// مصنع مصيرات الطباعة (MADAR SHOP Print Renderer Factory)
// Pure Dart — Zero UI Dependencies

import '../../../domain/printing/enums/paper_profile_type.dart';
import 'a4_document_renderer.dart';
import 'a5_document_renderer.dart';
import 'label_document_renderer.dart';
import 'print_renderer.dart';
import 'thermal_58mm_renderer.dart';
import 'thermal_80mm_renderer.dart';

class RendererFactory {
  const RendererFactory._();

  static const PrintRenderer _thermal58 = Thermal58mmRenderer();
  static const PrintRenderer _thermal80 = Thermal80mmRenderer();
  static const PrintRenderer _a4 = A4DocumentRenderer();
  static const PrintRenderer _a5 = A5DocumentRenderer();
  static const PrintRenderer _label = LabelDocumentRenderer();

  static PrintRenderer getRenderer(PaperProfileType type) {
    switch (type) {
      case PaperProfileType.thermal58mm:
        return _thermal58;
      case PaperProfileType.thermal80mm:
        return _thermal80;
      case PaperProfileType.a4:
        return _a4;
      case PaperProfileType.a5:
        return _a5;
      case PaperProfileType.label:
        return _label;
      case PaperProfileType.custom:
        return _thermal80;
    }
  }
}
