// قاعدة بيانات محلية تبادلية ومفهرسة بالكامل (MADAR SHOP Memory Local Database)
// Pure Dart — Zero UI Dependencies — Multi-Platform Ready (Windows, Android, iOS)

import 'dart:async';
import '../../../domain/sync/contracts/i_local_database.dart';
import '../../../domain/sync/failures/sync_failures.dart';
import 'schema_migrations.dart';

class MemoryLocalTransaction implements ILocalTransaction {
  final MemoryLocalDatabase _db;
  final Map<String, List<Map<String, dynamic>>> _stagedTables = {};
  bool _isCommitted = false;
  bool _isRolledBack = false;

  MemoryLocalTransaction(this._db) {
    // نسخ عميق لحالة الجداول الحالية لتمكين التراجع الذري Rollback
    for (final entry in _db._tables.entries) {
      _stagedTables[entry.key] = entry.value.map((row) => Map<String, dynamic>.from(row)).toList();
    }
  }

  void _ensureActive() {
    if (_isCommitted) throw SyncDatabaseFailure('Transaction already committed');
    if (_isRolledBack) throw SyncDatabaseFailure('Transaction already rolled back');
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> row) async {
    _ensureActive();
    _stagedTables.putIfAbsent(table, () => []);
    _stagedTables[table]!.add(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> update(
    String table,
    Map<String, dynamic> row, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    _ensureActive();
    final list = _stagedTables[table] ?? [];
    for (int i = 0; i < list.length; i++) {
      if (_matches(list[i], where, whereArgs)) {
        list[i] = {...list[i], ...row};
      }
    }
  }

  @override
  Future<void> delete(String table, {required String where, required List<dynamic> whereArgs}) async {
    _ensureActive();
    final list = _stagedTables[table] ?? [];
    list.removeWhere((item) => _matches(item, where, whereArgs));
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    _ensureActive();
    var list = (_stagedTables[table] ?? []).map((r) => Map<String, dynamic>.from(r)).toList();

    if (where != null && whereArgs != null) {
      list = list.where((item) => _matches(item, where, whereArgs)).toList();
    }

    if (orderBy != null) {
      list = _sort(list, orderBy);
    }

    if (offset != null && offset > 0) {
      list = list.skip(offset).toList();
    }

    if (limit != null && limit > 0) {
      list = list.take(limit).toList();
    }

    return list;
  }

  @override
  Future<Map<String, dynamic>?> findById(String table, String idColumn, dynamic idValue) async {
    _ensureActive();
    final list = _stagedTables[table] ?? [];
    for (final item in list) {
      if (item[idColumn] == idValue) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  @override
  Future<void> commit() async {
    _ensureActive();
    _db._applyTransaction(_stagedTables);
    _isCommitted = true;
  }

  @override
  Future<void> rollback() async {
    _ensureActive();
    _stagedTables.clear();
    _isRolledBack = true;
  }

  bool _matches(Map<String, dynamic> row, String where, List<dynamic> whereArgs) {
    // دعم الاستعلامات الشائعة البسيطة: "column = ?" أو "col1 = ? AND col2 = ?"
    final parts = where.split(RegExp(r'\s+AND\s+', caseSensitive: false));
    if (parts.length != whereArgs.length) return false;

    for (int i = 0; i < parts.length; i++) {
      final expr = parts[i].trim();
      final tokens = expr.split('=');
      if (tokens.length == 2) {
        final col = tokens[0].trim();
        final val = whereArgs[i];
        if (row[col] != val) return false;
      }
    }
    return true;
  }

  List<Map<String, dynamic>> _sort(List<Map<String, dynamic>> list, String orderBy) {
    final tokens = orderBy.trim().split(RegExp(r'\s+'));
    final col = tokens[0];
    final isDesc = tokens.length > 1 && tokens[1].toUpperCase() == 'DESC';

    list.sort((a, b) {
      final va = a[col];
      final vb = b[col];
      if (va == null && vb == null) return 0;
      if (va == null) return isDesc ? 1 : -1;
      if (vb == null) return isDesc ? -1 : 1;
      final cmp = (va as Comparable).compareTo(vb);
      return isDesc ? -cmp : cmp;
    });
    return list;
  }
}

class MemoryLocalDatabase implements ILocalDatabase {
  final Map<String, List<Map<String, dynamic>>> _tables = {};
  int _schemaVersion = 0;
  bool _initialized = false;

  @override
  int get currentSchemaVersion => _schemaVersion;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    final migrationRunner = SchemaMigrations();
    _schemaVersion = await migrationRunner.runMigrations(this);
  }

  @override
  Future<void> close() async {
    _tables.clear();
    _initialized = false;
  }

  void _applyTransaction(Map<String, List<Map<String, dynamic>>> staged) {
    _tables.clear();
    for (final entry in staged.entries) {
      _tables[entry.key] = entry.value.map((r) => Map<String, dynamic>.from(r)).toList();
    }
  }

  @override
  Future<ILocalTransaction> beginTransaction() async {
    if (!_initialized) await initialize();
    return MemoryLocalTransaction(this);
  }

  @override
  Future<void> runInTransaction(Future<void> Function(ILocalTransaction tx) action) async {
    final tx = await beginTransaction();
    try {
      await action(tx);
      await tx.commit();
    } catch (e) {
      await tx.rollback();
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (!_initialized) await initialize();
    final tx = MemoryLocalTransaction(this);
    return tx.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Map<String, dynamic>?> findById(String table, String idColumn, dynamic idValue) async {
    if (!_initialized) await initialize();
    final tx = MemoryLocalTransaction(this);
    return tx.findById(table, idColumn, idValue);
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> row) async {
    await runInTransaction((tx) => tx.insert(table, row));
  }

  @override
  Future<void> update(
    String table,
    Map<String, dynamic> row, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    await runInTransaction((tx) => tx.update(table, row, where: where, whereArgs: whereArgs));
  }

  @override
  Future<void> delete(String table, {required String where, required List<dynamic> whereArgs}) async {
    await runInTransaction((tx) => tx.delete(table, where: where, whereArgs: whereArgs));
  }

  @override
  Future<int> count(String table, {String? where, List<dynamic>? whereArgs}) async {
    final rows = await query(table, where: where, whereArgs: whereArgs);
    return rows.length;
  }

  // ميثود مساعدة لترقية المخطط برمجياً في اختبارات الترقية
  void setSchemaVersion(int version) {
    _schemaVersion = version;
  }
}
