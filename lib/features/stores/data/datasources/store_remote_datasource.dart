import 'package:cloud_firestore/cloud_firestore.dart';

/// مصدر البيانات البعيد للوحة تحكم المتجر (Store Remote Datasource)
/// المسؤول الحصري عن كافة استدعاءات Firestore المباشرة والعمليات الذرية (Transactions)
class StoreRemoteDatasource {
  final FirebaseFirestore? _firestore;

  StoreRemoteDatasource({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 1. ترحيل وتحديث البيانات القديمة (Legacy Data Migration) ───────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// ترحيل الأقسام من product_categories إلى categories ومعالجة createdAt للمنتجات
  Future<void> migrateOldData(String storeId) async {
    if (storeId.trim().isEmpty) return;

    try {
      final storeRef = _db.collection('stores').doc(storeId);

      // 1. ترحيل الأقسام القديمة
      final oldCats = await storeRef.collection('product_categories').get();
      if (oldCats.docs.isNotEmpty) {
        final existingCats = await storeRef.collection('categories').get();
        final existingNames = existingCats.docs
            .map((d) => (d.data()['name'] ?? '').toString())
            .toSet();

        for (final doc in oldCats.docs) {
          final data = doc.data();
          final name = (data['name'] ?? '').toString();
          if (name.isNotEmpty && !existingNames.contains(name)) {
            await storeRef.collection('categories').add({
              'name': name,
              'iconCode': data['iconCode'] ?? 0xe148,
              'colorValue': data['colorValue'] ?? 0xFFF5F5F5,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
          await doc.reference.delete();
        }
      }

      // 2. تحديث createdAt للمنتجات التي تفتقر إليه
      final products = await storeRef.collection('products').get();
      for (final doc in products.docs) {
        final data = doc.data();
        if (data['createdAt'] == null) {
          await doc.reference.update({
            'createdAt': data['updatedAt'] ?? FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (_) {
      // Ignored for graceful migration
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 2. مراقبة وإدارة الطلبات (Orders Management & Streaming) ───────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// مراقبة عدد الطلبات المعلقة لشارة الـ TabBar
  Stream<List<Map<String, dynamic>>> watchPendingOrders(String storeId) {
    if (storeId.trim().isEmpty) return Stream.value([]);
    return _db
        .collection('stores')
        .doc(storeId)
        .collection('madar_orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// مراقبة جميع طلبات المتجر للملخص العام والإحصائيات
  Stream<List<Map<String, dynamic>>> watchAllOrders(String storeId) {
    if (storeId.trim().isEmpty) return Stream.value([]);
    return _db
        .collection('stores')
        .doc(storeId)
        .collection('madar_orders')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// مراقبة قائمة الطلبات مرتبة حسب تاريخ الإنشاء
  Stream<List<Map<String, dynamic>>> watchOrders(String storeId) {
    if (storeId.trim().isEmpty) return Stream.value([]);
    return _db
        .collection('stores')
        .doc(storeId)
        .collection('madar_orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// تعليم الطلب كمقروء من قبل المتجر
  Future<void> markOrderAsRead({
    required String storeId,
    required String orderId,
  }) async {
    if (storeId.trim().isEmpty || orderId.trim().isEmpty) return;
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('madar_orders')
        .doc(orderId)
        .update({'readByStore': true});
  }

  /// العملية الذرية الحساسة لتحديث حالة الطلب وتزامن النقاط والمحفظة (P0 Atomic Transaction)
  Future<void> updateOrderStatus({
    required String storeId,
    required String orderId,
    required String nextStatus,
  }) async {
    if (storeId.trim().isEmpty || orderId.trim().isEmpty) return;

    final orderRef = _db
        .collection('stores')
        .doc(storeId)
        .collection('madar_orders')
        .doc(orderId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      final String oldStatus = data['status']?.toString() ?? 'pending';
      if (oldStatus == nextStatus) return;

      final String customerId =
          data['customerId']?.toString() ?? data['userId']?.toString() ?? '';
      final int pointsEarned = (data['pointsEarned'] as num? ?? 0).toInt();
      final int pointsUsed = (data['pointsUsed'] as num? ?? 0).toInt();
      final double total = (data['total'] as num? ?? data['totalPrice'] as num? ?? 0.0).toDouble();
      final String paymentStatus = data['paymentStatus']?.toString() ?? '';

      // 1. تحديث حالة الطلب داخل متجر
      tx.update(orderRef, {
        'status': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. تحديث سجل طلبات العميل والنقاط/المحفظة
      if (customerId.isNotEmpty) {
        final userRef = _db.collection('users').doc(customerId);
        final userHistoryRef = _db
            .collection('madar_orders')
            .doc(customerId)
            .collection('store_orders')
            .doc(orderId);

        tx.set(
          userHistoryRef,
          {
            'status': nextStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // عند الإكمال: منح النقاط المكتسبة
        if (nextStatus == 'completed' && oldStatus != 'completed') {
          if (pointsEarned > 0) {
            tx.update(userRef, {
              'points': FieldValue.increment(pointsEarned),
            });
          }
        }
        // عند الإلغاء: استرجاع النقاط والمحفظة
        else if (nextStatus == 'cancelled' && oldStatus != 'cancelled') {
          if (pointsUsed > 0) {
            tx.update(userRef, {
              'points': FieldValue.increment(pointsUsed),
            });
          }
          if (paymentStatus == 'paid_wallet' && total > 0) {
            tx.update(userRef, {
              'balance': FieldValue.increment(total),
            });
          }
        }
      }
    });
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 3. مراقبة وإدارة المنتجات (Products CRUD) ──────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// مراقبة جميع منتجات المتجر
  Stream<List<Map<String, dynamic>>> watchProducts(String storeId) {
    if (storeId.trim().isEmpty) return Stream.value([]);
    return _db
        .collection('stores')
        .doc(storeId)
        .collection('products')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// إنشاء منتج جديد في المتجر
  Future<void> createProduct({
    required String storeId,
    required Map<String, dynamic> productData,
  }) async {
    if (storeId.trim().isEmpty) return;
    final payload = Map<String, dynamic>.from(productData);
    payload['createdAt'] = FieldValue.serverTimestamp();
    payload['updatedAt'] = FieldValue.serverTimestamp();
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('products')
        .add(payload);
  }

  /// تعديل بيانات منتج موجود
  Future<void> updateProduct({
    required String storeId,
    required String productId,
    required Map<String, dynamic> productData,
  }) async {
    if (storeId.trim().isEmpty || productId.trim().isEmpty) return;
    final payload = Map<String, dynamic>.from(productData);
    payload['updatedAt'] = FieldValue.serverTimestamp();
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('products')
        .doc(productId)
        .update(payload);
  }

  /// حذف منتج من المتجر
  Future<void> deleteProduct({
    required String storeId,
    required String productId,
  }) async {
    if (storeId.trim().isEmpty || productId.trim().isEmpty) return;
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('products')
        .doc(productId)
        .delete();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 4. مراقبة وإدارة التصنيفات (Categories CRUD) ────────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// مراقبة تصنيفات المتجر
  Stream<List<Map<String, dynamic>>> watchCategories(String storeId) {
    if (storeId.trim().isEmpty) return Stream.value([]);
    return _db
        .collection('stores')
        .doc(storeId)
        .collection('categories')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// إضافة تصنيف جديد للمتجر
  Future<void> createCategory({
    required String storeId,
    required String name,
    int iconCode = 0xe148,
    int colorValue = 0xFFF5F5F5,
  }) async {
    if (storeId.trim().isEmpty || name.trim().isEmpty) return;
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('categories')
        .add({
      'name': name.trim(),
      'iconCode': iconCode,
      'colorValue': colorValue,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// حذف تصنيف من المتجر
  Future<void> deleteCategory({
    required String storeId,
    required String categoryId,
  }) async {
    if (storeId.trim().isEmpty || categoryId.trim().isEmpty) return;
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('categories')
        .doc(categoryId)
        .delete();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 5. مراقبة وإدارة الإعلانات الترويجية (Banners CRUD) ─────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// مراقبة إعلانات المتجر مرتبة تنازلياً
  Stream<List<Map<String, dynamic>>> watchBanners(String storeId) {
    if (storeId.trim().isEmpty) return Stream.value([]);
    return _db
        .collection('stores')
        .doc(storeId)
        .collection('banners')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// إضافة إعلان ترويجي للمتجر
  Future<void> createBanner({
    required String storeId,
    required String title,
    String subtitle = '',
    required String imageUrl,
  }) async {
    if (storeId.trim().isEmpty || imageUrl.trim().isEmpty) return;
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('banners')
        .add({
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'imageUrl': imageUrl.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// حذف إعلان ترويجي للمتجر
  Future<void> deleteBanner({
    required String storeId,
    required String bannerId,
  }) async {
    if (storeId.trim().isEmpty || bannerId.trim().isEmpty) return;
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('banners')
        .doc(bannerId)
        .delete();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 6. ملف المتجر ونقل الملكية (Profile & Ownership) ───────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// جلب بيانات المتجر الحالية
  Future<Map<String, dynamic>?> getStoreById(String storeId) async {
    if (storeId.trim().isEmpty) return null;
    final doc = await _db.collection('stores').doc(storeId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    data['id'] = doc.id;
    return data;
  }

  /// مراقبة بيانات المتجر وتحديثاتها
  Stream<Map<String, dynamic>?> watchStore(String storeId) {
    if (storeId.trim().isEmpty) return Stream.value(null);
    return _db.collection('stores').doc(storeId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final data = Map<String, dynamic>.from(doc.data()!);
      data['id'] = doc.id;
      return data;
    });
  }

  /// تحديث معلومات المتجر والشعار والصور والإحداثيات
  Future<void> updateStoreProfile({
    required String storeId,
    required String name,
    String? logoUrl,
    String? coverUrl,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    if (storeId.trim().isEmpty || name.trim().isEmpty) return;
    await _db.collection('stores').doc(storeId).update({
      'name': name.trim(),
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (address != null) 'address': address,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// نقل ملكية المتجر إلى مستخدم آخر بواسطة البريد الإلكتروني (P0 Security Operation)
  Future<bool> transferStoreOwnership({
    required String storeId,
    required String targetEmail,
  }) async {
    if (storeId.trim().isEmpty || targetEmail.trim().isEmpty) return false;

    final query = await _db
        .collection('users')
        .where('email', isEqualTo: targetEmail.trim())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return false;
    }

    final newOwnerUid = query.docs.first.id;
    await _db.collection('stores').doc(storeId).update({
      'ownerId': newOwnerUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return true;
  }
}
