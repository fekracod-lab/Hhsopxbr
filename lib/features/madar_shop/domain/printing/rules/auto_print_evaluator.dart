// مقيّم سياسة الطباعة التلقائية (MADAR SHOP Auto Print Evaluator)
// Pure Dart — Zero UI Dependencies

import '../enums/auto_print_policy.dart';
import '../enums/print_document_type.dart';

class AutoPrintEvaluator {
  /// التحقق مما إذا كان المستند يجب أن يُطبع تلقائياً وفق السياسة المعتمدة
  static bool shouldAutoPrint({
    required AutoPrintPolicy policy,
    required PrintDocumentType documentType,
    Map<PrintDocumentType, bool>? customRules,
  }) {
    switch (policy) {
      case AutoPrintPolicy.off:
        return false;

      case AutoPrintPolicy.saleOnly:
        return documentType == PrintDocumentType.saleReceipt ||
            documentType == PrintDocumentType.invoice;

      case AutoPrintPolicy.saleAndReturn:
        return documentType == PrintDocumentType.saleReceipt ||
            documentType == PrintDocumentType.invoice ||
            documentType == PrintDocumentType.returnReceipt;

      case AutoPrintPolicy.allDocuments:
        return true;

      case AutoPrintPolicy.custom:
        if (customRules != null && customRules.containsKey(documentType)) {
          return customRules[documentType]!;
        }
        return false;
    }
  }
}
