import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dalal_alqaim/core/automation/smart_assistant_config.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class RealEstateService {
  static final RealEstateService _instance = RealEstateService._internal();
  factory RealEstateService() => _instance;
  RealEstateService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  /// Stream of active real estate listings
  Stream<QuerySnapshot<Map<String, dynamic>>> getPropertiesStream({String? typeFilter, String? categoryFilter}) {
    Query<Map<String, dynamic>> query = _firestore.collection('real_estate');

    if (typeFilter != null && typeFilter != 'الكل') {
      query = query.where('type', isEqualTo: typeFilter);
    }
    if (categoryFilter != null && categoryFilter != 'الكل') {
      query = query.where('category', isEqualTo: categoryFilter);
    }

    return query.snapshots();
  }

  /// Stream of properties created by current user
  Stream<QuerySnapshot<Map<String, dynamic>>> getMyPropertiesStream(String uid) {
    return _firestore
        .collection('real_estate')
        .where('createdBy', isEqualTo: uid)
        .snapshots();
  }

  /// Add new Real Estate Listing
  Future<String> addProperty({
    required String title,
    required String type, // 'للبيع' or 'للإيجار'
    required String category, // 'بيت', 'شقة', 'أرض', 'محل', 'مزرعة', 'فيلا'
    required String price,
    required String currency, // 'IQD' or 'USD'
    required String area, // مساحة بالمتر المربع
    required String location, // الحي أو المنطقة
    String governorate = 'الأنبار',
    String city = 'القائم',
    required String phone,
    required String description,
    required List<String> features,
    required List<XFile> images,
    int? bedrooms,
    int? bathrooms,
    String? streetWidth,
  }) async {
    final user = _auth.currentUser;
    List<String> imageUrls = [];

    // Upload images
    for (var img in images) {
      final bytes = await img.readAsBytes();
      final url = await CloudinaryService.uploadBytes(bytes, img.name);
      if (url != null && url.isNotEmpty) {
        imageUrls.add(url);
      }
    }

    final docRef = await _firestore.collection('real_estate').add({
      'title': title,
      'type': type,
      'category': category,
      'price': price,
      'currency': currency,
      'area': area,
      'location': location,
      'governorate': governorate.trim(),
      'city': city.trim(),
      'country': 'العراق',
      'phone': phone,
      'description': description,
      'features': features,
      'images': imageUrls,
      'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : '',
      'bedrooms': bedrooms ?? 0,
      'bathrooms': bathrooms ?? 0,
      'streetWidth': streetWidth ?? '',
      'createdBy': user?.uid ?? 'guest',
      'ownerName': user?.displayName ?? 'مستخدم مدار',
      'ownerPhoto': user?.photoURL ?? '',
      'sold': false,
      'views': 0,
      'likesCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Update Property Status (Sold / Available)
  Future<void> toggleSoldStatus(String docId, bool isSold) async {
    await _firestore.collection('real_estate').doc(docId).update({
      'sold': isSold,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete property
  Future<void> deleteProperty(String docId) async {
    await _firestore.collection('real_estate').doc(docId).delete();
  }

  /// Increment views count
  Future<void> incrementViews(String docId) async {
    try {
      await _firestore.collection('real_estate').doc(docId).update({
        'views': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  /// Like / Toggle Favorite
  Future<void> toggleLike(String docId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final favDoc = _firestore
        .collection('users')
        .doc(uid)
        .collection('favorite_properties')
        .doc(docId);

    final snapshot = await favDoc.get();
    if (snapshot.exists) {
      await favDoc.delete();
      await _firestore.collection('real_estate').doc(docId).update({
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      await favDoc.set({'addedAt': FieldValue.serverTimestamp()});
      await _firestore.collection('real_estate').doc(docId).update({
        'likesCount': FieldValue.increment(1),
      });
    }
  }

  /// Stream comments for property
  Stream<QuerySnapshot<Map<String, dynamic>>> getCommentsStream(String propertyId) {
    return _firestore
        .collection('real_estate')
        .doc(propertyId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Add comment to property
  Future<void> addComment(String propertyId, String text) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return;

    await _firestore
        .collection('real_estate')
        .doc(propertyId)
        .collection('comments')
        .add({
      'userId': user.uid,
      'userName': user.displayName ?? 'مستخدم مدار',
      'userPhoto': user.photoURL ?? '',
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Direct WhatsApp contact
  Future<void> contactWhatsApp(String phone, String propertyTitle) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('07')) {
      cleanPhone = '+964${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('+')) {
      cleanPhone = '+964$cleanPhone';
    }

    final message = Uri.encodeComponent(
      'السلام عليكم عيوني.. تواصلت وياك بخصوص إعلان العقار المعروض بمدار ("$propertyTitle"). ممكن تفاصيل أكثر؟',
    );
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$message');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Direct Phone Call
  Future<void> makePhoneCall(String phone) async {
    final url = Uri.parse('tel:$phone');
    try {
      await launchUrl(url);
    } catch (_) {}
  }

  /// AI Property Description & Evaluation Assistant (Gemini AI Server Proxy + Fallback)
  Future<String> generateRealEstateTextWithAI({
    required String prompt,
    String? propertyType,
    String? category,
    String? location,
    String? area,
    String? price,
  }) async {
    try {
      final fullPrompt = """أنت "سكوزمي"، المستشار العقاري الذكي والمسوق في تطبيق"مدار" لمدينة القائم ومحافظة الأنبار والعراق.
تحدث دائماً باللهجة العراقية المحببة والجذابة والمقنعة.
معلومات العقار:
- النوع: ${propertyType ?? 'عقار'}
- الصنف: ${category ?? 'بيت / أرض'}
- الموقع / الحي: ${location ?? 'القائم'}
- المساحة: ${area ?? ''} م²
- السعر: ${price ?? 'اتفاقي'}

الطلب:
$prompt

صيغ إعلاناً أو رداً تسويقياً جذاباً بالعراقي يبرز مميزات العقار ويشجع الزبائن على التواصل مع أرقام التواصل وذكر المزايا (طابو، خدمات، ماء، كهرباء).
""";
      final reply = await SmartAssistantConfig.askProxy(fullPrompt);
      if (reply != null && reply.trim().isNotEmpty) {
        return reply.trim();
      }
    } catch (e) {
      debugPrint('Real estate AI generation error: $e');
    }

    // Offline Iraqi Fallback
    return "ما شاء الله! فرصة عقارية ممتازة وموقع استراتيجي في ${location ?? 'القائم'}.\n"
        "عقار بمساحة ${area ?? '200'} م² جاهز للسكن مع كامل الخدمات (ماء إسالة، كهرباء، مجاري، وشارع مبلط).\n"
        "السعر المطلوب: ${price ?? 'مناسب جداً وقابل للتفاوض'}.\n"
        "سند طابو صرف وجاهز للتنازل الفوري. للجادين يرجى التواصل مباشرة عبر الواتساب أو الاتصال! ";
  }
}
