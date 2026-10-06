// عقد مستودع ملفات تخصيص الطابعات (MADAR SHOP Printer Profile Repository Interface)
// Pure Dart — Zero UI Dependencies

import '../entities/printer_profile.dart';
import '../enums/print_document_type.dart';

abstract class IPrinterProfileRepository {
  Future<void> saveProfile(PrinterProfile profile);

  Future<PrinterProfile?> getProfileById({
    required String businessId,
    required String profileId,
  });

  Future<List<PrinterProfile>> getProfilesForBranch({
    required String businessId,
    required String branchId,
  });

  Future<PrinterProfile?> getProfileForDocument({
    required String businessId,
    required String branchId,
    required PrintDocumentType documentType,
  });

  Future<void> deleteProfile({
    required String businessId,
    required String profileId,
  });
}
