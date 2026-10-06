// مستودع إشعارات الدائن للموردين في الذاكرة (MADAR SHOP Memory Supplier Credit Note Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/returns/entities/supplier_credit_note.dart';
import '../../../domain/returns/repositories/i_supplier_credit_note_repository.dart';

class MemorySupplierCreditNoteRepository implements ISupplierCreditNoteRepository {
  final Map<String, SupplierCreditNote> _store = {};

  @override
  Future<SupplierCreditNote?> getCreditNoteById({
    required String businessId,
    required String creditNoteId,
  }) async {
    final note = _store[creditNoteId];
    if (note != null && note.businessId == businessId) return note;
    return null;
  }

  @override
  Future<List<SupplierCreditNote>> getCreditNotesForSupplier({
    required String businessId,
    required String supplierId,
  }) async {
    return _store.values
        .where((n) => n.businessId == businessId && n.supplierId == supplierId)
        .toList();
  }

  @override
  Future<void> saveCreditNote(SupplierCreditNote creditNote) async {
    _store[creditNote.id] = creditNote;
  }

  void clear() => _store.clear();
}
