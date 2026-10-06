import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/store_profile.dart';

/// خدمة مصادقة واختيار المتجر لكاشير مدار (Store Auth & Selector Service)
class StoreAuthService extends ChangeNotifier {
  static final StoreAuthService instance = StoreAuthService._();
  StoreAuthService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StoreProfile? _currentStore;
  StoreProfile? get currentStore => _currentStore;
  bool get hasActiveStore => _currentStore != null;

  /// تهيئة الخدمة واستعادة آخر متجر محدد
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('active_store_profile');
      if (savedJson != null && savedJson.isNotEmpty) {
        _currentStore = StoreProfile.fromMap(jsonDecode(savedJson));
        notifyListeners();
      }
    } catch (_) {}
  }

  /// تعيين المتجر النشط وحفظه
  Future<void> setActiveStore(StoreProfile store) async {
    _currentStore = store;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_store_profile', jsonEncode(store.toMap()));
    } catch (_) {}
  }

  /// مسح المتجر الحالي (تسجيل الخروج)
  Future<void> clearActiveStore() async {
    _currentStore = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_store_profile');
    } catch (_) {}
  }

  /// جلب قائمة جميع المتاجر المسجلة في مدار لاختيار المتجر
  Future<List<StoreProfile>> fetchStores() async {
    try {
      final snap = await _firestore.collection('stores').get();
      return snap.docs.map((doc) => StoreProfile.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[StoreAuthService] fetchStores error: $e');
      return [];
    }
  }

  /// تسجيل الدخول عبر البريد وكلمة المرور
  Future<StoreProfile?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user?.uid;
    if (uid != null) {
      // 1. فحص ما إذا كان الـ UID هو نفس معرف المتجر
      final storeDoc = await _firestore.collection('stores').doc(uid).get();
      if (storeDoc.exists) {
        final profile = StoreProfile.fromFirestore(storeDoc);
        await setActiveStore(profile);
        return profile;
      }

      // 2. البحث بالمالك
      final query = await _firestore.collection('stores').where('ownerId', isEqualTo: uid).limit(1).get();
      if (query.docs.isNotEmpty) {
        final profile = StoreProfile.fromFirestore(query.docs.first);
        await setActiveStore(profile);
        return profile;
      }
    }
    return null;
  }
}
