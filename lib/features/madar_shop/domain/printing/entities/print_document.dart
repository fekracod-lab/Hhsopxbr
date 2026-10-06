// وثيقة الطباعة المجردة المستقلة عن نماذج المبيعات (MADAR SHOP Print Document Entity)
// Pure Dart — Zero UI Dependencies

import '../enums/print_document_type.dart';
import '../value_objects/paper_profile.dart';
import 'print_section.dart';

class PrintDocument {
  final PrintDocumentType documentType;
  final String documentId;
  final String title;
  final String businessId;
  final String branchId;
  final List<PrintSection> sections;
  final PaperProfile? preferredPaperProfile;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const PrintDocument({
    required this.documentType,
    required this.documentId,
    required this.title,
    required this.businessId,
    required this.branchId,
    required this.sections,
    this.preferredPaperProfile,
    this.metadata = const {},
    required this.createdAt,
  });

  bool get hasSections => sections.isNotEmpty;
  int get sectionsCount => sections.length;

  bool get containsCutSection =>
      sections.any((s) => s.type == PrintSectionType.paperCut);

  bool get containsDrawerKickSection =>
      sections.any((s) => s.type == PrintSectionType.cashDrawerKick);

  PrintDocument copyWith({
    PrintDocumentType? documentType,
    String? documentId,
    String? title,
    String? businessId,
    String? branchId,
    List<PrintSection>? sections,
    PaperProfile? preferredPaperProfile,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return PrintDocument(
      documentType: documentType ?? this.documentType,
      documentId: documentId ?? this.documentId,
      title: title ?? this.title,
      businessId: businessId ?? this.businessId,
      branchId: branchId ?? this.branchId,
      sections: sections ?? this.sections,
      preferredPaperProfile: preferredPaperProfile ?? this.preferredPaperProfile,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'PrintDocument(type: $documentType, id: $documentId, sections: ${sections.length})';
}
