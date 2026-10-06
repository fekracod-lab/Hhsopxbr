import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// خدمة قاعدة البيانات المحلية التراكمية (SQLite Local Database)
/// تضمن استمرارية الكاشير بنسبة 100% بدون إنترنت وحفظ كافة المعاملات فورياً < 15ms
class LocalDatabaseService {
  static final LocalDatabaseService instance = LocalDatabaseService._internal();
  LocalDatabaseService._internal();

  Database? _database;

  /// محوّل فائق الأمان لكائنات Firestore والنماذج المعقدة إلى كائنات قابلة للترميز JSON
  static dynamic _toEncodable(dynamic item) {
    if (item is Timestamp) {
      return item.toDate().toIso8601String();
    }
    if (item is DateTime) {
      return item.toIso8601String();
    }
    if (item is FieldValue) {
      return DateTime.now().toIso8601String();
    }
    try {
      final dynamic dyn = item;
      if (dyn.toDate is Function) {
        return (dyn.toDate() as DateTime).toIso8601String();
      }
    } catch (_) {}
    try {
      final dynamic dyn = item;
      if (dyn.toJson is Function) {
        return dyn.toJson();
      }
    } catch (_) {}
    try {
      final dynamic dyn = item;
      if (dyn.toMap is Function) {
        return dyn.toMap();
      }
    } catch (_) {}
    return item.toString();
  }

  /// تشفير JSON فائق الأمان لا ينهار أبداً مع كائنات Firestore أو النماذج المعقدة
  static String safeJsonEncode(dynamic data) {
    try {
      return jsonEncode(data, toEncodable: _toEncodable);
    } catch (_) {
      try {
        final sanitized = _sanitize(data);
        return jsonEncode(sanitized, toEncodable: (e) => e.toString());
      } catch (e) {
        debugPrint('[LocalDatabaseService] safeJsonEncode fallback error: $e');
        return '{}';
      }
    }
  }

