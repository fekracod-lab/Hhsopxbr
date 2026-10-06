import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dalal_alqaim/core/automation/smart_assistant_config.dart';

class VacancyService {
  static final VacancyService _instance = VacancyService._internal();
  factory VacancyService() => _instance;
  VacancyService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  /// Direct WhatsApp contact with prefilled Iraqi message
  Future<void> contactWhatsApp(String phone, String title) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('07')) {
      cleanPhone = '+964${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('+')) {
      cleanPhone = '+964$cleanPhone';
    }

    final message = Uri.encodeComponent(
      'السلام عليكم عيوني.. تواصلت وياك بخصوص إعلان الوظيفة في تطبيق مدار ("$title").',
    );
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$message');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Stream to fetch all active vacancies ordered by creation date
  Stream<QuerySnapshot<Map<String, dynamic>>> getVacanciesStream() {
    return _firestore
        .collection('vacancies')
        .snapshots();
  }

  /// Parse raw date into DateTime safely
  DateTime parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {}
    }
    return DateTime(1970);
  }

  /// Format date for display
  String formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Delete a vacancy doc
  Future<void> deleteVacancy(String docId) async {
    await _firestore.collection('vacancies').doc(docId).delete();
  }

  /// Check if user applied
  Future<bool> hasAlreadyApplied(String vacancyId) async {
    if (currentUser == null) return false;
    final snap = await _firestore
        .collection('vacancies')
        .doc(vacancyId)
        .collection('applications')
        .where('appliedBy', isEqualTo: currentUser!.uid)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Submit application
  Future<void> submitApplication({
    required String vacancyId,
    required String applicantName,
    required String applicantPhone,
    required String applicantExp,
    required String message,
  }) async {
    if (currentUser == null) throw 'سجّل دخولك أولاً';

    await _firestore
        .collection('vacancies')
        .doc(vacancyId)
        .collection('applications')
        .add({
      'applicantName': applicantName,
      'applicantPhone': applicantPhone,
      'applicantExp': applicantExp,
      'message': message,
      'appliedBy': currentUser!.uid,
      'appliedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add a new vacancy or seeker post
  Future<void> addVacancy({
    required String type,
    String? name,
    String? company,
    String? job,
    String? jobDetails,
    required String phone,
    required String notes,
    String? salary,
    List<String>? tags,
    String? tag,
    required String experience,
    String? governorate,
    String? city,
    String? workType,
    String? imageUrl,
  }) async {
    if (currentUser == null) throw 'سجّل دخولك أولاً';

    final effectiveTag = (tags != null && tags.isNotEmpty) ? tags.first : (tag ?? 'مهن أخرى');
    final effectiveJob = jobDetails ?? job ?? '';

    await _firestore.collection('vacancies').add({
      'type': type,
      'name': name ?? company ?? 'مستخدم مدار',
      'company': company ?? name ?? '',
      'job': effectiveJob,
      'jobDetails': effectiveJob,
      'phone': phone,
      'notes': notes,
      'salary': salary ?? 'حسب الاتفاق',
      'tags': tags ?? [effectiveTag],
      'tag': effectiveTag,
      'experience': experience,
      'governorate': governorate ?? 'الأنبار',
      'city': city ?? 'القائم',
      'country': 'العراق',
      'workType': workType ?? 'دوام كامل',
      'views': 0,
      'date': FieldValue.serverTimestamp(),
      'createdBy': currentUser!.uid,
      'likes': 0,
      'imageUrl': imageUrl ?? '',
    });

    await _firestore.collection('notifications').add({
      'title': 'وظيفة جديدة',
      'body': '${type == "seeker" ? "باحث:" : "فرصة:"}$effectiveJob',
      'type': 'vacancy',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Create a new vacancy or seeker post (alias)
  Future<void> createVacancy({
    required String type,
    String? name,
    String? company,
    String? job,
    String? jobDetails,
    required String phone,
    required String notes,
    required String salary,
    required String tag,
    required String experience,
    String? city,
    String? workType,
    String? imageUrl,
  }) async {
    await addVacancy(
      type: type,
      name: name,
      company: company,
      job: job,
      jobDetails: jobDetails,
      phone: phone,
      notes: notes,
      salary: salary,
      tags: [tag],
      tag: tag,
      experience: experience,
      city: city,
      workType: workType,
      imageUrl: imageUrl,
    );
  }

  /// AI content generation helper using secure Server AI Proxy
  Future<String> generateWithAI(String prompt) async {
    try {
      final reply = await SmartAssistantConfig.askProxy(prompt);
      if (reply != null && reply.trim().isNotEmpty) {
        return reply.trim();
      }
    } catch (e) {
      debugPrint('Vacancy AI generation error: $e');
    }
    return '';
  }

  /// Get User Job Profile Stream
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserJobProfileStream(String uid) {
    return _firestore.collection('user_job_profiles').doc(uid).snapshots();
  }

  /// Get User Job Profile Future
  Future<Map<String, dynamic>?> getUserJobProfile(String uid) async {
    final doc = await _firestore.collection('user_job_profiles').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return doc.data();
    }
    // Fallback from users collection
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      final u = userDoc.data()!;
      return {
        'name': u['name'] ?? u['fullName'] ?? '',
        'phone': u['phone'] ?? u['phoneNumber'] ?? '',
        'title': u['title'] ?? 'باحث عن عمل',
        'city': u['city'] ?? 'القائم',
        'experience': 'متوسط',
        'skills': <String>['التواصل', 'العمل الجماعي'],
        'bio': '',
        'isAvailable': true,
      };
    }
    return null;
  }

  /// Save or Update User Job Profile
  Future<void> saveUserJobProfile({
    required String name,
    required String title,
    required String phone,
    required String city,
    required String experience,
    required List<String> skills,
    required String bio,
    required bool isAvailable,
    String? expectedSalary,
  }) async {
    if (currentUser == null) throw 'سجّل دخولك أولاً';
    final uid = currentUser!.uid;

    final data = {
      'name': name.trim(),
      'title': title.trim(),
      'phone': phone.trim(),
      'city': city.trim(),
      'experience': experience,
      'skills': skills,
      'bio': bio.trim(),
      'isAvailable': isAvailable,
      'expectedSalary': expectedSalary?.trim() ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'uid': uid,
    };

    await _firestore.collection('user_job_profiles').doc(uid).set(
      data,
      SetOptions(merge: true),
    );

    // Also update basic info in users collection
    await _firestore.collection('users').doc(uid).set({
      'jobTitle': title.trim(),
      'jobAvailable': isAvailable,
    }, SetOptions(merge: true));
  }

  /// Generate Iraqi Bio / Resume Summary with Skozme AI
  Future<String> generateIraqiBioWithAI({
    required String name,
    required String title,
    required String experience,
    required List<String> skills,
    required String city,
  }) async {
    final prompt = """
أنت سكوزمي، المستشار المهني الذكي لمنصة مدار في العراق والأنبار والقائم.
المطلوب: كتابة نبذة مهنية وسيرة ذاتية مختصرة وجذابة باللهجة العراقية اللطيفة والمحترفة لشخص يبحث عن عمل:
- الاسم: $name
- المسمى المهني: $title
- مستوى الخبرة: $experience
- المهارات: ${skills.join(', ')}
- المدينة: $city

اكتب نبذة احترافية بحدود 3-4 أسطر تعبر عن الالتزام والشغف والجاهزية للعمل فوراً، بدون مقدمات أو فذلكة، مباشرة بالنبذة مع إيموجيز لطيفة.
""";
    final aiResult = await generateWithAI(prompt);
    if (aiResult.isNotEmpty) return aiResult.trim();

    return "مرحباً! أنا $name، متخصص في $title وخبرتي $experience في $city. أمتلك مهارات قوية في ${skills.join('و ')}، وملتزم بتقديم أفضل أداء مع الشغف لتطوير العمل ومستعد للبدء فوراً بكل همة ونشاط!";
  }

  /// Generate Tailored Job Cover Letter
  Future<String> generateIraqiCoverLetterWithAI({
    required String jobTitle,
    required String company,
    required String applicantName,
    required String applicantTitle,
    required String applicantPhone,
  }) async {
    final prompt = """
أنت سكوزمي، مستشار التوظيف الذكي في مدار.
المطلوب: صياغة رسالة تقديم لواتساب/الإيميل مرتبة جداً باللهجة العراقية المحترمة:
- مقدم الطلب: $applicantName ($applicantTitle)
- الوظيفة المستهدفة: $jobTitle
- الجهة/المتجر: $company
- رقم التواصل: $applicantPhone

اكتب رسالة تقديم قصيرة ومباشرة ومحترمة تعبر عن الاهتمام بالانضمام لفريقهم.
""";
    final aiResult = await generateWithAI(prompt);
    if (aiResult.isNotEmpty) return aiResult.trim();

    return "السلام عليكم ورحمة الله وبركاته، تحياتي لفريق $company المحترمين. أنا $applicantName ($applicantTitle)، شفت إعلان وظيفة ($jobTitle) وحبيت أقدم عليها بكل فخر واهتمام لما أملكه من خبرة والتزام. يسعدني التواصل معكم عبر الرقم: $applicantPhone. شكراً جزيلاً وبالتوفيق الدائم!";
  }

  /// Generate Job Ad for Employers
  Future<String> generateIraqiJobAdWithAI({
    required String jobTitle,
    required String company,
    required String city,
    required String salary,
    required String workType,
  }) async {
    final prompt = """
أنت سكوزمي مساعد مدار للتوظيف.
المطلوب: صياغة إعلان فرصة عمل جذابة ومحفزة في العراق والقائم:
- اسم العمل/المتجر: $company
- المسمى الوظيفي: $jobTitle
- المدينة: $city
- الراتب: $salary
- نوع الدوام: $workType

اكتب تفاصيل الإعلان بنقاط واضحة: (المسؤوليات، الشروط، والمزايا) بأسلوب عراقي محترم ومرتب.
""";
    final aiResult = await generateWithAI(prompt);
    if (aiResult.isNotEmpty) return aiResult.trim();

    return "فرصة عمل مميزة في $company ($city)! \nمطلوب: $jobTitle ($workType)\n الراتب: $salary\n الشروط: الالتزام بالمواعيد، الأمانة، والعمل بروح الفريق\n المزايا: بيئة عمل مريحة ومكافآت للمجتهدين\nللتواصل والتقديم يرجى الضغط على زر التقديم أو مراسلتنا مباشرة!";
  }
}
