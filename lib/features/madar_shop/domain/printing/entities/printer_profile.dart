// ملف تخصيص الطابعة للفرع والمستندات (MADAR SHOP Printer Profile Entity)
// Pure Dart — Zero UI Dependencies

import '../enums/auto_print_policy.dart';
import '../enums/print_document_type.dart';
import '../value_objects/paper_profile.dart';

class PrinterProfile {
  final String id;
  final String businessId;
  final String branchId;
  final String printerId;
  final String name;
  final PrintDocumentType targetDocumentType;
  final PaperProfile paperProfile;
  final AutoPrintPolicy autoPrintPolicy;
  final int copies;
  final bool cutAfterPrint;
  final bool openDrawerOnCash;
  final bool isDefault;
  final Map<String, dynamic> metadata;

  const PrinterProfile({
    required this.id,
    required this.businessId,
    required this.branchId,
    required this.printerId,
    required this.name,
    this.targetDocumentType = PrintDocumentType.saleReceipt,
    required this.paperProfile,
    this.autoPrintPolicy = AutoPrintPolicy.saleOnly,
    this.copies = 1,
    this.cutAfterPrint = true,
    this.openDrawerOnCash = true,
    this.isDefault = false,
    this.metadata = const {},
  });

  PrintDocumentType get documentType => targetDocumentType;
  bool get isActive => true;

  PrinterProfile copyWith({
    String? name,
    String? printerId,
    PrintDocumentType? targetDocumentType,
    PaperProfile? paperProfile,
    AutoPrintPolicy? autoPrintPolicy,
    int? copies,
    bool? cutAfterPrint,
    bool? openDrawerOnCash,
    bool? isDefault,
    Map<String, dynamic>? metadata,
  }) {
    return PrinterProfile(
      id: id,
      businessId: businessId,
      branchId: branchId,
      printerId: printerId ?? this.printerId,
      name: name ?? this.name,
      targetDocumentType: targetDocumentType ?? this.targetDocumentType,
      paperProfile: paperProfile ?? this.paperProfile,
      autoPrintPolicy: autoPrintPolicy ?? this.autoPrintPolicy,
      copies: copies ?? this.copies,
      cutAfterPrint: cutAfterPrint ?? this.cutAfterPrint,
      openDrawerOnCash: openDrawerOnCash ?? this.openDrawerOnCash,
      isDefault: isDefault ?? this.isDefault,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          businessId == other.businessId &&
          branchId == other.branchId;

  @override
  int get hashCode => id.hashCode ^ businessId.hashCode ^ branchId.hashCode;

  @override
  String toString() =>
      'PrinterProfile(id: $id, printer: $printerId, doc: $targetDocumentType, copies: $copies)';
}