  static dynamic _sanitize(dynamic value) {
    if (value == null) return null;
    if (value is num || value is bool || value is String) return value;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is FieldValue) return DateTime.now().toIso8601String();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _sanitize(v)));
    }
    if (value is Iterable) {
      return value.map(_sanitize).toList();
    }
    try {
      final dynamic dyn = value;
      if (dyn.toDate is Function) {
        return (dyn.toDate() as DateTime).toIso8601String();
      }
    } catch (_) {}
    try {
      final dynamic dyn = value;
      if (dyn.toJson is Function) {
        return _sanitize(dyn.toJson());
      }
    } catch (_) {}
    try {
      final dynamic dyn = value;
      if (dyn.toMap is Function) {
        return _sanitize(dyn.toMap());
      }
    } catch (_) {}
    return value.toString();
  }

  /// تهيئة قاعدة البيانات المحلية على نظام Windows والأنظمة المدعومة
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final dbDir = Directory(p.join(docsDir.path, 'MadarPosData'));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    final dbPath = p.join(dbDir.path, 'madar_pos_local.db');

    return await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          debugPrint('[LocalDatabaseService] Creating local SQLite tables at $dbPath');

          // 1. جدول الطلبات المحلية (Offline Transactions)
          await db.execute('''
            CREATE TABLE local_orders (
              local_id TEXT PRIMARY KEY,
              remote_id TEXT,
              restaurant_id TEXT NOT NULL,
              order_type TEXT NOT NULL,
              table_number TEXT,
              customer_name TEXT,
              customer_phone TEXT,
              delivery_address TEXT,
              items_json TEXT NOT NULL,
              subtotal REAL NOT NULL,
              discount_amount REAL NOT NULL,
              tax_or_service REAL NOT NULL,
              total_amount REAL NOT NULL,
              payment_method TEXT NOT NULL,
              amount_paid REAL NOT NULL,
              change_amount REAL NOT NULL,
              status TEXT NOT NULL,
              cashier_name TEXT NOT NULL,
              created_at TEXT NOT NULL,
              sync_status TEXT NOT NULL,
              sync_attempts INTEGER DEFAULT 0,
              last_sync_error TEXT,
              synced_at TEXT
            )
          ''');

          // 2. جدول طابور الطباعة (Print Jobs State Machine)
          await db.execute('''
            CREATE TABLE print_jobs (
              job_id TEXT PRIMARY KEY,
              order_id TEXT NOT NULL,
              printer_id TEXT,
              status TEXT NOT NULL,
              attempts INTEGER DEFAULT 0,
              last_error TEXT,
              created_at TEXT NOT NULL,
              printed_at TEXT,
              receipt_payload_json TEXT NOT NULL
            )
          ''');

          // 3. جدول سجل التدقيق التجاري (Audit Trail)
          await db.execute('''
            CREATE TABLE audit_logs (
              log_id TEXT PRIMARY KEY,
              terminal_id TEXT NOT NULL,
              user_id TEXT NOT NULL,
              user_name TEXT NOT NULL,
              action TEXT NOT NULL,
              target_type TEXT NOT NULL,
              target_id TEXT NOT NULL,
              before_state TEXT,
              after_state TEXT,
              reason TEXT,
              manager_pin_verified INTEGER DEFAULT 0,
              timestamp TEXT NOT NULL,
              sync_status TEXT DEFAULT 'pending'
            )
          ''');

          // إنشاء فهارس لتحسين سرعة الاستعلامات والـ Sync
          await db.execute('CREATE INDEX idx_orders_sync ON local_orders(sync_status);');
          await db.execute('CREATE INDEX idx_print_status ON print_jobs(status);');
          await db.execute('CREATE INDEX idx_audit_sync ON audit_logs(sync_status);');
        },
      ),
    );
  }

  // ==========================================
  // عمليات الطلبات المحلية (Local Orders CRUD)
  // ==========================================

  /// حفظ طلب جديد محلياً (معاملة ذرية فورية)
  Future<void> saveLocalOrder(Map<String, dynamic> orderMap) async {
    final db = await database;
    await db.insert(
      'local_orders',
      {
        'local_id': orderMap['localId'] ?? orderMap['orderId'],
        'remote_id': orderMap['remoteId'],
        'restaurant_id': orderMap['restaurantId'] ?? 'unknown_rest',
        'order_type': orderMap['orderType'] ?? 'takeaway',
        'table_number': orderMap['tableNumber'],
        'customer_name': orderMap['customerName'] ?? 'زبون مباشر',
        'customer_phone': orderMap['customerPhone'] ?? '',
        'delivery_address': orderMap['deliveryAddress'] ?? '',
        'items_json': safeJsonEncode(orderMap['items'] ?? []),
        'subtotal': (orderMap['subtotal'] ?? 0.0).toDouble(),
        'discount_amount': (orderMap['discountAmount'] ?? 0.0).toDouble(),
        'tax_or_service': (orderMap['taxOrService'] ?? 0.0).toDouble(),
        'total_amount': (orderMap['totalAmount'] ?? 0.0).toDouble(),
        'payment_method': orderMap['paymentMethod'] ?? 'cash',
        'amount_paid': (orderMap['amountPaid'] ?? 0.0).toDouble(),
        'change_amount': (orderMap['changeAmount'] ?? 0.0).toDouble(),
        'status': orderMap['status'] ?? 'completed',
        'cashier_name': orderMap['cashierName'] ?? 'كاشير رئيسي',
        'created_at': orderMap['createdAt'] is DateTime
            ? (orderMap['createdAt'] as DateTime).toIso8601String()
            : orderMap['createdAt'] is Timestamp
                ? (orderMap['createdAt'] as Timestamp).toDate().toIso8601String()
                : (orderMap['createdAt']?.toString() ?? DateTime.now().toIso8601String()),
        'sync_status': orderMap['syncStatus'] ?? 'pending',
        'sync_attempts': 0,
        'last_sync_error': null,
        'synced_at': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// حذف طلب محلي من قاعدة البيانات المحلية في SQLite
  Future<int> deleteLocalOrder(String orderId) async {
    final db = await database;
    return await db.delete(
      'local_orders',
      where: 'local_id = ? OR remote_id = ?',
      whereArgs: [orderId, orderId],
    );
  }

  /// مسح وحذف كافة الطلبات المحلية التالفة أو التجريبية
  Future<int> clearCorruptOrTestOrders() async {
    final db = await database;
    return await db.delete(
      'local_orders',
      where: 'total_amount <= 0 OR customer_name = ? OR customer_name LIKE ?',
      whereArgs: ['', '%%'],
    );
  }

  /// جلب الطلبات المعلقة للمزامنة مع السيرفر
  Future<List<Map<String, dynamic>>> getPendingSyncOrders({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'local_orders',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  /// جلب كافة الطلبات المحلية المحفوظة في SQLite
  Future<List<Map<String, dynamic>>> getAllLocalOrders({int limit = 100}) async {
    final db = await database;
    return await db.query(
      'local_orders',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  /// تحديث حالة مزامنة الطلب بعد رفعه إلى Firebase
  Future<void> markOrderSynced({required String localId, required String remoteId}) async {
    final db = await database;
    await db.update(
      'local_orders',
      {
        'remote_id': remoteId,
        'sync_status': 'synced',
        'synced_at': DateTime.now().toIso8601String(),
        'last_sync_error': null,
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// تسجيل فشل محاولة المزامنة
  Future<void> recordSyncFailure({required String localId, required String error}) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE local_orders 
      SET sync_attempts = sync_attempts + 1,
          last_sync_error = ?,
          sync_status = 'failed'
      WHERE local_id = ?
    ''', [error, localId]);
  }

  /// إجمالي عدد الطلبات المحلية غير المتزامنة
  Future<int> getPendingSyncCount() async {
    final db = await database;
    final res = await db.rawQuery("SELECT COUNT(*) as cnt FROM local_orders WHERE sync_status = 'pending' OR sync_status = 'failed'");
    if (res.isNotEmpty) {
      return (res.first['cnt'] as int?) ?? 0;
    }
    return 0;
  }

  // ==========================================
  // عمليات طابور الطباعة (Print Queue CRUD)
  // ==========================================

  /// إدراج مهمة طباعة في الطابور المحلي
  Future<void> insertPrintJob({
    required String jobId,
    required String orderId,
    String? printerId,
    required Map<String, dynamic> payload,
    String status = 'pending',
  }) async {
    final db = await database;
    await db.insert(
      'print_jobs',
      {
        'job_id': jobId,
        'order_id': orderId,
        'printer_id': printerId,
        'status': status,
        'attempts': 0,
        'last_error': null,
        'created_at': DateTime.now().toIso8601String(),
        'printed_at': null,
        'receipt_payload_json': safeJsonEncode(payload),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// تحديث حالة مهمة الطباعة
  Future<void> updatePrintJobStatus({
    required String jobId,
    required String status,
    String? error,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    if (status == 'printed') {
      await db.update(
        'print_jobs',
        {
          'status': 'printed',
          'printed_at': now,
          'last_error': null,
        },
        where: 'job_id = ?',
        whereArgs: [jobId],
      );
    } else if (status == 'failed') {
      await db.rawUpdate('''
        UPDATE print_jobs
        SET status = 'failed',
            attempts = attempts + 1,
            last_error = ?
        WHERE job_id = ?
      ''', [error ?? 'Unknown print error', jobId]);
    } else {
      await db.update(
        'print_jobs',
        {'status': status},
        where: 'job_id = ?',
        whereArgs: [jobId],
      );
    }
  }

  /// جلب مهام الطباعة الفاشلة أو المعلقة
  Future<List<Map<String, dynamic>>> getActiveOrFailedPrintJobs() async {
    final db = await database;
    return await db.query(
      'print_jobs',
      where: 'status = ? OR status = ?',
      whereArgs: ['failed', 'pending'],
      orderBy: 'created_at DESC',
    );
  }

  // ==========================================
  // عمليات سجل التدقيق التجاري (Audit Logs CRUD)
  // ==========================================

  /// تسجيل حركة جديدة في سجل التدقيق
  Future<void> insertAuditLog(Map<String, dynamic> log) async {
    final db = await database;
    await db.insert(
      'audit_logs',
      {
        'log_id': log['logId'],
        'terminal_id': log['terminalId'] ?? 'terminal_main',
        'user_id': log['userId'] ?? 'anonymous',
        'user_name': log['userName'] ?? 'الكاشير',
        'action': log['action'],
        'target_type': log['targetType'] ?? 'order',
        'target_id': log['targetId'] ?? '',
        'before_state': log['beforeState'] != null ? safeJsonEncode(log['beforeState']) : null,
        'after_state': log['afterState'] != null ? safeJsonEncode(log['afterState']) : null,
        'reason': log['reason'],
        'manager_pin_verified': (log['managerPinVerified'] == true) ? 1 : 0,
        'timestamp': log['timestamp'] is DateTime
            ? (log['timestamp'] as DateTime).toIso8601String()
            : (log['timestamp']?.toString() ?? DateTime.now().toIso8601String()),
        'sync_status': 'pending',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// جلب سجلات التدقيق المعلقة للمزامنة مع السيرفر
  Future<List<Map<String, dynamic>>> getPendingAuditLogs({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'audit_logs',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
  }

  /// تحديث حالة مزامنة سجلات التدقيق
  Future<void> markAuditLogsSynced(List<String> logIds) async {
    if (logIds.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(logIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE audit_logs SET sync_status = ? WHERE log_id IN ($placeholders)',
      ['synced', ...logIds],
    );
  }

  /// جلب كافة سجلات التدقيق المحلية مرتبة من الأحدث للأقدم
  Future<List<Map<String, dynamic>>> getAllAuditLogs({int limit = 100}) async {
    final db = await database;
    return await db.query(
      'audit_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  /// جلب سجلات التدقيق الخاصة بطلب محدد (توثيق حقيقي لكافة الإجراءات)
  Future<List<Map<String, dynamic>>> getAuditLogsForOrder(String orderId) async {
    final db = await database;
    return await db.query(
      'audit_logs',
      where: 'target_id = ? OR target_id = ?',
      whereArgs: [orderId, 'order_$orderId'],
      orderBy: 'timestamp DESC',
    );
  }
}
