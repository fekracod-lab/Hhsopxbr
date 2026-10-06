// عقد قاعدة البيانات المحلية التبادلية المفهرسة (MADAR SHOP ILocalDatabase Contract)
// Pure Dart — Zero UI Dependencies

abstract class ILocalTransaction {
  Future<void> insert(String table, Map<String, dynamic> row);
  Future<void> update(String table, Map<String, dynamic> row, {required String where, required List<dynamic> whereArgs});
  Future<void> delete(String table, {required String where, required List<dynamic> whereArgs});
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  });
  Future<Map<String, dynamic>?> findById(String table, String idColumn, dynamic idValue);
  Future<void> commit();
  Future<void> rollback();
}

abstract class ILocalDatabase {
  int get currentSchemaVersion;
  Future<void> initialize();
  Future<void> close();

  Future<ILocalTransaction> beginTransaction();

  Future<void> runInTransaction(Future<void> Function(ILocalTransaction tx) action);

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  });

  Future<Map<String, dynamic>?> findById(String table, String idColumn, dynamic idValue);

  Future<void> insert(String table, Map<String, dynamic> row);
  Future<void> update(String table, Map<String, dynamic> row, {required String where, required List<dynamic> whereArgs});
  Future<void> delete(String table, {required String where, required List<dynamic> whereArgs});
  Future<int> count(String table, {String? where, List<dynamic>? whereArgs});
}
