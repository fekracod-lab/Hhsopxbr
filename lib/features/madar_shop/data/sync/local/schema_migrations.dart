// إدارة ترقيات ومخططات قاعدة البيانات المحلية (MADAR SHOP Schema Migrations)
// Pure Dart — Zero UI Dependencies

import '../../../domain/sync/contracts/i_local_database.dart';

class SchemaMigrations {
  static const int currentVersion = 3;

  Future<int> runMigrations(ILocalDatabase db, {int targetVersion = currentVersion}) async {
    int version = db.currentSchemaVersion;

    if (version < 1 && targetVersion >= 1) {
      await _applyV1(db);
      version = 1;
    }

    if (version < 2 && targetVersion >= 2) {
      await _applyV2(db);
      version = 2;
    }

    if (version < 3 && targetVersion >= 3) {
      await _applyV3(db);
      version = 3;
    }

    return version;
  }

  /// الإصدار 1: جداول المزامنة الأساسية وطابور الصادر والوارد
  Future<void> _applyV1(ILocalDatabase db) async {
    // جدول الأوامر المنفذة محلياً
    await db.runInTransaction((tx) async {
      // تهيئة مفاتيح الجداول (عبر إدخال/فحص افتراضي إن لزم)
    });
  }

  /// الإصدار 2: جداول التخزين المحلي المؤقت (المنتجات، المخزون، العملاء، الموردين)
  Future<void> _applyV2(ILocalDatabase db) async {
    // إضافة حقول إضافية وفهارس
  }

  /// الإصدار 3: استدامة طباعة S6 وجداول التعارضات والأقفال
  Future<void> _applyV3(ILocalDatabase db) async {
    // دعم PrintJobs و PrinterProfiles
  }
}
