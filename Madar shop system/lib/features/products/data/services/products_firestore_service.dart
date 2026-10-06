import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/shop_product.dart';
import '../../domain/entities/shop_category.dart';

/// خدمة المزامنة السحابية الفورية لمنتجات وتصنيفات المتجر مع تطبيق مدار الرئيسي
class ProductsFirestoreService {
  static final ProductsFirestoreService instance = ProductsFirestoreService._();
  ProductsFirestoreService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// مراقبة حية لجميع منتجات المتجر في الوقت الفعلي
  Stream<List<ShopProduct>> watchProducts(String storeId) {
    if (storeId.trim().isEmpty) return Stream.value([]);
    return _firestore
        .collection('stores')
        .doc(storeId)
        .collection('products')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ShopProduct.fromFirestore(doc)).toList());
  }

  /// مراقبة أقسام وتصنيفات المتجر
  Stream<List<ShopCategory>> watchCategories(String storeId) {
    if (storeId.trim().isEmpty) return Stream.value([]);
    return _firestore
        .collection('stores')
        .doc(storeId)
        .collection('categories')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ShopCategory.fromFirestore(doc)).toList());
  }

  /// إضافة منتج جديد (يظهر فوراً في تطبيق مدار الرئيسي وفي واجهة المتجر)
  Future<String> addProduct(String storeId, ShopProduct product) async {
    final payload = product.toFirestore();
    payload['createdAt'] = FieldValue.serverTimestamp();
    final docRef = await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('products')
        .add(payload);
    return docRef.id;
  }

  /// تحديث بيانات منتج موجود
  Future<void> updateProduct(String storeId, ShopProduct product) async {
    if (product.id.isEmpty) return;
    await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('products')
        .doc(product.id)
        .update(product.toFirestore());
  }

  /// حذف منتج من المتجر وتطبيق مدار
  Future<void> deleteProduct(String storeId, String productId) async {
    if (productId.isEmpty) return;
    await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('products')
        .doc(productId)
        .delete();
  }

  /// خصم كمية المخزون عند إتمام بيع عبر الكاشير (Atomic Increment)
  Future<void> deductStock(String storeId, String productId, int quantity) async {
    if (productId.isEmpty || quantity <= 0) return;
    try {
      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('products')
          .doc(productId)
          .update({
        'stock': FieldValue.increment(-quantity),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// إضافة تصنيف جديد
  Future<String> addCategory(String storeId, String categoryName, {int iconCode = 0xe148}) async {
    final docRef = await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('categories')
        .add({
      'name': categoryName.trim(),
      'iconCode': iconCode,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// حذف تصنيف
  Future<void> deleteCategory(String storeId, String categoryId) async {
    await _firestore
        .collection('stores')
        .doc(storeId)
        .collection('categories')
        .doc(categoryId)
        .delete();
  }
}
