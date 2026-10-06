// عقد مستودع إشعارات الدائن للموردين (MADAR SHOP Supplier Credit Note Repository Interface)
// Pure Dart — Zero UI Dependencies

import '../entities/supplier_credit_note.dart';

abstract class ISupplierCreditNoteRepository {
  Future<SupplierCreditNote?> getCreditNoteById({
    required String businessId,
    required String creditNoteId,
  });

  Future<List<SupplierCreditNote>> getCreditNotesForSupplier({
    required String businessId,
    required String supplierId,
  });

  Future<void> saveCreditNote(SupplierCreditNote creditNote);
}
