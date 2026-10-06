import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dalal_alqaim/core/automation/smart_assistant_config.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';
import 'package:image_picker/image_picker.dart';

class ComplaintsService {
  static final ComplaintsService _instance = ComplaintsService._internal();
  factory ComplaintsService() => _instance;
  ComplaintsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  /// Stream of all active complaints/reports
  Stream<QuerySnapshot<Map<String, dynamic>>> getComplaintsStream({String? categoryFilter, String? statusFilter}) {
    Query<Map<String, dynamic>> query = _firestore.collection('complaints');

    if (categoryFilter != null && categoryFilter != 'الكل') {
      query = query.where('category', isEqualTo: categoryFilter);
    }
    if (statusFilter != null && statusFilter != 'الكل') {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.snapshots();
  }

  /// Stream of current user's reports
  Stream<QuerySnapshot<Map<String, dynamic>>> getMyComplaintsStream(String uid) {
    return _firestore
        .collection('complaints')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  /// Add a new community report / complaint with map coordinates and multiple images
  Future<String> addComplaint({
    required String title,
    required String description,
    required String category, // 'حفرة بالشارع', 'ماء فايض', 'وايرات كهرباء', 'انسداد مجاري', 'تراكم نفايات', 'إنارة طافية', 'أخرى'
    required String locationName, // حي الجمعية، الكرابلة، المنصور...
    required double latitude,
    required double longitude,
    String governorate = 'الأنبار',
    String city = 'القائم',
    List<XFile>? imageFiles,
    XFile? imageFile,
    String? type = 'شكوى', // 'شكوى' or 'اقتراح'
  }) async {
    final user = _auth.currentUser;
    List<String> imageUrls = [];

    // Collect all files
    List<XFile> allFiles = [];
    if (imageFiles != null && imageFiles.isNotEmpty) {
      allFiles.addAll(imageFiles);
    }
    if (imageFile != null && !allFiles.contains(imageFile)) {
      allFiles.add(imageFile);
    }

    // Upload all images to Cloudinary
    for (var img in allFiles) {
      try {
        final bytes = await img.readAsBytes();
        final uploadedUrl = await CloudinaryService.uploadBytes(bytes, img.name);
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          imageUrls.add(uploadedUrl);
        }
      } catch (e) {
        debugPrint('Image upload error: $e');
      }
    }

    final docRef = await _firestore.collection('complaints').add({
      'title': title.trim(),
      'description': description.trim(),
      'category': category,
      'type': type,
      'status': 'pending', // 'pending' (قيد المراجعة), 'in_progress' (قيد المعالجة), 'resolved' (تم الحل), 'rejected' (مرفوض)
      'locationName': locationName.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'images': imageUrls,
      'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : '',
      'userId': user?.uid ?? 'guest',
      'userName': user?.displayName ?? 'مواطن من العراق',
      'userPhone': user?.phoneNumber ?? '',
      'upvotesCount': 1,
      'upvotedUsers': user != null ? [user.uid] : [],
      'governorate': governorate.trim(),
      'city': city.trim(),
      'country': 'العراق',
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Toggle Upvote / Confirmation on a complaint ("أؤيد هذا البلاغ")
  Future<void> toggleUpvote(String docId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('complaints').doc(docId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.data() as Map<String, dynamic>;
    final List<dynamic> upvotedUsers = List.from(data['upvotedUsers'] ?? []);

    if (upvotedUsers.contains(user.uid)) {
      upvotedUsers.remove(user.uid);
      await docRef.update({
        'upvotedUsers': upvotedUsers,
        'upvotesCount': FieldValue.increment(-1),
      });
    } else {
      upvotedUsers.add(user.uid);
      await docRef.update({
        'upvotedUsers': upvotedUsers,
        'upvotesCount': FieldValue.increment(1),
      });
    }
  }

  /// Update complaint status (Admin / SuperUser)
  Future<void> updateStatus(String docId, String newStatus, {String? resolutionNote}) async {
    await _firestore.collection('complaints').doc(docId).update({
      'status': newStatus,
      if (resolutionNote != null) 'resolutionNote': resolutionNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete complaint
  Future<void> deleteComplaint(String docId) async {
    await _firestore.collection('complaints').doc(docId).delete();
  }

  /// Stream comments / updates for a complaint
  Stream<QuerySnapshot<Map<String, dynamic>>> getCommentsStream(String complaintId) {
    return _firestore
        .collection('complaints')
        .doc(complaintId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Add comment / update to complaint
  Future<void> addComment(String complaintId, String text) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return;

    await _firestore
        .collection('complaints')
        .doc(complaintId)
        .collection('comments')
        .add({
      'userId': user.uid,
      'userName': user.displayName ?? 'مواطن من القائم',
      'userPhoto': user.photoURL ?? '',
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Generate AI Civic Complaint Text with Skozme
  Future<String> generateCivicReportWithAI({
    required String issueCategory,
    required String location,
    String? additionalNotes,
  }) async {
    try {
      final prompt = """أنت "سكوزمي البلدي"، المساعد الذكي لبلاغات وشكاوى المواطنين في تطبيق"مدار" لمدينة القائم ومحافظة الأنبار.
قم بصياغة بلاغ/شكوى بلدية واضحة ومحترمة باللهجة العراقية اللطيفة والمباشرة للجهات المختصة (البلدية، دائرة الماء، الكهرباء، المجاري).
نوع المشكلة: $issueCategory
الموقع / الحي: $location بالقائم
ملاحظات إضافية: ${additionalNotes ?? 'لا توجد'}

المطلوب:
صيغ عنواناً مختصراً ووصفاً دقيقاً يوضح مكان المشكلة وتأثيرها على الأهالي وطلب الإسراع بمعالجتها.
""";
      final reply = await SmartAssistantConfig.askProxy(prompt);
      if (reply != null && reply.trim().isNotEmpty) {
        return reply.trim();
      }
    } catch (e) {
      debugPrint('Civic AI generation error: $e');
    }

    // Offline Iraqi Fallback
    return "السلام عليكم، نود التبليغ عن وجود ($issueCategory) في منطقة ($location) بالقائم، مما يسبب إعاقة لحركة السير والمواطنين وخطورة على الأطفال والسيارات. نرجو من الجهات المختصة والكوادر الخدمية التفضل بالاطلاع والمعالجة السريعة مشكورين.";
  }
}
