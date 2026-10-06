// مستودع ملفات تخصيص الطباعة بالذاكرة (MADAR SHOP In-Memory Printer Profile Repository)
// Pure Dart — Zero UI Dependencies

import '../../../domain/printing/contracts/i_printer_profile_repository.dart';
import '../../../domain/printing/entities/printer_profile.dart';
import '../../../domain/printing/enums/print_document_type.dart';

class MemoryPrinterProfileRepository implements IPrinterProfileRepository {
  final Map<String, PrinterProfile> _storage = {};

  @override
  Future<void> saveProfile(PrinterProfile profile) async {
    _storage['${profile.businessId}_${profile.id}'] = profile;
  }

  @override
  Future<PrinterProfile?> getProfileById({
    required String businessId,
    required String profileId,
  }) async {
    return _storage['${businessId}_$profileId'];
  }

  @override
  Future<List<PrinterProfile>> getProfilesForBranch({
    required String businessId,
    required String branchId,
  }) async {
    return _storage.values
        .where((p) => p.businessId == businessId && p.branchId == branchId)
        .toList();
  }

  @override
  Future<PrinterProfile?> getProfileForDocument({
    required String businessId,
    required String branchId,
    required PrintDocumentType documentType,
  }) async {
    final branchProfiles = await getProfilesForBranch(
      businessId: businessId,
      branchId: branchId,
    );

    // Exact document match first
    for (final p in branchProfiles) {
      if (p.documentType == documentType && p.isActive) {
        return p;
      }
    }

    return null;
  }

  @override
  Future<void> deleteProfile({
    required String businessId,
    required String profileId,
  }) async {
    _storage.remove('${businessId}_$profileId');
  }

  void clear() {
    _storage.clear();
  }
}
