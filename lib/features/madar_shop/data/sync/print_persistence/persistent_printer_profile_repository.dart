// مستودع ملفات تخصيص الطابعات المستدام في قاعدة البيانات المحلية (MADAR SHOP Persistent Printer Profile Repository)
// Pure Dart — Zero UI Dependencies — Integrates with S6 Printing Engine

import '../../../domain/printing/contracts/i_printer_profile_repository.dart';
import '../../../domain/printing/entities/printer_profile.dart';
import '../../../domain/printing/enums/auto_print_policy.dart';
import '../../../domain/printing/enums/paper_profile_type.dart';
import '../../../domain/printing/enums/print_document_type.dart';
import '../../../domain/printing/value_objects/paper_profile.dart';
import '../../../domain/sync/contracts/i_local_database.dart';

class PersistentPrinterProfileRepository implements IPrinterProfileRepository {
  static const String tableName = 'printer_profiles';
  final ILocalDatabase _db;

  PersistentPrinterProfileRepository(this._db);

  @override
  Future<void> saveProfile(PrinterProfile profile) async {
    final existing = await getProfileById(businessId: profile.businessId, profileId: profile.id);
    final row = {
      'profileId': profile.id,
      'name': profile.name,
      'businessId': profile.businessId,
      'branchId': profile.branchId,
      'printerId': profile.printerId,
      'targetDocumentType': profile.targetDocumentType.name,
      'paperProfileType': profile.paperProfile.type.name,
      'autoPrintPolicy': profile.autoPrintPolicy.name,
      'copies': profile.copies,
      'cutAfterPrint': profile.cutAfterPrint ? 1 : 0,
      'openDrawerOnCash': profile.openDrawerOnCash ? 1 : 0,
      'isDefault': profile.isDefault ? 1 : 0,
    };

    if (existing != null) {
      await _db.update(tableName, row, where: 'profileId = ?', whereArgs: [profile.id]);
    } else {
      await _db.insert(tableName, row);
    }
  }

  @override
  Future<PrinterProfile?> getProfileById({
    required String businessId,
    required String profileId,
  }) async {
    final row = await _db.findById(tableName, 'profileId', profileId);
    if (row == null || row['businessId'] != businessId) return null;
    return _mapToProfile(row);
  }

  @override
  Future<List<PrinterProfile>> getProfilesForBranch({
    required String businessId,
    required String branchId,
  }) async {
    final rows = await _db.query(
      tableName,
      where: 'businessId = ? AND branchId = ?',
      whereArgs: [businessId, branchId],
    );
    return rows.map(_mapToProfile).toList();
  }

  @override
  Future<PrinterProfile?> getProfileForDocument({
    required String businessId,
    required String branchId,
    required PrintDocumentType documentType,
  }) async {
    final rows = await _db.query(
      tableName,
      where: 'businessId = ? AND branchId = ?',
      whereArgs: [businessId, branchId],
    );

    for (final r in rows) {
      if (r['targetDocumentType'] == documentType.name) {
        return _mapToProfile(r);
      }
    }
    return null;
  }

  @override
  Future<void> deleteProfile({
    required String businessId,
    required String profileId,
  }) async {
    await _db.delete(tableName, where: 'profileId = ?', whereArgs: [profileId]);
  }

  PrinterProfile _mapToProfile(Map<String, dynamic> row) {
    final paperTypeStr = row['paperProfileType'] as String? ?? 'thermal80mm';
    final paperType = PaperProfileType.values.byName(paperTypeStr);

    PaperProfile paperProfile;
    switch (paperType) {
      case PaperProfileType.thermal58mm:
        paperProfile = PaperProfile.thermal58mm();
        break;
      case PaperProfileType.thermal80mm:
        paperProfile = PaperProfile.thermal80mm();
        break;
      case PaperProfileType.a4:
        paperProfile = PaperProfile.a4();
        break;
      case PaperProfileType.a5:
        paperProfile = PaperProfile.a5();
        break;
      case PaperProfileType.label:
        paperProfile = PaperProfile.label();
        break;
      case PaperProfileType.custom:
        paperProfile = PaperProfile.thermal80mm();
        break;
    }

    return PrinterProfile(
      id: row['profileId'] as String,
      name: row['name'] as String? ?? 'طابعة الفرع',
      businessId: row['businessId'] as String,
      branchId: row['branchId'] as String,
      printerId: row['printerId'] as String,
      targetDocumentType: row['targetDocumentType'] != null
          ? PrintDocumentType.values.byName(row['targetDocumentType'] as String)
          : PrintDocumentType.saleReceipt,
      paperProfile: paperProfile,
      autoPrintPolicy: row['autoPrintPolicy'] != null
          ? AutoPrintPolicy.values.byName(row['autoPrintPolicy'] as String)
          : AutoPrintPolicy.saleOnly,
      copies: (row['copies'] as num?)?.toInt() ?? 1,
      cutAfterPrint: (row['cutAfterPrint'] as num?)?.toInt() == 1,
      openDrawerOnCash: (row['openDrawerOnCash'] as num?)?.toInt() == 1,
      isDefault: (row['isDefault'] as num?)?.toInt() == 1,
    );
  }
}
