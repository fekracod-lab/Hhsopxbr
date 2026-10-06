import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../domain/entities/store_cart_item_entity.dart';
import '../../domain/entities/store_checkout_models.dart';

/// مصدر البيانات البعيد لتفاصيل المتجر والسلة وإتمام الطلب (Store Details Remote Datasource)
/// المسؤول الحصري عن كافة استدعاءات Firestore والمعاملات الذرية (Atomic Transactions) والخدمات الخارجية
class StoreDetailsRemoteDatasource {
  final FirebaseFirestore? _firestore;
  final Dio? _dio;

  StoreDetailsRemoteDatasource({
    FirebaseFirestore? firestore,
    Dio? dio,
  }) : _firestore = firestore,
        _dio = dio;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  Dio get _httpClient => _dio ?? Dio();

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 1. التدفقات واسترجاع بيانات المتجر (Streams & Reads) ───────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// مراقبة منتجات المتجر لحظياً
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
              data['productId'] = doc.id;
              return data;
            }).toList());
  }

  /// مراقبة أقسام المتجر لحظياً
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
              data['categoryId'] = doc.id;
              return data;
            }).toList());
  }

  /// مراقبة إعلانات المتجر لحظياً
  Stream<List<Map<String, dynamic>>> watchBanners(String storeId) {
    if (storeId.trim().isEmpty) return Stream.value([]);
    return _db
        .collection('stores')
        .doc(storeId)
        .collection('banners')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              data['bannerId'] = doc.id;
              return data;
            }).toList());
  }

  /// جلب وثيقة المتجر لمرة واحدة
  Future<Map<String, dynamic>?> getStore(String storeId) async {
    if (storeId.trim().isEmpty) return null;
    final doc = await _db.collection('stores').doc(storeId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    data['id'] = doc.id;
    return data;
  }

  /// جلب بيانات المستخدم لمرة واحدة (النقاط، الرصيد، العنوان)
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (userId.trim().isEmpty) return null;
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    data['id'] = doc.id;
    return data;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 2. المعاملة الذرية الحساسة لإتمام الطلب (P0 Atomic Checkout) ────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// إنشاء الطلب وخصم النقاط والرصيد وحفظ سجل الطلبات ذرياً داخل Transaction واحدة
  Future<bool> placeOrderAtomic({
    required String storeId,
    required String userId,
    required String orderId,
    required String customerName,
    required String customerPhone,
    required String address,
    required String notes,
    double? latitude,
    double? longitude,
    required Map<String, dynamic> storeData,
    required List<StoreCartItemEntity> items,
    required StoreCheckoutSummaryEntity summary,
  }) async {
    if (storeId.trim().isEmpty || userId.trim().isEmpty || orderId.trim().isEmpty) {
      return false;
    }

    final userRef = _db.collection('users').doc(userId);
    final storeOrderRef = _db
        .collection('stores')
        .doc(storeId)
        .collection('madar_orders')
        .doc(orderId);
    final customerOrderRef = _db
        .collection('madar_orders')
        .doc(userId)
        .collection('store_orders')
        .doc(orderId);

    final ownerId = storeData['ownerId']?.toString() ?? storeId;
    final isWallet = summary.paymentMethod == StorePaymentMethod.wallet;

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final userData = userSnap.data() ?? {};

      // 1. التحقق من رصيد المحفظة عند الدفع بها
      if (isWallet) {
        final userBalance = (userData['balance'] as num? ?? 0.0).toDouble();
        if (userBalance < summary.finalTotal) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'insufficient-balance',
            message: 'رصيد المحفظة غير كافٍ لإتمام عملية الشراء',
          );
        }
      }

      // 2. التحقق من رصيد النقاط عند استخدامها
      if (summary.pointsUsed > 0) {
        final userPoints = (userData['points'] as num? ?? 0).toInt();
        if (userPoints < summary.pointsUsed) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'insufficient-points',
            message: 'رصيد النقاط غير كافٍ',
          );
        }
      }

      // 3. كتابة وثيقة الطلب لمتجر التاجر
      final storeOrderPayload = <String, dynamic>{
        'orderId': orderId,
        'ownerId': ownerId,
        'customerId': userId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'storeId': storeId,
        'storeName': storeData['name'] ?? 'متجر مدار',
        'storeAddress': storeData['address'] ?? storeData['location'] ?? 'عنوان المتجر',
        'storeLatitude': storeData['latitude'] ?? storeData['lat'],
        'storeLongitude': storeData['longitude'] ?? storeData['lng'],
        'storePhone': storeData['phone'] ?? '',
        'deliveryFee': summary.deliveryFee,
        'notes': notes,
        'items': items.map((it) => {
              'name': it.name,
              'price': it.price,
              'imageUrl': it.imageUrl,
              'quantity': it.quantity,
            }).toList(),
        'total': summary.finalTotal,
        'subTotal': summary.subtotal,
        'discount': summary.totalDiscount,
        'pointsUsed': summary.pointsUsed,
        'pointsDiscount': summary.pointsDiscount,
        'walletDiscount': summary.walletDiscount,
        'pointsEarned': summary.pointsEarned,
        'paymentStatus': summary.paymentStatus.toDbString(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'readByStore': false,
      };
      tx.set(storeOrderRef, storeOrderPayload);

      // 4. كتابة وثيقة الطلب في سجل طلبات العميل
      final customerOrderPayload = <String, dynamic>{
        'orderId': orderId,
        'ownerId': ownerId,
        'storeId': storeId,
        'storeName': storeData['name'] ?? 'متجر مدار',
        'items': items.map((it) => {
              'name': it.name,
              'price': it.price,
              'imageUrl': it.imageUrl,
              'quantity': it.quantity,
            }).toList(),
        'total': summary.finalTotal,
        'status': 'pending',
        'paymentStatus': summary.paymentStatus.toDbString(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      tx.set(customerOrderRef, customerOrderPayload);

      // 5. تحديث ملف العميل ذرياً (النقاط، المحفظة، العنوان)
      final userUpdates = <String, dynamic>{
        'fullName': customerName,
        'phone': customerPhone,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      };

      if (summary.pointsUsed > 0) {
        userUpdates['points'] = FieldValue.increment(-summary.pointsUsed);
      }
      if (isWallet && summary.finalTotal > 0.0) {
        userUpdates['balance'] = FieldValue.increment(-summary.finalTotal);
      }

      tx.update(userRef, userUpdates);
    });

    return true;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 3. إدارة المنتجات والأقسام للمالك/الأدمن (In-UI Admin Operations) ──
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// إنشاء منتج جديد
  Future<void> createProduct({
    required String storeId,
    required Map<String, dynamic> productData,
  }) async {
    final payload = Map<String, dynamic>.from(productData);
    payload['createdAt'] = FieldValue.serverTimestamp();
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('products')
        .add(payload);
  }

  /// تحديث بيانات منتج
  Future<void> updateProduct({
    required String storeId,
    required String productId,
    required Map<String, dynamic> productData,
  }) async {
    final payload = Map<String, dynamic>.from(productData);
    payload['updatedAt'] = FieldValue.serverTimestamp();
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('products')
        .doc(productId)
        .update(payload);
  }

  /// حذف منتج
  Future<void> deleteProduct({
    required String storeId,
    required String productId,
  }) async {
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('products')
        .doc(productId)
        .delete();
  }

  /// إنشاء قسم جديد
  Future<void> createCategory({
    required String storeId,
    required String name,
    int iconCode = 0xe148,
    int colorValue = 0xFFF5F5F5,
  }) async {
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('categories')
        .add({
      'name': name,
      'iconCode': iconCode,
      'colorValue': colorValue,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// تحديث قسم
  Future<void> updateCategory({
    required String storeId,
    required String categoryId,
    required Map<String, dynamic> categoryData,
  }) async {
    final payload = Map<String, dynamic>.from(categoryData);
    payload['updatedAt'] = FieldValue.serverTimestamp();
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('categories')
        .doc(categoryId)
        .update(payload);
  }

  /// حذف قسم
  Future<void> deleteCategory({
    required String storeId,
    required String categoryId,
  }) async {
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('categories')
        .doc(categoryId)
        .delete();
  }

  /// إضافة إعلان ترويجي
  Future<void> addBanner({
    required String storeId,
    required String imageUrl,
  }) async {
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('banners')
        .add({
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// حذف إعلان ترويجي
  Future<void> deleteBanner({
    required String storeId,
    required String bannerId,
  }) async {
    await _db
        .collection('stores')
        .doc(storeId)
        .collection('banners')
        .doc(bannerId)
        .delete();
  }

  /// ترحيل الأقسام القديمة من product_categories إلى categories
  Future<void> migrateOldCategories(String storeId) async {
    if (storeId.trim().isEmpty) return;
    try {
      final storeRef = _db.collection('stores').doc(storeId);
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
    } catch (_) {}
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ─── 4. الخدمات الخارجية (Cloudinary & Geolocation) ─────────────────────
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// رفع صورة المنتج أو القسم إلى Cloudinary
  Future<String?> uploadImageToCloudinary({
    required String filePath,
    String cloudName = 'dprr2bcq5',
    String uploadPreset = 'madar_app',
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'upload_preset': uploadPreset,
    });

    final response = await _httpClient.post(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      data: formData,
    );

    if (response.statusCode == 200 && response.data != null) {
      return response.data['secure_url']?.toString();
    }
    return null;
  }

  /// جلب الموقع الجغرافي الحالي والعنوان عبر GPS
  Future<Map<String, dynamic>?> getCurrentLocationAndAddress() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String address = '';
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        List<String> parts = [];
        if (p.street != null && p.street!.trim().isNotEmpty && !p.street!.contains('+')) parts.add(p.street!.trim());
        if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) parts.add(p.subLocality!.trim());
        if (p.locality != null && p.locality!.trim().isNotEmpty) parts.add(p.locality!.trim());
        if (p.administrativeArea != null && p.administrativeArea!.trim().isNotEmpty) parts.add(p.administrativeArea!.trim());
        address = parts.join('،');
      }

      return {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'address': address,
      };
    } catch (_) {
      return null;
    }
  }
}
