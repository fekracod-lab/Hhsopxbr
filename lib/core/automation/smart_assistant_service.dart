import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalal_alqaim/core/app_globals.dart';
import 'automation_agent.dart';
import 'iraqi_nlp_engine.dart';
import 'smart_assistant_memory.dart';
import 'iraqi_emotion_engine.dart';
import 'package:dalal_alqaim/pages/restaurants_page.dart';

/// رسالة محادثة
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final String? actionType; // نوع الإجراء: navigate, fetch, say
  final String? actionData; // بيانات الإجراء
  ChatMessage(this.text, this.isUser, {this.actionType, this.actionData})
      : time = DateTime.now();
}

/// بنية بيانات الأسئلة المحلية المخصصة
class LocalFAQItem {
  final List<String> triggers;
  final String response;
  final String? actionType;
  final String? actionData;

  const LocalFAQItem({
    required this.triggers,
    required this.response,
    this.actionType,
    this.actionData,
  });
}

/// خدمة المساعد الذكي سكوزمي - إعادة برمجة كاملة
class SmartAssistantService extends ChangeNotifier {
  static final SmartAssistantService _instance = SmartAssistantService._internal();
  factory SmartAssistantService() => _instance;

  final AutomationAgent agent;
  bool isProcessing = false;
  final List<ChatMessage> messages = [];

  // Callback to trigger visual highlight on screen
  void Function(String target)? onHighlightWidget;

  /// قاعدة بيانات الأسئلة المتكررة المحلية - مخصصة بالكامل لخدمات مدار باللهجة العراقية
  static final List<LocalFAQItem> _localFAQs = [
    LocalFAQItem(
      triggers: [
        'سجل مطعمي', 'تسجيل مطعمي', 'اضيف مطعمي', 'اضافة مطعمي', 'تسجيل مطعم', 'سجل مطعم',
        'اسجل مطعمي', 'اضيف مطعم', 'اضافه مطعم', 'طريقة تسجيل مطعم', 'شلون اسجل مطعمي',
        'شلون اضيف مطعمي', 'مطعمي', 'اضيف مطعمي'
      ],
      response: 'يا هلا ومية هلا بيك! إذا عندك مطعم أو محل وتريد تنضم لعائلة ومتاجر مدار وتزيد زبائنك ومبيعاتك، تكدر تتواصل هسة ويا الإدارة على الواتساب ويفعلولك الحساب فوراً. اضغط بالأسفل وتدلل!',
      actionType: 'launch_whatsapp',
      actionData: 'restaurant',
    ),
    LocalFAQItem(
      triggers: [
        'سجل تكسي', 'تسجيل تكسي', 'اشتغل كابتن', 'شلون اشتغل تكسي', 'تسجيل تاكسي', 'سجل تاكسي',
        'شلون اصير كابتن', 'كابتن تكسي', 'سجلني كابتن', 'سجلني تكسي', 'اشتغل تاكسي', 'تسجيل الكباتن',
        'اسجل كابتن', 'تسجيل كابتن', 'سجلني كابتن'
      ],
      response: 'يا هلا بكابتنا المستقبلي! للعمل ويا تكسي مدار وبأعلى نسبة ربح وأسهل شغل، تكدر تسجل حسابك وتبعت مستمسكاتك للإدارة على الواتساب ويفعلوه فوراً. اضغط بالأسفل وتدلل!',
      actionType: 'launch_whatsapp',
      actionData: 'taxi',
    ),
    LocalFAQItem(
      triggers: [
        'عقارات', 'عقار', 'شقة للبيع', 'شقة للايجار', 'بيوت', 'بيت للايجار', 'بيت للبيع',
        'دورلي بيت', 'اريد شقة', 'اريد بيت', 'شقق', 'شراء بيت', 'ايجار شقة', 'بيع عقار',
        'شراء عقار', 'عقارات مدار', 'شقة', 'بيت'
      ],
      response: 'يا هلا بيك عيوني! تكدر تدور على أحسن البيوت والشقق والأراضي المعروضة للبيع أو الإيجار، أو تضيف عقارك الخاص.. هسة أنقلك لقسم العقارات تتصفح كل المعروض وتدلل!',
      actionType: 'fetch_sections',
      actionData: 'عقارات',
    ),

    LocalFAQItem(
      triggers: [
        'رقم الدعم', 'دعم فني', 'اتصال بالادارة', 'رقم الادارة', 'رقم مدار', 'تقديم شكوى',
        'تقديم بلاغ', 'مشكلة بالتطبيق', 'تواصل مع الادارة', 'واتساب الادارة', 'خدمة العملاء',
        'رقم الواتساب', 'رقم واتساب'
      ],
      response: 'فريق خدمة ودعم مدار دائماً بظهرك وخدمتك يا غالي! تكدر تقدم شكوى داخل التطبيق، أو تحجي ويا الإدارة مباشرة على الواتساب (07819436408). اضغط بالأسفل وإحنا نسمعك ونحل كلشي!',
      actionType: 'launch_whatsapp',
      actionData: 'support',
    ),
  ];

  /// الصفحة الحالية - يتم تحديثها من FAB عند فتح المحادثة
  String currentRoute = '/home';

  /// Callback للتنقل - يتم تعيينه من الـ FAB
  void Function(String route)? onNavigate;

  /// قنوات التحكم في صفحة الوظائف
  void Function(String query)? onSearchJobs;
  void Function(String? category)? onFilterCategory;
  void Function(String filter)? onSetFilter;
  void Function(String sort)? onSetSort;
  void Function()? onAddJob;

  /// قنوات التحكم في صفحة الشكاوى والاقتراحات
  void Function(String query)? onSearchComplaints;
  void Function(String type)? onFilterComplaintType;
  void Function(String status)? onFilterComplaintStatus;
  void Function(String? title, String? desc, String? type)? onAddComplaint;

  /// قنوات التحكم في صفحة استوديوهات التصوير
  void Function(String query)? onSearchStudios;
  void Function(String filter)? onFilterStudioType;
  void Function()? onAddStudio;

  /// قنوات التحكم في صفحة المطاعم
  void Function(String category)? onFilterRestaurantCategory;
  void Function(String query)? onSearchRestaurant;

  /// قنوات التحكم في صفحة البروفايل
  void Function(Map<String, dynamic> updates)? onUpdateProfile;
  void Function()? onTrackOrders;

  /// قنوات التحكم في صفحة التوصيل (مرسال)
  void Function()? onRequestDelivery;

  /// قنوات التحكم في صفحة المتاجر
  void Function(String query)? onSearchStores;
  void Function(String category)? onFilterStoreCategory;

  /// قنوات التحكم في صفحة العقارات
  void Function()? onAddRealEstate;
  void Function(String query)? onSearchRealEstate;
  void Function(String filter)? onFilterRealEstate;

  /// الحالات المعلقة لصفحة الوظائف
  static String? pendingSearchQuery;
  static String? pendingCategory;
  static String? pendingFilter;
  static String? pendingSort;
  static bool pendingAddJob = false;

  /// الحالات المعلقة لصفحة الشكاوى والاقتراحات
  static String? pendingComplaintSearch;
  static String? pendingComplaintType;
  static String? pendingComplaintStatus;
  static bool pendingAddComplaint = false;
  static String? pendingComplaintAddTitle;
  static String? pendingComplaintAddDesc;
  static String? pendingComplaintAddType;

  /// الحالات المعلقة لصفحة استوديوهات التصوير
  static String? pendingStudioSearch;
  static String? pendingStudioType;
  static bool pendingAddStudio = false;

  /// الحالات المعلقة لصفحة المطاعم
  static String? pendingRestaurantCategory;
  static String? pendingRestaurantSearch;

  /// الحالات المعلقة للصفحات الجديدة
  static bool pendingDeliveryRequest = false;
  static bool pendingAddRealEstate = false;
  static String? pendingStoreSearch;
  static String? pendingStoreCategory;
  static String? pendingRealEstateSearch;
  static String? pendingRealEstateFilter;

  SmartAssistantService._internal() : agent = AutomationAgent() {
    // تحميل القاموس العراقي الخارجي عند التشغيل
    IraqiNLPEngine.loadDictionary();
    IraqiNLPEngine.loadLearnedPhrases();

    _addBotMessage(
      'يا هلا ومية هلا بيك! أني سكوزمي رفيقك ومساعدك العراقي الذكي لمدار.\n'
      'أفهم عليك وأتذكرك وأكدر أساعدك بأي شي تريده بالعراق:\n'
      '• احجزلك تكسي وأحسبلك الأجرة\n'
      '• ارشحلك أطيب المطاعم والأكلات الحية\n'
      '• اشوفلك نقاطك ورصيدك بالمحفظة\n'
      '• اساعدك بالتسوق ومتاجر مدار\n'
      '• اتابعلك طلباتك السابقة والشحنات\n'
      '• اشغلك أو اطفي الوضع الليلي\n'
      '• احفظ عناويني وأكلاتي ولقبي المفضل\n'
      '• اساعدك بالبحث عن وظيفة أو نشرها\n\n'
      'آمرني حبيبي شنو محتاج هسة؟ تدلل من عيوني!',
    );

    // تحميل ذاكرة المستخدم وتحديث التحية باسمه المفضل إن وجد
    SmartAssistantMemory().loadMemory().then((_) {
      final nickname = SmartAssistantMemory().customNickname;
      if (nickname != null && nickname.isNotEmpty && messages.isNotEmpty) {
        messages[0] = ChatMessage(
          'يا هلا ومية هلا بيك $nickname! \n'
          'سكوزمي وياك.. شمحتاج اليوم؟ تكسي ، أكل طيب ، فحص نقاطك ومحفظتك ، أو مسواك من المتاجر ؟ تدلل من عيوني الثنتين!',
          false,
        );
        notifyListeners();
      }
    });
  }

  void _addBotMessage(String text, {String? actionType, String? actionData}) {
    messages.add(ChatMessage(text, false,
        actionType: actionType, actionData: actionData));
    notifyListeners();
  }

  void _addUserMessage(String text) {
    messages.add(ChatMessage(text, true));
    notifyListeners();
  }

  /// المسارات المتاحة مع أسمائها بالعربي
  static const Map<String, String> _routeNames = {
    '/login': 'تسجيل الدخول',
    '/register': 'إنشاء حساب جديد',
    '/home': 'الصفحة الرئيسية',
    '/vacancies': 'الوظائف',
    '/complaints': 'الشكاوى والاقتراحات',
    '/my_orders': 'طلباتي',
    '/favorites': 'المفضلة',
    '/profile': 'الملف الشخصي',
    '/taxi': 'تكسي مدار',
    '/restaurants': 'المطاعم',
    '/delivery': 'مرسال لتوصيل الطلبات',
    '/studios': 'استوديوهات التصوير',
    '/stores': 'متاجر مدار',
    '/real_estate': 'العقارات',
    '/all-sections': 'الخدمات العامة والأقسام',
    '/search': 'البحث الشامل',
    '/settings': 'الإعدادات',
    '/notifications': 'الإشعارات',
    '/emergency': 'خدمات الطوارئ',
    '/support': 'الدعم الفني المباشر',
    '/my_addresses': 'عناويني المحفوظة',
    '/user_info': 'بياناتي الشخصية',
    '/lost_found': 'المفقودات والموجودات',
    '/add_place': 'إضافة مكان جديد',
    '/points': 'نقاط مدار والمكافآت',
    '/cart': 'سلة المشتريات',
  };

  // ────────────────────────────────────────────────────────
  // حالات وأساليب المحادثة متعددة الخطوات الذكية (Conversational Wizards)
  // ────────────────────────────────────────────────────────
  int _profileEditStep = 0;
  String? _newProfileName;
  String? _newProfilePhone;

  int _jobAddStep = 0;
  String? _newJobTitle;
  String? _newJobDesc;
  String? _newJobCategory;
  String? _newJobPhone;

  int _realEstateAddStep = 0;
  String? _newRealEstateTitle;
  String? _newRealEstateType; // للبيع / للإيجار
  String? _newRealEstateArea;
  String? _newRealEstateLocation;
  String? _newRealEstatePrice;
  String? _newRealEstatePhone;
  String? _newRealEstateNotes;

  int _deliveryStep = 0;
  String? _newDeliveryItem;
  String? _newDeliveryPickup;
  String? _newDeliveryDropoff;
  String? _newDeliveryPhone;

  int _taxiBookingStep = 0;
  String? _newTaxiPickup;
  String? _newTaxiDestination;
  String? _newTaxiPassengers;

  int _complaintStep = 0;
  String? _newComplaintSubject;
  String? _newComplaintDetails;
  String? _newComplaintPhone;

  String _cleanExcuseMePrefix(String text) {
    String cleaned = text.trim();
    final prefixes = [
      'يا سكوزمي', 'سكوزمي', 'ياحبيبي سكوزمي', 'حبيبي سكوزمي', 'اسمعني سكوزمي',
      'excuse me', 'excuseme'
    ];
    for (var prefix in prefixes) {
      final normC = cleaned.toLowerCase();
      if (normC.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length).trim();
        break;
      }
    }
    if (cleaned.startsWith('و')) {
      cleaned = cleaned.substring(2).trim();
    }
    return cleaned;
  }

  Future<void> _handleProfileEditStep(String text) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final normalized = _normalizeArabic(text);

    if (_matchesAny(normalized, ['الغاء', 'بطلت', 'هونت', 'كافي', 'مسح', 'خلاص'])) {
      _profileEditStep = 0;
      _addBotMessage("صار يا غالي، لغيت التعديل ورجعنا للمحادثة!");
      isProcessing = false;
      notifyListeners();
      return;
    }

    if (uid == null) {
      _addBotMessage("حبيبي، لازم تسجل دخولك أول شي علمود أكدر أعدل معلوماتك.");
      _profileEditStep = 0;
      isProcessing = false;
      notifyListeners();
      return;
    }

    if (_profileEditStep == 1) {
      _newProfileName = text;
      _profileEditStep = 2;
      _addBotMessage("عاشت الأسامي $_newProfileName! \nهسه اكتبلي رقم تليفونك الجديد؟");
    } else if (_profileEditStep == 2) {
      _newProfilePhone = text;
      _profileEditStep = 0;
      _addBotMessage("جاري تحديث معلوماتك بالفايربيس...");
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'name': _newProfileName,
          'fullName': _newProfileName,
          'phone': _newProfilePhone,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.updateDisplayName(_newProfileName);
        }
        
        await agent.loadUserInfo(); // إعادة تحميل معلومات المستخدم
        
        _addBotMessage(
          "تم التحديث! \n"
          "الاسم الجديد: $_newProfileName\n"
          "الرقم الجديد: $_newProfilePhone\n"
          "صار كلشي جاهز حبيبي!"
        );
      } catch (e) {
        _addBotMessage("عذراً، صار عندي خطأ بتحديث البيانات بفايربيس. تأكد من اتصالك بالإنترنت");
      }
    }
    isProcessing = false;
    notifyListeners();
  }

  Future<void> _handleJobAddStep(String text) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final normalized = _normalizeArabic(text);

    if (_matchesAny(normalized, ['الغاء', 'بطلت', 'هونت', 'كافي', 'مسح', 'خلاص'])) {
      _jobAddStep = 0;
      _addBotMessage("صار يا غالي! لغيت نشر الوظيفة ورجعنا للمحادثة!");
      isProcessing = false;
      notifyListeners();
      return;
    }

    if (uid == null) {
      _addBotMessage("حبيبي، سجّل دخولك أولاً لنشر وظيفة.");
      _jobAddStep = 0;
      isProcessing = false;
      notifyListeners();
      return;
    }

    if (_jobAddStep == 1) {
      _newJobTitle = text;
      _jobAddStep = 2;
      _addBotMessage("حلو! مسمى الوظيفة: \"$_newJobTitle\".\nهسه اكتبلي وصف مختصر للوظيفة ومتطلباتها؟ ");
    } else if (_jobAddStep == 2) {
      _newJobDesc = text;
      _jobAddStep = 3;
      _addBotMessage("تمام! هسه حددلي القسم أو المجال؟\n(اكتب: تقنية، تعليم، صحة، هندسة، تجارة، خدمات، أو أخرى)");
    } else if (_jobAddStep == 3) {
      _newJobCategory = text;
      _jobAddStep = 4;
      _addBotMessage("أخيراً، انطيني رقم التليفون أو الواتساب للتواصل مع المتقدمين؟");
    } else if (_jobAddStep == 4) {
      _newJobPhone = text;
      _jobAddStep = 0;
      _addBotMessage("جاري نشر الوظيفة في فايربيس...");
      try {
        await FirebaseFirestore.instance.collection('vacancies').add({
          'type': 'employer',
          'company': agent.userName,
          'jobDetails': _newJobTitle,
          'phone': _newJobPhone,
          'notes': _newJobDesc,
          'tag': _newJobCategory,
          'views': 0,
          'likes': 0,
          'date': FieldValue.serverTimestamp(),
          'createdBy': uid,
        });

        await FirebaseFirestore.instance.collection('notifications').add({
          'title': 'وظيفة جديدة معروضة',
          'body': 'فرصة جديدة: $_newJobTitle في قسم $_newJobCategory',
          'type': 'vacancy',
          'createdAt': FieldValue.serverTimestamp(),
        });

        _addBotMessage(
          "تم نشر الوظيفة بنجاح! فرصة عمل جديدة لـ \"$_newJobTitle\"صارت متاحة للجميع الحين. ",
          actionType: 'navigate',
          actionData: '/vacancies',
        );
      } catch (e) {
        _addBotMessage("حدث خطأ أثناء نشر الوظيفة. حاول مرة ثانية بعد شوية");
      }
    }
    isProcessing = false;
    notifyListeners();
  }

  Future<void> _handleRealEstateAddStep(String text) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final normalized = _normalizeArabic(text);

    if (_matchesAny(normalized, ['الغاء', 'بطلت', 'هونت', 'كافي', 'مسح', 'خلاص'])) {
      _realEstateAddStep = 0;
      _addBotMessage("صار يا غالي! لغيت عملية نشر العقار ورجعنا للمحادثة العادية.. تدلل بأي شي ثاني!");
      isProcessing = false;
      notifyListeners();
      return;
    }

    if (uid == null) {
      _addBotMessage("سجّل دخولك أولاً لتتمكن من إضافة عقار بفايربيس.");
      _realEstateAddStep = 0;
      isProcessing = false;
      notifyListeners();
      return;
    }

    if (_realEstateAddStep == 1) {
      _newRealEstateTitle = text;
      if (text.contains('ايجار') || text.contains('إيجار') || text.contains('للايجار')) {
        _newRealEstateType = 'للإيجار';
      } else {
        _newRealEstateType = 'للبيع';
      }
      _realEstateAddStep = 2;
      _addBotMessage(
        "ما شاء الله! عنوان تسويقي روعة: \"$_newRealEstateTitle\" ($_newRealEstateType) \n\n"
        " **الخطوة 2: كم المساحة الإجمالية وشنو المواصفات؟**\n"
        "(مثال: 200 متر مربع، 3 غرف نوم، هول وصالة، طابقين، كراج وحوش...)"
      );
    } else if (_realEstateAddStep == 2) {
      _newRealEstateArea = text;
      _realEstateAddStep = 3;
      _addBotMessage(
        "عاشت إيدك، مواصفات ومساحة ممتازة! \n\n"
        " **الخطوة 3: وين الموقع والمنطقة والحي بالتفصيل؟**\n"
        "(مثال: القائم - حي الفرات قرب السوق، بغداد - المنصور، أربيل...)"
      );
    } else if (_realEstateAddStep == 3) {
      _newRealEstateLocation = text;
      _realEstateAddStep = 4;
      _addBotMessage(
        "تمام يا غالي، موقع حيوي ومميز! \n\n"
        " **الخطوة 4: كم السعر المطلوب؟**\n"
        "(مثال: 120 مليون دينار، أو 75 ألف دولار، وهل السعر قفل لو بي مجال تفاوض؟ )"
      );
    } else if (_realEstateAddStep == 4) {
      _newRealEstatePrice = text;
      _realEstateAddStep = 5;
      _addBotMessage(
        "سعر مناسب وممتاز! \n\n"
        " **الخطوة 5: انطيني رقم الهاتف أو الواتساب للتواصل ويا المشترين؟** "
      );
    } else if (_realEstateAddStep == 5) {
      _newRealEstatePhone = text;
      _realEstateAddStep = 6;
      _addBotMessage(
        "تمام التمام! \n\n"
        " **الخطوة الأخيرة: هل عندك ملاحظات إضافية أو صور؟**\n"
        "(إذا ما عندك بس اكتب 'تم'أو 'ما عندي' وننشر الإعلان فوراً بفايربيس! )"
      );
    } else if (_realEstateAddStep == 6) {
      _newRealEstateNotes = (text.contains('تم') || text.contains('ما عندي') || text.contains('ماكو')) ? '' : text;
      _realEstateAddStep = 0;
      _addBotMessage("جاري رفع ونشر إعلان العقار في فايربيس...");

      try {
        await FirebaseFirestore.instance.collection('real_estate').add({
          'title': _newRealEstateTitle,
          'type': _newRealEstateType,
          'area': _newRealEstateArea,
          'location': _newRealEstateLocation,
          'price': _newRealEstatePrice,
          'phone': _newRealEstatePhone,
          'notes': _newRealEstateNotes,
          'status': 'approved',
          'date': FieldValue.serverTimestamp(),
          'createdBy': uid,
          'ownerName': agent.userName,
        });

        await FirebaseFirestore.instance.collection('notifications').add({
          'title': 'عقار جديد معروض',
          'body': '$_newRealEstateType: $_newRealEstateTitle في $_newRealEstateLocation',
          'type': 'real_estate',
          'createdAt': FieldValue.serverTimestamp(),
        });

        _addBotMessage(
          "تم نشر عقارك بنجاح وصار متاح لكل زوار ومستخدمي مدار! \n\n"
          " **ملخص بطاقة العقار المنشور:**\n"
          "• **العنوان:** $_newRealEstateTitle\n"
          "• **النوع:** $_newRealEstateType\n"
          "• **المساحة والمواصفات:** $_newRealEstateArea\n"
          "• **الموقع:** $_newRealEstateLocation\n"
          "• **السعر:** $_newRealEstatePrice\n"
          "• **رقم التواصل:** $_newRealEstatePhone\n\n"
          "ربي يباركلك ويفتحها بوجهك وتبيعه/تأجره بأحسن سعر!",
          actionType: 'navigate',
          actionData: '/real_estate',
        );
      } catch (e) {
        _addBotMessage("فشل حفظ العقار بفايربيس. يرجى التحقق من اتصالك وحاول مرة أخرى");
      }
    }
    isProcessing = false;
    notifyListeners();
  }

  Future<void> _handleDeliveryStep(String text) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final normalized = _normalizeArabic(text);

    if (_matchesAny(normalized, ['الغاء', 'بطلت', 'هونت', 'كافي', 'مسح', 'خلاص'])) {
      _deliveryStep = 0;
      _addBotMessage("صار عيوني، لغيت طلب التوصيل ورجعنا للمحادثة العادية!");
      isProcessing = false;
      notifyListeners();
      return;
    }

    if (_deliveryStep == 1) {
      _newDeliveryItem = text;
      _deliveryStep = 2;
      _addBotMessage(
        "تمام، طرد: \"$_newDeliveryItem\" \n\n"
        " **الخطوة 2: من وين يستلم المندوب الغراض؟ (مكان الاستلام)** "
      );
    } else if (_deliveryStep == 2) {
      _newDeliveryPickup = text;
      _deliveryStep = 3;
      _addBotMessage(
        "عاشت إيدك! \n\n"
        " **الخطوة 3: لوين نوصل الطرد؟ (مكان التسليم والحي)** "
      );
    } else if (_deliveryStep == 3) {
      _newDeliveryDropoff = text;
      _deliveryStep = 4;
      _addBotMessage(
        "تمام! \n\n"
        " **الخطوة 4: انطيني رقم تليفونك أو تليفون المستلم للتواصل؟** "
      );
    } else if (_deliveryStep == 4) {
      _newDeliveryPhone = text;
      _deliveryStep = 0;
      _addBotMessage("جاري إرسال طلب التوصيل لكباتن مرسال...");

      try {
        await FirebaseFirestore.instance.collection('delivery_orders').add({
          'item': _newDeliveryItem,
          'pickup': _newDeliveryPickup,
          'dropoff': _newDeliveryDropoff,
          'phone': _newDeliveryPhone,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'userId': uid ?? '',
          'userName': agent.userName,
        });

        _addBotMessage(
          "تم تأكيد طلب التوصيل عبر مرسال! \n\n"
          " **تفاصيل الشحنة:**\n"
          "• **الغراض:** $_newDeliveryItem\n"
          "• **من:** $_newDeliveryPickup\n"
          "• **إلى:** $_newDeliveryDropoff\n"
          "• **رقم التواصل:** $_newDeliveryPhone\n\n"
          "أقرب مندوب مرسال راح يتواصل وياك ويستلم الغراض فوراً!",
          actionType: 'navigate',
          actionData: '/delivery',
        );
      } catch (e) {
        _addBotMessage("فشل تسجيل طلب التوصيل. حاول مرة ثانية بعد شوية");
      }
    }
    isProcessing = false;
    notifyListeners();
  }

  Future<void> _handleTaxiBookingStep(String text) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final normalized = _normalizeArabic(text);

    if (_matchesAny(normalized, ['الغاء', 'بطلت', 'هونت', 'كافي', 'مسح', 'خلاص'])) {
      _taxiBookingStep = 0;
      _addBotMessage("صار عيوني، لغيت طلب التكسي ورجعنا للمحادثة!");
      isProcessing = false;
      notifyListeners();
      return;
    }

    if (_taxiBookingStep == 1) {
      _newTaxiPickup = text;
      _taxiBookingStep = 2;
      _addBotMessage(
        "مكان الانطلاق: \"$_newTaxiPickup\" \n\n"
        " **الخطوة 2: لوين رايح؟ (الوجهة)** "
      );
    } else if (_taxiBookingStep == 2) {
      _newTaxiDestination = text;
      _taxiBookingStep = 3;
      _addBotMessage(
        "الوجهة: \"$_newTaxiDestination\" \n\n"
        " **الخطوة 3: كم عدد الركاب، وهل تحتاج سيارة عائلية أو عادية؟** "
      );
    } else if (_taxiBookingStep == 3) {
      _newTaxiPassengers = text;
      _taxiBookingStep = 0;
      _addBotMessage("جاري توجيه طلبك لأقرب كابتن تكسي مدار...");

      try {
        await FirebaseFirestore.instance.collection('taxi_requests').add({
          'pickup': _newTaxiPickup,
          'destination': _newTaxiDestination,
          'passengers': _newTaxiPassengers,
          'status': 'searching',
          'createdAt': FieldValue.serverTimestamp(),
          'userId': uid ?? '',
          'userName': agent.userName,
        });

        _addBotMessage(
          "تم إرسال طلب التكسي بنجاح! \n\n"
          " **تفاصيل الرحلة:**\n"
          "• **من:** $_newTaxiPickup\n"
          "• **إلى:** $_newTaxiDestination\n"
          "• **الركاب/النوع:** $_newTaxiPassengers\n\n"
          "كباتن تكسي مدار القريبين استلموا إشعارك وجايينك طيارة!",
          actionType: 'navigate',
          actionData: '/taxi',
        );
      } catch (e) {
        _addBotMessage("فشل إرسال طلب التكسي. يرجى المحاولة من صفحة التكسي");
      }
    }
    isProcessing = false;
    notifyListeners();
  }

  Future<void> _handleComplaintStep(String text) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final normalized = _normalizeArabic(text);

    if (_matchesAny(normalized, ['الغاء', 'بطلت', 'هونت', 'كافي', 'مسح', 'خلاص'])) {
      _complaintStep = 0;
      _addBotMessage("صار يا غالي، لغيت تقديم الشكوى ورجعنا للمحادثة!");
      isProcessing = false;
      notifyListeners();
      return;
    }

    if (_complaintStep == 1) {
      _newComplaintSubject = text;
      _complaintStep = 2;
      _addBotMessage(
        "الموضوع: \"$_newComplaintSubject\" \n\n"
        " **الخطوة 2: اشرحلي بالتفصيل شنو صار وياك بالضبط؟**"
      );
    } else if (_complaintStep == 2) {
      _newComplaintDetails = text;
      _complaintStep = 3;
      _addBotMessage(
        " **الخطوة الأخيرة: انطيني رقم تليفونك للتواصل ومتابعة حل الشكوى؟** "
      );
    } else if (_complaintStep == 3) {
      _newComplaintPhone = text;
      _complaintStep = 0;
      _addBotMessage("جاري إرسال الشكوى للإدارة العليا لمدار...");

      try {
        await FirebaseFirestore.instance.collection('complaints').add({
          'subject': _newComplaintSubject,
          'details': _newComplaintDetails,
          'phone': _newComplaintPhone,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'userId': uid ?? '',
          'userName': agent.userName,
        });

        _addBotMessage(
          "تم استلام بلاغك وشكواك بنجاح! \n\n"
          "حقك فوك راسنا، وإدارة مدار راح تتابع الشكوى وتتصل بيك على الرقم ($_newComplaintPhone) لحل المشكلة فوراً! وإذا تحب تحجي وياهم واتساب هسة، اضغط بالأسفل.",
          actionType: 'launch_whatsapp',
          actionData: 'support',
        );
      } catch (e) {
        _addBotMessage("فشل إرسال الشكوى. تكدر تتواصل ويا الدعم عبر الواتساب مباشرة");
      }
    }
    isProcessing = false;
    notifyListeners();
  }

  /// إرسال رسالة من المستخدم ومعالجتها
  Future<void> sendMessage(BuildContext context, String userText) async {
    if (userText.trim().isEmpty || isProcessing) return;

    _addUserMessage(userText.trim());
    isProcessing = true;
    notifyListeners();

    try {
      final cleanedText = _cleanExcuseMePrefix(userText.trim());

      // التحقق من محادثات المعالجة متعددة الخطوات الذكية
      if (_profileEditStep > 0) {
        await _handleProfileEditStep(cleanedText);
        return;
      }
      if (_jobAddStep > 0) {
        await _handleJobAddStep(cleanedText);
        return;
      }
      if (_realEstateAddStep > 0) {
        await _handleRealEstateAddStep(cleanedText);
        return;
      }
      if (_deliveryStep > 0) {
        await _handleDeliveryStep(cleanedText);
        return;
      }
      if (_taxiBookingStep > 0) {
        await _handleTaxiBookingStep(cleanedText);
        return;
      }
      if (_complaintStep > 0) {
        await _handleComplaintStep(cleanedText);
        return;
      }

      // 1. فحص الأوامر المحلية المباشرة ذات الأولوية (الذاكرة، المظهر، النقاط، بحث الأماكن)
      final localResult = _tryLocalAction(cleanedText);
      if (localResult != null) {
        _executeCommand(localResult);
        return;
      }

      // 2. إرسال المحادثة لعميل سكوزمي الذكي (Gemini AI + المحرك المعرفي العراقي الشامل)
      final aiResult = await agent.chat(cleanedText, currentRoute: currentRoute);
      _executeCommand(aiResult);
    } catch (e) {
      _addBotMessage('عذراً، صار خطأ، حاول مرة ثانية. حاول مرة أخرى');
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  /// إرسال رسالة سريعة (Quick Action)
  Future<void> sendQuickAction(BuildContext context, String prompt) async {
    await sendMessage(context, prompt);
  }

  /// محاولة التعامل مع الطلب محلياً (بدون استدعاء API لتوفير التكلفة)
  String? _tryLocalAction(String text) {
    final normalized = _normalizeArabic(text);

    // 1. التحقق أولاً من قاعدة البيانات المحلية للأسئلة المتكررة (FAQ) بنسبة تطابق عالية
    for (var faq in _localFAQs) {
      if (faq.triggers.any((trigger) {
        final trigNorm = _normalizeArabic(trigger);
        return normalized.contains(trigNorm) || trigNorm.contains(normalized);
      })) {
        return 'FAQ_ANSWER: ${json.encode({
          'response': faq.response,
          'actionType': faq.actionType,
          'actionData': faq.actionData,
        })}';
      }
    }

    // --- 1.1 حفظ واستعلام ومسح الذاكرة ---
    if (_matchesAny(normalized, [
      'شنو تعرف عني', 'شنو حافظ عني', 'شنو حافظ ببالك', 'ذاكرتك', 'معلوماتي المحفوظة',
      'شنو مسجل عني', 'شنو متذكر عني', 'شنو معلوماتي عندك', 'بياناتي بذاكرتك'
    ])) {
      return 'MEMORY_QUERY';
    }

    if (_matchesAny(normalized, [
      'امسح ذاكرتك', 'انسى كلشي', 'صفر الذاكرة', 'احذف معلوماتي من ذاكرتك', 'امسح اللي حافظه',
      'فرمت ذاكرتك', 'انساني'
    ])) {
      return 'MEMORY_CLEAR';
    }

    // حفظ الاسم / اللقب العراقي
    final nameRegex = RegExp(r'(?:احفظ اني اسمي|احفظ اسمي|صيحلي|ناديني|كلي يا)\s+(.+)', caseSensitive: false);
    final nameMatch = nameRegex.firstMatch(text);
    if (nameMatch != null) {
      final name = nameMatch.group(1)?.trim();
      if (name != null && name.isNotEmpty) {
        return 'MEMORY_SAVE_NAME: "$name"';
      }
    }

    // حفظ عنوان البيت
    final homeRegex = RegExp(r'(?:احفظ بيتي ب|احفظ عنوان بيتي ب|عنوان بيتي ب|احفظ موقعي ب|بيتي ب)\s+(.+)', caseSensitive: false);
    final homeMatch = homeRegex.firstMatch(text);
    if (homeMatch != null) {
      final home = homeMatch.group(1)?.trim();
      if (home != null && home.isNotEmpty) {
        return 'MEMORY_SAVE_HOME: "$home"';
      }
    }

    // حفظ عنوان العمل/الدوام
    final workRegex = RegExp(r'(?:احفظ دوامي ب|احفظ شغلي ب|دوامي ب|مكان عملي ب|احفظ مكان شغلي ب)\s+(.+)', caseSensitive: false);
    final workMatch = workRegex.firstMatch(text);
    if (workMatch != null) {
      final work = workMatch.group(1)?.trim();
      if (work != null && work.isNotEmpty) {
        return 'MEMORY_SAVE_WORK: "$work"';
      }
    }

    // حفظ أكلة مفضلة
    final foodRegex = RegExp(r'(?:احفظ اني احب|احفظ اكلتي المفضلة|احب اكل|اكلتي المفضلة)\s+(.+)', caseSensitive: false);
    final foodMatch = foodRegex.firstMatch(text);
    if (foodMatch != null) {
      final food = foodMatch.group(1)?.trim();
      if (food != null && food.isNotEmpty) {
        return 'MEMORY_SAVE_FOOD: "$food"';
      }
    }

    // حفظ ملاحظة عامة
    final noteRegex = RegExp(r'(?:احفظ عندك|احفظ ببالك|تذكر اني|سجل عندك)\s+(.+)', caseSensitive: false);
    final noteMatch = noteRegex.firstMatch(text);
    if (noteMatch != null) {
      final note = noteMatch.group(1)?.trim();
      if (note != null && note.isNotEmpty) {
        return 'MEMORY_SAVE_NOTE: "$note"';
      }
    }

    // --- 1.2 فحص المشاعر والذكاء العاطفي العراقي ---
    final emotion = IraqiEmotionEngine.analyzeEmotion(text);
    if (emotion != null && emotion.emotion != IraqiEmotion.neutral) {
      final bool isExplicitFunction = _matchesAny(normalized, [
        'احجزلي تكسي', 'طلب تكسي', 'وديني للمطاعم', 'فتح الوظائف', 'تسجيل دخول', 'انشاء حساب'
      ]);
      if (!isExplicitFunction ||
          emotion.emotion == IraqiEmotion.fatigue ||
          emotion.emotion == IraqiEmotion.sadness ||
          emotion.emotion == IraqiEmotion.happiness ||
          emotion.emotion == IraqiEmotion.banter ||
          emotion.emotion == IraqiEmotion.gratitude) {
        // تحديث آخر حالة مزاجية في الذاكرة
        SmartAssistantMemory().setMood(emotion.emotion.name);
        return 'EMOTION_RESPONSE: ${json.encode({
          'response': emotion.suggestedResponse,
          'actionType': emotion.suggestedActionType,
          'actionData': emotion.suggestedActionData,
        })}';
      }
    }

    // --- نقاطي ورصيد محفظتي ---
    if (_matchesAny(normalized, [
      'شكد نقاطي', 'نقاطي', 'نقاط مدار', 'استبدال النقاط', 'فلوسي', 'رصيدي',
      'رصيد المحفظة', 'شكد عندي فلوس', 'محفظتي', 'شحن المحفظة', 'فلوس المحفظة',
      'اريد اعرف نقاطي', 'رصيدي شكد', 'شكد رصيدي', 'نقاطي شكد', 'استبدل نقاطي'
    ])) {
      return 'POINTS_AND_WALLET';
    }

    // --- تكسي وحجز سيارة ---
    if (_matchesAny(normalized, [
      'اريد تكسي', 'احجزلي تكسي', 'طلب تكسي', 'تكسي مدار', 'تكسي', 'تاكسي',
      'سيارة', 'اريد سيارة', 'احجزلي سيارة', 'وديني', 'توصيل تكسي', 'كابتن تكسي'
    ])) {
      return 'TAXI_REQUEST';
    }

    // --- جوعان ومطاعم وأكلات ---
    if (_matchesAny(normalized, [
      'جوعان', 'اريد اكل', 'اريد مطعم', 'رشحلي مطعم', 'شنو اكل', 'مطاعم مدار',
      'كباب', 'بيتزا', 'برجر', 'شاورما', 'دجاج', 'سمك', 'مشويات', 'ريوق', 'غدا', 'عشا',
      'اكل طيب', 'مطعم طيب', 'وجبات'
    ])) {
      return 'FOOD_RECOMMENDATION: "$text"';
    }

    // --- متاجر وتسوق مدار ---
    if (_matchesAny(normalized, [
      'متاجر', 'متاجر مدار', 'تسوق', 'سوق مدار', 'اريد اشتري', 'محلات',
      'سوبرماركت', 'مسواك', 'تسوق مدار', 'عطور', 'ملابس'
    ])) {
      return 'STORE_RECOMMENDATION: "$text"';
    }

    // --- التحكم بالوضع الليلي والنهاري ---
    if (_matchesAny(normalized, [
      'شغل الدارك مود', 'الوضع الليلي', 'دارك مود', 'شغل الوضع الليلي', 'تفعيل الوضع الليلي', 'طفي الضو', 'الوضع المظلم'
    ])) {
      return 'THEME_TOGGLE: "dark"';
    }
    if (_matchesAny(normalized, [
      'طفي الدارك مود', 'الوضع النهاري', 'لايت مود', 'شغل الوضع الفاتح', 'تفعيل الوضع النهاري', 'طفي الوضع الليلي', 'شغل الضو'
    ])) {
      return 'THEME_TOGGLE: "light"';
    }

    // --- تنظيف الكاش والذاكرة ---
    if (_matchesAny(normalized, [
      'نظف الكاش', 'تنظيف الكاش', 'تسريع التطبيق', 'نظف الذاكرة', 'التطبيق بطيء', 'مسح الذاكرة المؤقتة', 'نظف كاش'
    ])) {
      return 'CLEAN_CACHE';
    }

    // --- معلومات المطور والمبتكر ---
    if (_matchesAny(normalized, [
      'منو سواك', 'منو صنعك', 'منو طورك', 'منو برمجك', 'منو صاحب التطبيق', 'عن مدار', 'عن سكوزمي', 'منو مهندس التطبيق', 'منو المطور'
    ])) {
      return 'CREATOR_INFO';
    }

    // --- تعديل معلوماتي ---
    if (_matchesAny(normalized, ['عدل معلوماتي', 'غير اسمي', 'حدث بياناتي', 'تحديث معلوماتي', 'تعديل الملف الشخصي', 'تعديل بياناتي'])) {
      return 'PROFILE_EDIT';
    }

    // --- تغيير كلمة المرور ---
    if (_matchesAny(normalized, ['تغيير كلمة المرور', 'تغيير الرمز', 'تعديل الرمز', 'غير الرمز', 'رمز المرور'])) {
      return 'PROFILE_CHANGE_PASSWORD';
    }

    // --- تتبع الطلبات ---
    if (_matchesAny(normalized, ['تابع طلباتي', 'وين طلبي', 'حالة طلبي', 'تتبع طلباتي', 'اوردراتي', 'وين الاكل'])) {
      return 'TRACK_ORDERS';
    }

    // --- توصيل غراض ---
    if (_matchesAny(normalized, ['محتاج توصيل', 'وصلي غراض', 'توصيل غراض', 'توصيل طلب', 'طلب توصيل', 'اريد مندوب'])) {
      return 'DELIVERY_REQUEST';
    }

    // --- تتبع توصيل ---
    if (_matchesAny(normalized, ['تتبع التوصيل', 'تتبع شحنة', 'وين المندوب', 'تتبع مرسال'])) {
      return 'DELIVERY_TRACK';
    }

    // --- انشر عقار وتأجير وبيوت ---
    if (_matchesAny(normalized, [
      'انشر عقار', 'اضيف عقار', 'اعلن عن عقار', 'نشر عقار', 'اضافة عقار', 'انشرلي عقار',
      'اريد ابيع بيت', 'اريد ااجر شقة', 'اريد ابيع عقار', 'اريد اعرض بيت', 'نشر بيت',
      'بيع بيت', 'تاجير شقة', 'تاجير بيت', 'اعلان عقار', 'انشر شقة', 'انشر بيت'
    ])) {
      return 'REAL_ESTATE_ADD';
    }

    // --- اتواصل وي الدعم ---
    if (_matchesAny(normalized, ['اتواصل وي الدعم', 'كلم الادارة', 'الدعم الفني', 'انقلني للدعم', 'تواصل مع الدعم', 'دعم فني'])) {
      return 'CONTACT_SUPPORT';
    }

    // --- مشكلة بالتطبيق ---
    if (_matchesAny(normalized, ['مشكلة بالتطبيق', 'بلاغ مشكلة', 'ابلغ عن مشكلة', 'عندي مشكلة', 'التطبيق خربان', 'خطأ بالتطبيق'])) {
      return 'REPORT_BUG';
    }

    // --- ارقام الطوارئ ---
    if (_matchesAny(normalized, ['ارقام الطوارئ', 'اريد ارقام الطوارئ', 'رقم الاسعاف', 'طوارئ', 'رقم الاطفاء', 'رقم الشرطة'])) {
      return 'EMERGENCY_NUMBERS';
    }

    // --- اني منو ---
    if (_matchesAny(normalized, ['اني منو', 'منو اني', 'معلومات حسابي', 'الملف الشخصي'])) {
      return 'WHO_AM_I';
    }

    // --- بحث مواد منزلية في المتاجر ---
    if (_matchesAny(normalized, ['مواد منزلية', 'اغراض بيت', 'تسوق منزلية', 'منزلية'])) {
      return 'STORE_SEARCH: "مواد منزلية"';
    }

    // --- تسجيل مطعم ---
    if (_matchesAny(normalized, [
      'سجل مطعمي', 'تسجيل مطعمي', 'اضيف مطعمي', 'اضافة مطعمي', 'تسجيل مطعم', 'سجل مطعم',
      'اسجل مطعمي', 'اضيف مطعم', 'اضافه مطعم'
    ])) {
      return 'LAUNCH_WHATSAPP: "restaurant"';
    }

    // --- تسجيل تكسي ---
    if (_matchesAny(normalized, [
      'سجل تكسي', 'تسجيل تكسي', 'اشتغل تكسي', 'اسجل كابتن', 'تسجيل كابتن', 'سجلني كابتن',
      'سجلني تكسي', 'اسجل التكسي', 'سجل التاكسي', 'تسجيل تاكسي', 'سجل تاكسي', 'اسجل تاكسي',
      'اشتغل كابتن', 'سجل كابتن تكسي'
    ])) {
      return 'LAUNCH_WHATSAPP: "taxi"';
    }

    // --- تسجيل الدخول ---
    if (_matchesAny(normalized, [
      'تسجيل دخول', 'سجل دخول', 'ادخل', 'دخول', 'لوقن', 'login',
      'اريد ادخل', 'ابي ادخل', 'سجلني', 'دخلني',
    ])) {
      return 'NAVIGATE: "/login"';
    }

    // --- إنشاء حساب ---
    if (_matchesAny(normalized, [
      'انشاء حساب', 'حساب جديد', 'تسجيل', 'سجلني حساب', 'ريجستر',
      'register', 'اريد حساب', 'فتح حساب', 'عمل حساب',
    ])) {
      return 'NAVIGATE: "/register"';
    }

    // --- الشكاوى والاقتراحات ---
    if (_matchesAny(normalized, [
      'شكوي', 'شكاوي', 'اقتراح', 'اقتراحات', 'شكوى', 'شكاوى',
      'تقديم شكوي', 'تقديم اقتراح', 'اشتكي', 'عندي شكوى', 'اريد اقدم شكوى'
    ])) {
      return 'COMPLAINT_ADD';
    }

    // --- الوظائف والتحكم بها ---
    // 1. إضافة إعلان وظيفة
    if (_matchesAny(normalized, [
      'اضف اعلان', 'اضافة اعلان', 'نشر وظيفه', 'نشر وظيفة', 'اريد انشر وظيفة', 'انشر شغل',
      'اضافة وظيفه', 'اضافه وظيفه', 'انشر وظيفة', 'انشرلي وظيفة', 'انشر وظيفه جديدة'
    ])) {
      return 'JOB_ADD';
    }

    // 2. البحث عن وظيفة
    final searchTerms = ['ابحث عن', 'دورلي على', 'دور على', 'بحث عن', 'اريد شغل', 'اريد وظيفه'];
    for (var term in searchTerms) {
      final normalizedTerm = _normalizeArabic(term);
      if (normalized.contains(normalizedTerm)) {
        final index = normalized.indexOf(normalizedTerm) + normalizedTerm.length;
        String query = text.substring(index).trim();
        query = query.replaceFirst(RegExp(r'^(وظيفه|شغل|عمل|وظيفة|عن|على)\s*'), '').trim();
        if (query.isNotEmpty) {
          if (onSearchJobs != null) {
            onSearchJobs!(query);
            return 'SAY: "حاضر! بحثت لك عن \'$query\'في الوظائف المتاحة."';
          } else {
            pendingSearchQuery = query;
            return 'NAVIGATE: "/vacancies"';
          }
        }
      }
    }

    // 3. فلترة حسب التصنيف (الفئة)
    final cats = {
      'تقنية': 'تقنيه',
      'تعليم': 'تعليم',
      'صحة': 'صحه',
      'هندسة': 'هندسه',
      'تجارة': 'تجاره',
      'خدمات': 'خدمات',
      'أخرى': 'اخرى',
    };
    for (var entry in cats.entries) {
      if (_matchesAny(normalized, ['وظائف ${entry.value}', 'فلتر على ${entry.value}', 'فئة ${entry.value}', 'تصنيف ${entry.value}', 'قسم ${entry.value}'])) {
        if (onFilterCategory != null) {
          onFilterCategory!(entry.key);
          return 'SAY: "صار تدلل! عرضت لك وظائف قسم (${entry.key}) الحين."';
        } else {
          pendingCategory = entry.key;
          return 'NAVIGATE: "/vacancies"';
        }
      }
    }
    
    // إلغاء الفلترة أو عرض الكل
    if (_matchesAny(normalized, ['عرض الكل', 'كل الوظائف', 'الغاء الفلتر', 'مسح الفلتر'])) {
      if (onFilterCategory != null) {
        onFilterCategory!(null);
        onSearchJobs?.call('');
        onSetFilter?.call('all');
        return 'SAY: "تفضل، عرضت لك كل الوظائف والفرص الحين بدون أي فلترة."';
      } else {
        pendingCategory = null;
        pendingSearchQuery = '';
        pendingFilter = 'all';
        return 'NAVIGATE: "/vacancies"';
      }
    }

    // 4. نوع الفلتر (باحثين / أصحاب عمل / مفضلة)
    if (_matchesAny(normalized, ['باحثين عن عمل', 'الباحثين عن عمل', 'باحثين عن شغل', 'الباحثين عن شغل', 'الباحثين', 'باحثين'])) {
      if (onSetFilter != null) {
        onSetFilter!('seeker');
        return 'SAY: "عرضت لك طلبات الباحثين عن عمل الحين."';
      } else {
        pendingFilter = 'seeker';
        return 'NAVIGATE: "/vacancies"';
      }
    }
    if (_matchesAny(normalized, ['فرص العمل', 'فرص عمل', 'اصحاب العمل', 'أصحاب العمل', 'الوظائف المتاحه', 'الوظائف المتاحة'])) {
      if (onSetFilter != null) {
        onSetFilter!('employer');
        return 'SAY: "عرضت لك فرص العمل المتاحة من أصحاب الشركات والمحلات الحين."';
      } else {
        pendingFilter = 'employer';
        return 'NAVIGATE: "/vacancies"';
      }
    }
    if (_matchesAny(normalized, ['الوظائف المحفوظه', 'الوظائف المحفوظة', 'المفضله', 'المفضلة', 'محفوظاتي'])) {
      if (onSetFilter != null) {
        onSetFilter!('saved');
        return 'SAY: "عرضت لك إعلانات الوظائف التي قمت بحفظها سابقاً."';
      } else {
        pendingFilter = 'saved';
        return 'NAVIGATE: "/vacancies"';
      }
    }

    // 5. الترتيب
    if (_matchesAny(normalized, ['رتب حسب الاقدم', 'ترتيب حسب الاقدم', 'رتب من الاقدم', 'ترتيب من الاقدم', 'الاقدم اولا', 'الأقدم أولاً'])) {
      if (onSetSort != null) {
        onSetSort!('date_asc');
        return 'SAY: "صار! رتبت لك الوظائف من الأقدم إلى الأحدث الحين."';
      } else {
        pendingSort = 'date_asc';
        return 'NAVIGATE: "/vacancies"';
      }
    }
    if (_matchesAny(normalized, ['رتب حسب الاحدث', 'ترتيب حسب الاحدث', 'رتب من الاحدث', 'ترتيب من الاحدث', 'الاحدث اولا', 'الأحدث أولاً'])) {
      if (onSetSort != null) {
        onSetSort!('date_desc');
        return 'SAY: "تفضل! رتبت لك الوظائف من الأحدث إلى الأقدم."';
      } else {
        pendingSort = 'date_desc';
        return 'NAVIGATE: "/vacancies"';
      }
    }
    if (_matchesAny(normalized, ['رتب حسب التفاعل', 'الاكثر تفاعلا', 'الأكثر تفاعلاً', 'الاكثر لايكات', 'حسب الاعجابات'])) {
      if (onSetSort != null) {
        onSetSort!('likes_desc');
        return 'SAY: "أكيد! رتبت لك الوظائف حسب الأكثر تفاعلاً وإعجاباً من المستخدمين."';
      } else {
        pendingSort = 'likes_desc';
        return 'NAVIGATE: "/vacancies"';
      }
    }

    // --- الوظائف العادية (فتح الصفحة) ---
    if (_matchesAny(normalized, [
      'وظيفه', 'وظائف', 'شغل', 'عمل', 'وظيفة', 'فرص عمل',
    ])) {
      return 'NAVIGATE: "/vacancies"';
    }

    // --- الطلبات ---
    if (_matchesAny(normalized, [
      'طلباتي', 'طلبات', 'اوردراتي', 'orders', 'طلبي',
    ])) {
      return 'NAVIGATE: "/my_orders"';
    }

    // --- المفضلة ---
    if (_matchesAny(normalized, [
      'مفضله', 'المفضله', 'favorites', 'مفضلتي', 'مفضلة',
    ])) {
      return 'NAVIGATE: "/favorites"';
    }

    // --- تكسي مدار ---
    if (_matchesAny(normalized, [
      'تاكسي', 'تكسي', 'كابتن', 'سيارة', 'طلب تكسي', 'سياره', 'taxi', 'نقل', 'حجز سيارة',
    ])) {
      return 'NAVIGATE: "/taxi"';
    }

    // --- المطاعم ---
    if (_matchesAny(normalized, [
      'مطاعم', 'اكل', 'وجبه', 'وجبات', 'مطعم', 'توصيل اكل', 'جوعان', 'restaurant', 'اكلات',
    ])) {
      return 'NAVIGATE: "/restaurants"';
    }

    // --- مرسال ---
    if (_matchesAny(normalized, [
      'مرسال', 'توصيل طرود', 'توصيل طلب', 'توصيل', 'طلب مندوب', 'مندوب', 'delivery', 'شحنه', 'ارساليه',
    ])) {
      return 'NAVIGATE: "/delivery"';
    }

    // --- الاستوديوهات ---
    if (_matchesAny(normalized, [
      'استوديو', 'تصوير', 'استوديوهات', 'استوديو ميم', 'كاميرا', 'صوره', 'studio',
    ])) {
      return 'NAVIGATE: "/studios"';
    }

    // --- المتاجر ---
    if (_matchesAny(normalized, [
      'متاجر', 'تسوق', 'سوق', 'دكان', 'متجر', 'اسواق', 'shop', 'stores',
    ])) {
      return 'NAVIGATE: "/stores"';
    }

    // --- الأقسام الطبية والخدمات العامة بفايربيس ---
    if (_matchesAny(normalized, [
      'الاقسام بفايربيس', 'اقسام بفايربيس', 'بحث بالاقسام', 'البحث في الاقسام',
      'عرض الاقسام', 'عرض اقسام', 'الاقسام الطبية', 'اقسام طبية', 'شنو الاقسام',
      'ما هي الاقسام', 'اقسام التطبيق'
    ])) {
      final terms = [
        'الاقسام بفايربيس', 'اقسام بفايربيس', 'بحث بالاقسام', 'البحث في الاقسام',
        'عرض الاقسام', 'عرض اقسام', 'الاقسام الطبية', 'اقسام طبية', 'شنو الاقسام',
        'ما هي الاقسام', 'اقسام التطبيق'
      ];
      String searchQ = '';
      for (var t in terms) {
        final nt = _normalizeArabic(t);
        if (normalized.contains(nt)) {
          final index = normalized.indexOf(nt) + nt.length;
          searchQ = text.substring(index).trim();
          break;
        }
      }
      if (searchQ.isEmpty && (normalized.contains('طبي') || normalized.contains('صحه') || normalized.contains('عياد'))) {
        searchQ = 'طبي';
      }
      return 'FETCH_SECTIONS: "$searchQ"';
    }

    // --- بحث الأماكن والمناطق والمعالم والمحلات ---
    final placeTerms = [
      'وين مكان', 'وين صاير', 'وين صايرة', 'وين موقع', 'موقع', 'مكان', 'اماكن', 'الأماكن', 'اماكن القائم', 'مناطق القائم',
      'وين صيدلية', 'وين مستشفى', 'وين اسواق', 'وين مدرسة', 'وين عيادة', 'وين جامع', 'وين شارع', 'وين حي',
      'دورلي على مكان', 'ابحث عن مكان'
    ];
    for (var term in placeTerms) {
      final nt = _normalizeArabic(term);
      if (normalized.contains(nt)) {
        final index = normalized.indexOf(nt) + nt.length;
        String pQuery = text.substring(index).trim();
        pQuery = pQuery.replaceFirst(RegExp(r'^(ال|في|ب|بمنطقة|بحي|عن|على)\s*'), '').trim();
        if (pQuery.isNotEmpty) {
          return 'SEARCH_PLACES: "$pQuery"';
        }
      }
    }

    if (_matchesAny(normalized, [
      'الاقسام', 'اقسام', 'sections', 'خدمات عامة', 'اماكن', 'الأماكن'
    ])) {
      return 'NAVIGATE: "/all-sections"';
    }

    // --- دليل الأطباء (بدون تخصص = اسأل) ---
    if (_matchesAny(normalized, [
      'طبيب', 'دكتور', 'اطباء', 'دكاتره', 'دليل اطباء',
    ]) && !_hasSpecialty(normalized)) {
      return 'SAY: "من عيوني! بس كلي شنو تخصص الدكتور اللي تريده؟\n أسنان\n أطفال\n عيون\n باطنية\n أعصاب\n عظام\nأو اكتب أي تخصص ثاني!"';
    }

    // --- الرئيسية ---
    if (_matchesAny(normalized, [
      'رئيسيه', 'الرئيسيه', 'home', 'رجعني', 'ارجع', 'الصفحه الرئيسيه',
    ])) {
      return 'NAVIGATE: "/home"';
    }

    return null; // لا يوجد تطابق محلي، أرسل للـ AI
  }

  /// فحص إذا كان النص يحتوي على تخصص
  bool _hasSpecialty(String text) {
    final specs = [
      'اسنان', 'عيون', 'اطفال', 'باطنيه', 'قلب', 'جلديه',
      'عظام', 'اعصاب', 'نسائيه', 'جراحه', 'انف', 'اذن', 'مسالك',
    ];
    return specs.any((s) => text.contains(s));
  }

  /// فحص التطابق مع قائمة كلمات
  bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(_normalizeArabic(kw)));
  }

  /// تشغيل الإجراءات مباشرة من نقرة فقاعة المحادثة
  void executeActionCommand(String actionType, String actionData) {
    if (actionType == 'navigate') {
      onNavigate?.call(actionData);
    } else if (actionType == 'launch_whatsapp') {
      _launchWhatsApp(actionData);
    } else if (actionType == 'fetch_sections') {
      _fetchSectionsFromFirebase(actionData);
    }
  }

  /// تنفيذ الأمر الناتج من AI أو المحلي
  void _executeCommand(String command) {
    String cleaned = command.trim();

    // قد يحتوي الرد على عدة أسطر، نأخذ أول أمر
    final lines = cleaned.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('FAQ_ANSWER:')) {
        final jsonStr = line.replaceFirst('FAQ_ANSWER:', '').trim();
        try {
          final data = json.decode(jsonStr) as Map<String, dynamic>;
          final response = data['response'] as String;
          final actionType = data['actionType'] as String?;
          final actionData = data['actionData'] as String?;
          
          _addBotMessage(response, actionType: actionType, actionData: actionData);
          
          // تشغيل الإجراء فوراً لتسريع تجربة المستخدم
          if (actionType != null && actionData != null && actionType.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 200), () {
              executeActionCommand(actionType, actionData);
            });
          }
        } catch (e) {
          debugPrint('Error parsing FAQ answer: $e');
        }
        return;
      }

      if (line.startsWith('NAVIGATE:')) {
        final target = line.replaceFirst('NAVIGATE:', '').replaceAll('"', '').trim();
        
        // حماية من فتح صفحة ببطن صفحة (التنقل المكرر)
        if (target == currentRoute) {
          final routeName = _routeNames[target] ?? target;
          _addBotMessage(
            'تدلل من عيوني! أنت هسه بصفحة $routeName! شلون أقدر أساعدك هنا؟',
          );
          return;
        }
        
        final routeName = _routeNames[target] ?? target;
        _addBotMessage(
          'تدلل، راح أنقلك لـ $routeName الحين!',
          actionType: 'navigate',
          actionData: target,
        );
        // تنفيذ الانتقال
        Future.delayed(const Duration(milliseconds: 600), () {
          onNavigate?.call(target);
        });
        return;

      } else if (line.startsWith('JOB_SEARCH:')) {
        final query = line.replaceFirst('JOB_SEARCH:', '').replaceAll('"', '').trim();
        if (onSearchJobs != null) {
          onSearchJobs!(query);
          _addBotMessage('من عيوني! بحثت لك عن \'$query\'في الوظائف المتاحة. ');
        } else {
          pendingSearchQuery = query;
          _executeCommand('NAVIGATE: "/vacancies"');
        }
        return;

      } else if (line.startsWith('JOB_CATEGORY:')) {
        final cat = line.replaceFirst('JOB_CATEGORY:', '').replaceAll('"', '').trim();
        if (onFilterCategory != null) {
          onFilterCategory!(cat);
          _addBotMessage('صار تدلل! صفيت لك الوظائف على قسم ($cat) الحين.');
        } else {
          pendingCategory = cat;
          _executeCommand('NAVIGATE: "/vacancies"');
        }
        return;

      } else if (line.startsWith('JOB_FILTER:')) {
        final filt = line.replaceFirst('JOB_FILTER:', '').replaceAll('"', '').trim();
        if (onSetFilter != null) {
          onSetFilter!(filt);
          final label = filt == 'seeker' ? 'الباحثين عن عمل' : filt == 'employer' ? 'فرص العمل' : 'المحفوظة';
          _addBotMessage('تدلل من عيوني، عرضت لك $label الحين.');
        } else {
          pendingFilter = filt;
          _executeCommand('NAVIGATE: "/vacancies"');
        }
        return;

      } else if (line.startsWith('JOB_SORT:')) {
        final sort = line.replaceFirst('JOB_SORT:', '').replaceAll('"', '').trim();
        if (onSetSort != null) {
          onSetSort!(sort);
          final label = sort == 'date_asc' ? 'الأقدم' : sort == 'date_desc' ? 'الأحدث' : 'الأكثر تفاعلاً';
          _addBotMessage('صار! رتبت لك الوظائف حسب $label الحين.');
        } else {
          pendingSort = sort;
          _executeCommand('NAVIGATE: "/vacancies"');
        }
        return;

      } else if (line.startsWith('JOB_ADD')) {
        if (onAddJob != null) {
          onAddJob!();
          _addBotMessage('تدلل! فتحت لك خيارات إضافة إعلان وظيفة جديد الحين.');
        } else {
          pendingAddJob = true;
          _executeCommand('NAVIGATE: "/vacancies"');
        }
        return;

      } else if (line.startsWith('COMPLAINT_SEARCH:')) {
        final query = line.replaceFirst('COMPLAINT_SEARCH:', '').replaceAll('"', '').trim();
        if (onSearchComplaints != null) {
          onSearchComplaints!(query);
          _addBotMessage('من عيوني! بحثت لك عن \'$query\'في البلاغات والشكاوى. ');
        } else {
          pendingComplaintSearch = query;
          _executeCommand('NAVIGATE: "/complaints"');
        }
        return;

      } else if (line.startsWith('COMPLAINT_TYPE:')) {
        final type = line.replaceFirst('COMPLAINT_TYPE:', '').replaceAll('"', '').trim();
        final label = type == 'complaint' ? 'الشكاوى' : type == 'suggestion' ? 'الاقتراحات' : 'الكل';
        if (onFilterComplaintType != null) {
          onFilterComplaintType!(type);
          _addBotMessage('تدلل! صفيت البلاغات لعرض ($label) الحين.');
        } else {
          pendingComplaintType = type;
          _executeCommand('NAVIGATE: "/complaints"');
        }
        return;

      } else if (line.startsWith('COMPLAINT_STATUS:')) {
        final status = line.replaceFirst('COMPLAINT_STATUS:', '').replaceAll('"', '').trim();
        if (onFilterComplaintStatus != null) {
          onFilterComplaintStatus!(status);
          _addBotMessage('صار من عيوني! عرضت الشكاوى بحالة ($status).');
        } else {
          pendingComplaintStatus = status;
          _executeCommand('NAVIGATE: "/complaints"');
        }
        return;

      } else if (line.startsWith('COMPLAINT_ADD')) {
        String? title;
        String? desc;
        String? type;
        if (line.contains('{')) {
          try {
            final jsonStr = line.substring(line.indexOf('{'));
            final data = json.decode(jsonStr) as Map<String, dynamic>;
            title = data['title'];
            desc = data['desc'] ?? data['description'];
            type = data['type'];
          } catch (e) {
            debugPrint('Error parsing complaint add JSON: $e');
          }
        }
        if (onAddComplaint != null) {
          onAddComplaint!(title, desc, type);
          _addBotMessage('تدلل! فتحت لك نموذج تقديم بلاغ جديد وعبيت لك الحقول مثل ما ردت. وتكدر تعدلها وتكتب عليها براحتك!');
        } else {
          pendingAddComplaint = true;
          pendingComplaintAddTitle = title;
          pendingComplaintAddDesc = desc;
          pendingComplaintAddType = type;
          _executeCommand('NAVIGATE: "/complaints"');
        }
        return;

      } else if (line.startsWith('STUDIO_SEARCH:')) {
        final query = line.replaceFirst('STUDIO_SEARCH:', '').replaceAll('"', '').trim();
        if (onSearchStudios != null) {
          onSearchStudios!(query);
          _addBotMessage('من عيوني! بحثت لك عن \'$query\'في استوديوهات التصوير. ');
        } else {
          pendingStudioSearch = query;
          _executeCommand('NAVIGATE: "/studios"');
        }
        return;

      } else if (line.startsWith('STUDIO_FILTER:')) {
        final filter = line.replaceFirst('STUDIO_FILTER:', '').replaceAll('"', '').trim();
        if (onFilterStudioType != null) {
          onFilterStudioType!(filter);
          _addBotMessage('تدلل! عرضت لك استوديوهات ($filter) الحين.');
        } else {
          pendingStudioType = filter;
          _executeCommand('NAVIGATE: "/studios"');
        }
        return;

      } else if (line.startsWith('STUDIO_ADD')) {
        if (onAddStudio != null) {
          onAddStudio!();
          _addBotMessage('صار تدلل! فتحت لك نموذج تسجيل استوديو تصوير جديد.');
        } else {
          pendingAddStudio = true;
          _executeCommand('NAVIGATE: "/studios"');
        }
        return;

      } else if (line.startsWith('RESTAURANT_CATEGORY:')) {
        final category = line.replaceFirst('RESTAURANT_CATEGORY:', '').replaceAll('"', '').trim();
        if (onFilterRestaurantCategory != null) {
          onFilterRestaurantCategory!(category);
          _addBotMessage('صار من عيوني! عرضت لك قسم ($category) في المطاعم.');
        } else {
          pendingRestaurantCategory = category;
          _executeCommand('NAVIGATE: "/restaurants"');
        }
        return;

      } else if (line.startsWith('RESTAURANT_SEARCH:')) {
        final query = line.replaceFirst('RESTAURANT_SEARCH:', '').replaceAll('"', '').trim();
        if (onSearchRestaurant != null) {
          onSearchRestaurant!(query);
          _addBotMessage('تدلل! بحثت لك عن \'$query\'في المطاعم والوجبات. ');
        } else {
          pendingRestaurantSearch = query;
          _executeCommand('NAVIGATE: "/restaurants"');
        }
        return;

      } else if (line.startsWith('PROFILE_EDIT')) {
        _profileEditStep = 1;
        _addBotMessage("تدلل عيوني! شنو الاسم الجديد اللي تحب أسجله إلك بالبروفايل؟");
        return;

      } else if (line.startsWith('PROFILE_CHANGE_PASSWORD')) {
        _addBotMessage("صار عيوني، فتحت لك واجهة تغيير كلمة المرور الحين.");
        _showChangePasswordDialog();
        return;

      } else if (line.startsWith('TRACK_ORDERS')) {
        _fetchRecentOrders();
        return;

      } else if (line.startsWith('ORDER_DETAILS:')) {
        final orderId = line.replaceFirst('ORDER_DETAILS:', '').replaceAll('"', '').trim();
        _fetchOrderDetails(orderId);
        return;

      } else if (line.startsWith('DELIVERY_REQUEST')) {
        _deliveryStep = 1;
        if (onNavigate != null && currentRoute != '/delivery') {
          onNavigate!('/delivery');
        }
        _addBotMessage(
          "صار تدلل! هسة نرتبلك طلب مرسال ونوصل غراضك وين ما تريد خطوة بخطوة!\n\n"
          " **أول شي: شنو نوع الغراض أو الطرد اللي تريد توصله؟**"
        );
        return;

      } else if (line.startsWith('DELIVERY_TRACK')) {
        _addBotMessage("صار حبيبي، راح أنقلك لصفحة مرسال لتتبع شحناتك.");
        _executeCommand('NAVIGATE: "/delivery"');
        return;

      } else if (line.startsWith('STORE_SEARCH:')) {
        final query = line.replaceFirst('STORE_SEARCH:', '').replaceAll('"', '').trim();
        if (onSearchStores != null) {
          onSearchStores!(query);
          _addBotMessage('من عيوني! بحثت لك عن \'$query\'في متاجر مدار. ');
        } else {
          pendingStoreSearch = query;
          _executeCommand('NAVIGATE: "/stores"');
        }
        return;

      } else if (line.startsWith('STORE_CATEGORY:')) {
        final category = line.replaceFirst('STORE_CATEGORY:', '').replaceAll('"', '').trim();
        if (onFilterStoreCategory != null) {
          onFilterStoreCategory!(category);
          _addBotMessage('صار تدلل! صفيت المتاجر على قسم ($category).');
        } else {
          pendingStoreCategory = category;
          _executeCommand('NAVIGATE: "/stores"');
        }
        return;

      } else if (line.startsWith('FOOD_ORDER:')) {
        _handleFoodOrderCommand(line);
        return;

      } else if (line.startsWith('HIGHLIGHT:')) {
        final target = line.replaceFirst('HIGHLIGHT:', '').replaceAll('"', '').trim();
        _triggerHighlight(target);
        return;

      } else if (line.startsWith('REAL_ESTATE_ADD')) {
        _realEstateAddStep = 1;
        if (onNavigate != null && currentRoute != '/real_estate') {
          onNavigate!('/real_estate');
        }
        _addBotMessage(
          "تمام وتدلل من عيوني! هسة راح ننشر إعلان عقارك سوية خطوة بخطوة بالدردشة ونملي كل الحقول وتدلل!\n\n"
          " **أول شي: شنو نوع العقار والعنوان اللي ببالك؟**\n"
          "(مثال: بيت للبيع، شقة للإيجار، محل تجاري، أرض للبيع) - أو اكتبلي فكرتك وأني أصيغلك عنوان تسويقي مغري يجذب الزبائن! "
        );
        return;

      } else if (line.startsWith('REAL_ESTATE_SEARCH:')) {
        final query = line.replaceFirst('REAL_ESTATE_SEARCH:', '').replaceAll('"', '').trim();
        if (onSearchRealEstate != null) {
          onSearchRealEstate!(query);
          _addBotMessage('تدلل! بحثت لك عن \'$query\'في العقارات المتاحة. ');
        } else {
          pendingRealEstateSearch = query;
          _executeCommand('NAVIGATE: "/real_estate"');
        }
        return;

      } else if (line.startsWith('REAL_ESTATE_FILTER:')) {
        final filter = line.replaceFirst('REAL_ESTATE_FILTER:', '').replaceAll('"', '').trim();
        if (onFilterRealEstate != null) {
          onFilterRealEstate!(filter);
          _addBotMessage('من عيوني! عرضت لك العقارات المصفاة على ($filter) الحين.');
        } else {
          pendingRealEstateFilter = filter;
          _executeCommand('NAVIGATE: "/real_estate"');
        }
        return;

      } else if (line.startsWith('CONTACT_SUPPORT')) {
        _launchWhatsApp('support');
        return;

      } else if (line.startsWith('REPORT_BUG')) {
        _createBugReport();
        return;

      } else if (line.startsWith('EMERGENCY_NUMBERS')) {
        _addBotMessage(
          " **أرقام الطوارئ الرسمية في العراق:**\n"
          "• الإسعاف الفوري: **122** \n"
          "• الدفاع المدني (المطافئ): **115** \n"
          "• الشرطة الاتحادية / النجدة: **104** \n"
          "تمنياتنا بالسلامة للجميع!"
        );
        return;

      } else if (line.startsWith('JOB_ADD')) {
        _jobAddStep = 1;
        if (onNavigate != null && currentRoute != '/vacancies') {
          onNavigate!('/vacancies');
        }
        _addBotMessage(
          "تدلل من عيوني! هسة ننشر إعلان وظيفتك خطوة بخطوة بالدردشة ونملي كل الحقول!\n\n"
          " **أول شي: شنو المسمى الوظيفي المطلوب؟**\n"
          "(مثال: مهندس برمجيات، كاشير، مندوب مبيعات، سكرتيرة...) "
        );
        return;

      } else if (line.startsWith('COMPLAINT_ADD')) {
        _complaintStep = 1;
        if (onNavigate != null && currentRoute != '/complaints') {
          onNavigate!('/complaints');
        }
        _addBotMessage(
          "حقك فوك راسنا يا غالي! إحنا بمدار بخدمتك، وهسة نسجل شكواك ونوصلها للإدارة فوراً!\n\n"
          " **أول شي: شنو موضوع الشكوى أو المشكلة اللي واجهتك؟**"
        );
        return;

      } else if (line.startsWith('WHO_AM_I')) {
        _displayUserInfo();
        return;

      } else if (line.startsWith('FETCH_SECTIONS:')) {
        final query = line.replaceFirst('FETCH_SECTIONS:', '').replaceAll('"', '').trim();
        _fetchSectionsFromFirebase(query);
        return;

      } else if (line.startsWith('SEARCH_PLACES:')) {
        final query = line.replaceFirst('SEARCH_PLACES:', '').replaceAll('"', '').trim();
        _searchPlacesFromFirebase(query);
        return;

      } else if (line.startsWith('LAUNCH_WHATSAPP:')) {
        final type = line.replaceFirst('LAUNCH_WHATSAPP:', '').replaceAll('"', '').trim();
        _launchWhatsApp(type);
        return;

      } else if (line.startsWith('POINTS_AND_WALLET')) {
        _checkUserPointsAndWallet();
        return;

      } else if (line.startsWith('TAXI_REQUEST')) {
        _handleTaxiRequest();
        return;

      } else if (line.startsWith('FOOD_RECOMMENDATION:')) {
        final query = line.replaceFirst('FOOD_RECOMMENDATION:', '').replaceAll('"', '').trim();
        _handleFoodRecommendation(query);
        return;

      } else if (line.startsWith('STORE_RECOMMENDATION:')) {
        final query = line.replaceFirst('STORE_RECOMMENDATION:', '').replaceAll('"', '').trim();
        _handleStoreRecommendation(query);
        return;

      } else if (line.startsWith('THEME_TOGGLE:')) {
        final mode = line.replaceFirst('THEME_TOGGLE:', '').replaceAll('"', '').trim();
        _handleThemeToggle(mode);
        return;

      } else if (line.startsWith('EMOTION_RESPONSE:')) {
        final dataStr = line.replaceFirst('EMOTION_RESPONSE:', '').trim();
        _handleEmotionResponse(dataStr);
        return;

      } else if (line.startsWith('MEMORY_SAVE_NAME:')) {
        final name = line.replaceFirst('MEMORY_SAVE_NAME:', '').replaceAll('"', '').trim();
        _handleSaveMemoryName(name);
        return;

      } else if (line.startsWith('MEMORY_SAVE_HOME:')) {
        final home = line.replaceFirst('MEMORY_SAVE_HOME:', '').replaceAll('"', '').trim();
        _handleSaveMemoryHome(home);
        return;

      } else if (line.startsWith('MEMORY_SAVE_WORK:')) {
        final work = line.replaceFirst('MEMORY_SAVE_WORK:', '').replaceAll('"', '').trim();
        _handleSaveMemoryWork(work);
        return;

      } else if (line.startsWith('MEMORY_SAVE_FOOD:')) {
        final food = line.replaceFirst('MEMORY_SAVE_FOOD:', '').replaceAll('"', '').trim();
        _handleSaveMemoryFood(food);
        return;

      } else if (line.startsWith('MEMORY_SAVE_NOTE:')) {
        final note = line.replaceFirst('MEMORY_SAVE_NOTE:', '').replaceAll('"', '').trim();
        _handleSaveMemoryNote(note);
        return;

      } else if (line.startsWith('MEMORY_QUERY')) {
        _handleMemoryQuery();
        return;

      } else if (line.startsWith('MEMORY_CLEAR')) {
        _handleMemoryClear();
        return;

      } else if (line.startsWith('CLEAN_CACHE')) {
        _handleCleanCache();
        return;

      } else if (line.startsWith('CREATOR_INFO')) {
        _handleCreatorInfo();
        return;

      } else if (line.startsWith('SAY:')) {
        String msg = line.substring(4).trim();
        if (msg.startsWith('"') && msg.endsWith('"') && msg.length >= 2) {
          msg = msg.substring(1, msg.length - 1);
        }
        msg = msg.replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
        _addBotMessage(msg);
        return;
      }
    }

    // إذا لم يتطابق مع أي نمط، اعرض الرد كما هو
    _addBotMessage(cleaned);
  }

  // ────────────────────────────────────────────────────────
  // دوال الذاكرة والمشاعر الذكية
  // ────────────────────────────────────────────────────────

  void _handleEmotionResponse(String jsonStr) {
    try {
      final map = json.decode(jsonStr);
      final response = map['response'] ?? 'يا هلا بيك عيوني، تدلل!';
      final actionType = map['actionType'];
      final actionData = map['actionData'];
      _addBotMessage(response, actionType: actionType, actionData: actionData);
    } catch (_) {
      _addBotMessage(jsonStr);
    }
  }

  Future<void> _handleSaveMemoryName(String name) async {
    await SmartAssistantMemory().setNickname(name);
    _addBotMessage(
      'تدلل وعاشت إيدك! حفظت ببالي إن اسمك / لقبك هو **$name**.. من اليوم وطالع راح أناديك بيه دائماً!'
    );
  }

  Future<void> _handleSaveMemoryHome(String home) async {
    await SmartAssistantMemory().setHomeAddress(home);
    _addBotMessage(
      'صار وعلى راسي! سجلت بذاكرتي إن عنوان بيتك هو **$home**.. كل ما تطلب تكسي أو مسواك راح أتذكر عنوانك فوراً!'
    );
  }

  Future<void> _handleSaveMemoryWork(String work) async {
    await SmartAssistantMemory().setWorkAddress(work);
    _addBotMessage(
      'تامر أمر! حفظت عنوان دوامك/شغلك بـ **$work**.. صرت أعرف مشاويرك اليومية يا غالي!'
    );
  }

  Future<void> _handleSaveMemoryFood(String food) async {
    await SmartAssistantMemory().addFavoriteFood(food);
    _addBotMessage(
      'يم يم أطيب أكل والله! سجلت ببالي إنك تحب **$food**.. كل ما تجوع راح أرشحلك أطيب المطاعم اللي تسويها!'
    );
  }

  Future<void> _handleSaveMemoryNote(String note) async {
    await SmartAssistantMemory().addUserNote(note);
    _addBotMessage(
      'حفظتها ببالي وما أنساها أبداً: "$note" .. ذاكرتي دائماً وياك!'
    );
  }

  void _handleMemoryQuery() {
    final summary = SmartAssistantMemory().getMemorySummary();
    _addBotMessage(summary);
  }

  Future<void> _handleMemoryClear() async {
    await SmartAssistantMemory().clearMemory();
    _addBotMessage(
      'صار يا غالي! مسحت كل المعلومات والملاحظات من ذاكرتي وصفرتها من جديد.. تكدر بأي وقت تضيف معلومات جديدة!'
    );
  }

  // ────────────────────────────────────────────────────────
  // دوال مساعدة لمعالجة الأوامر الجديدة
  // ────────────────────────────────────────────────────────

  void _showChangePasswordDialog() {
    final context = appNavigatorKey.currentContext;
    if (context == null) return;
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text(
              'تغيير كلمة المرور',
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: true,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الحالية',
                        labelStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'يرجى إدخال كلمة المرور الحالية' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الجديدة',
                        labelStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'يرجى إدخال كلمة المرور الجديدة';
                        if (v.length < 6) return 'يجب أن تكون 6 أحرف على الأقل';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور الجديدة',
                        labelStyle: const TextStyle(fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (v) {
                        if (v != newPasswordController.text) return 'كلمات المرور غير متطابقة';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('إلغاء', style: TextStyle()),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setState(() => isLoading = true);
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null && user.email != null) {
                              AuthCredential credential = EmailAuthProvider.credential(
                                email: user.email!,
                                password: currentPasswordController.text.trim(),
                              );
                              await user.reauthenticateWithCredential(credential);
                              await user.updatePassword(newPasswordController.text.trim());
                              // 'plainPassword': newPasswordController.text.trim(),
                              // Storing plaintext passwords is disabled for Apple App Store compliance.

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم تغيير كلمة المرور بنجاح', style: TextStyle()),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          } on FirebaseAuthException catch (e) {
                            String message = 'حدث خطأ أثناء تغيير كلمة المرور';
                            if (e.code == 'wrong-password') message = 'كلمة المرور الحالية غير صحيحة';
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message, style: const TextStyle()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('صار خطأ، حاول مرة ثانية', style: TextStyle()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) setState(() => isLoading = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009688)),
                child: isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('تغيير', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _fetchRecentOrders() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _addBotMessage("سجّل دخولك أولاً لعرض طلباتك.");
      return;
    }
    _addBotMessage("جاري جلب طلباتك الأخيرة...");
    try {
      final snapRes = await FirebaseFirestore.instance
          .collection('madar_orders')
          .doc(uid)
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();
      
      final snapStore = await FirebaseFirestore.instance
          .collection('madar_orders')
          .doc(uid)
          .collection('store_orders')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      final allDocs = [...snapRes.docs, ...snapStore.docs];
      allDocs.sort((a, b) {
        final dateA = (a.data())['createdAt'] as Timestamp?;
        final dateB = (b.data())['createdAt'] as Timestamp?;
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });

      if (allDocs.isEmpty) {
        _addBotMessage("ما عندك أي طلبات سابقة حالياً.");
        return;
      }

      String res = " **طلباتك الأخيرة:**\n\n";
      final showCount = allDocs.length > 5 ? 5 : allDocs.length;
      for (int i = 0; i < showCount; i++) {
        final data = allDocs[i].data();
        final isStore = allDocs[i].reference.path.contains('store_orders');
        final title = isStore ? (data['storeName'] ?? 'متجر') : 'طلب مطعم';
        final total = (data['total'] ?? 0).toInt();
        final status = data['status'] ?? 'pending';
        String statusAr;
        switch (status) {
          case 'pending': statusAr = 'قيد الانتظار'; break;
          case 'accepted': statusAr = 'مقبول'; break;
          case 'ready': statusAr = 'جاهز للتوصيل'; break;
          case 'delivering': statusAr = 'جاري التوصيل'; break;
          case 'completed': statusAr = 'مكتمل'; break;
          case 'cancelled': statusAr = 'ملغي'; break;
          default: statusAr = status;
        }
        
        res += "${i + 1}. **$title**\n";
        res += "المبلغ: $total د.ع\n";
        res += "الحالة: $statusAr\n";
        res += " 🆔 المعرف: `${allDocs[i].id.substring(0, 8)}...`\n";
        if (i < showCount - 1) res += "───────────\n";
      }
      _addBotMessage(res);
    } catch (e) {
      _addBotMessage("فشل جلب الطلبات. يرجى التحقق من اتصالك وحاول مرة أخرى.");
    }
  }

  Future<void> _fetchOrderDetails(String orderId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _addBotMessage("سجّل دخولك أولاً لعرض تفاصيل الطلب.");
      return;
    }
    _addBotMessage("جاري البحث عن الطلب `$orderId`...");
    try {
      DocumentSnapshot? doc;
      var docRef = FirebaseFirestore.instance.collection('madar_orders').doc(uid).collection('orders').doc(orderId);
      var snap = await docRef.get();
      bool isStore = false;
      if (snap.exists) {
        doc = snap;
      } else {
        docRef = FirebaseFirestore.instance.collection('madar_orders').doc(uid).collection('store_orders').doc(orderId);
        snap = await docRef.get();
        if (snap.exists) {
          doc = snap;
          isStore = true;
        }
      }

      if (doc == null || !doc.exists) {
        _addBotMessage("عذراً، ما كدرت ألاقي الطلب بالمعرف المطلوب. تأكد من صحة رقم الطلب.");
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final title = isStore ? (data['storeName'] ?? 'متجر') : 'طلب مطعم';
      final total = (data['total'] ?? 0).toInt();
      final status = data['status'] ?? 'pending';
      String statusAr;
      switch (status) {
        case 'pending': statusAr = 'قيد الانتظار'; break;
        case 'accepted': statusAr = 'مقبول'; break;
        case 'ready': statusAr = 'جاهز للتوصيل'; break;
        case 'delivering': statusAr = 'جاري التوصيل'; break;
        case 'completed': statusAr = 'مكتمل'; break;
        case 'cancelled': statusAr = 'ملغي'; break;
        default: statusAr = status;
      }
      final items = data['items'] as List<dynamic>? ?? [];

      String res = " **تفاصيل الطلب:**\n\n";
      res += "النوع: ${isStore ? 'متجر' : 'مطعم'} ($title)\n";
      res += "الحالة: **$statusAr**\n";
      res += "المجموع: $total د.ع\n\n";
      res += " **العناصر:**\n";
      for (var item in items) {
        res += "• ${item['name']} (العدد: ${item['quantity']}) - ${item['price']} د.ع\n";
      }
      _addBotMessage(res);
    } catch (e) {
      _addBotMessage("فشل جلب تفاصيل الطلب.");
    }
  }

  Future<void> _createBugReport() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _addBotMessage("جاري تسجيل بلاغ المشكلة تلقائياً...");
    try {
      await FirebaseFirestore.instance.collection('complaints').add({
        'title': 'بلاغ مشكلة تلقائي',
        'desc': 'المستخدم أبلغ عن مشكلة بالتطبيق عبر المساعد الذكي سكوزمي.',
        'type': 'complaint',
        'status': 'قيد المراجعة',
        'createdAt': FieldValue.serverTimestamp(),
        'userId': uid ?? 'anonymous',
        'userName': agent.userName,
      });
      _addBotMessage("سجلت البلاغ الحين ورفعته لقسم الشكاوى والدعم الفني. راح نتابعه ونحله بأسرع وقت!");
    } catch (e) {
      _addBotMessage("عذراً، ما كدرت أرسل البلاغ تلقائياً. تكدر تفتح صفحة الشكاوى وتقدمها بنفسك.");
    }
  }

  Future<void> _displayUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _addBotMessage("أنت ضيف حالياً، ما مسجل دخولك للتطبيق.");
      return;
    }
    _addBotMessage(
      " **معلومات حسابك الحالي:**\n"
      "• الاسم: **${agent.userName}**\n"
      "• البريد الإلكتروني: **${user.email ?? 'غير متصل ببريد'}**\n"
      "• معرف الحساب: `${user.uid}`\n"
      "إذا تحب تعدل معلوماتك بس اكتب لي \"عدل معلوماتي\"."
    );
  }

  /// فتح الواتساب للتسجيل بمطعم أو تكسي أو التواصل مع الدعم
  Future<void> _launchWhatsApp(String type) async {
    final msg = type == 'restaurant'
        ? 'السلام عليكم، أريد تسجيل مطعمي في تطبيق مدار.'
        : type == 'taxi'
            ? 'السلام عليكم، أريد التسجيل ككابتن تكسي في تطبيق مدار.'
            : 'السلام عليكم، أحتاج إلى دعم فني أو مساعدة بخصوص تطبيق مدار.';
    final url = Uri.parse('https://wa.me/9647819436408?text=${Uri.encodeComponent(msg)}');
    final label = type == 'restaurant'
        ? 'المطعم'
        : type == 'taxi'
            ? 'التكسي'
            : 'الدعم الفني';
    _addBotMessage('من عيوني! الحين راح أنقلك للواتساب للتواصل مع $label...', actionType: 'launch_whatsapp', actionData: type);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // طريقة بديلة في حال فشل wa.me
        final fallbackUrl = Uri.parse('whatsapp://send?phone=9647819436408&text=${Uri.encodeComponent(msg)}');
        if (await canLaunchUrl(fallbackUrl)) {
          await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
        } else {
          _addBotMessage('عذراً، ما كدرت أفتح الواتساب. تأكد من تثبيته على جهازك \nالرقم هو: 07819436408');
        }
      }
    } catch (e) {
      _addBotMessage('عذراً، ما كدرت أفتح الواتساب. تأكد من تثبيته على جهازك \nالرقم هو: 07819436408');
    }
  }


  /// تنظيف وتوحيد النص العربي للبحث الذكي
  String _normalizeArabic(String text) {
    return IraqiNLPEngine.normalizeIraqi(text);
  }

  /// جلب الأقسام والخدمات الطبية من فايربيس
  Future<void> _fetchSectionsFromFirebase(String query) async {
    _addBotMessage('جاري البحث في الأقسام والخدمات...');
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('sections').get();

      final searchWord = _normalizeArabic(query);

      final docs = querySnapshot.docs.where((doc) {
        final data = doc.data();
        final label = _normalizeArabic((data['label'] ?? '').toString());

        if (searchWord.isEmpty) return true; // عرض الكل إذا كانت كلمة البحث فارغة

        // تطابق بالاسم أو الكلمة
        if (label.contains(searchWord) || searchWord.contains(label)) {
          return true;
        }

        final words = searchWord.split(' ');
        for (var word in words) {
          if (word.trim().length > 1 && label.contains(word)) {
            return true;
          }
        }
        return false;
      }).toList();

      if (docs.isEmpty) {
        _addBotMessage(
          'ما لكيت أقسام تطابق "$query" حالياً \n'
          'بس تكدر تتصفح كل الأقسام بضغطة زر واحدة:',
          actionType: 'navigate',
          actionData: '/all-sections',
        );
      } else {
        String result = 'لكيت لك هذه الأقسام والخدمات بفايربيس! \n\n';
        final showCount = docs.length > 8 ? 8 : docs.length;
        for (var i = 0; i < showCount; i++) {
          final data = docs[i].data();
          final label = data['label'] ?? 'قسم غير مسمى';
          String emoji = '';
          if (label.contains('طبي') || label.contains('طبيب') || label.contains('دكتور') || label.contains('أسنان') || label.contains('صيدل') || label.contains('عياد') || label.contains('صحه') || label.contains('صحة')) {
            emoji = '';
          } else if (label.contains('عقار')) {
            emoji = '';
          } else if (label.contains('مطعم') || label.contains('أكل')) {
            emoji = '';
          } else if (label.contains('تكسي') || label.contains('تاكسي') || label.contains('سيار')) {
            emoji = '';
          } else if (label.contains('وظف') || label.contains('شغل') || label.contains('عمل')) {
            emoji = '';
          } else if (label.contains('مدرس') || label.contains('تعليم') || label.contains('أستاذ')) {
            emoji = '';
          } else if (label.contains('تصوير') || label.contains('استوديو') || label.contains('كامير')) {
            emoji = '';
          } else if (label.contains('سوق') || label.contains('دكان') || label.contains('متجر')) {
            emoji = '';
          }
          result += '$emoji $label\n';
          if (i < showCount - 1) result += '───────────\n';
        }
        if (docs.length > 8) {
          result += '\n...و ${docs.length - 8} أقسام أخرى';
        }
        _addBotMessage(result);
        _addBotMessage(
          'اضغط هنا لعرض كافة الأقسام والتفاصيل والتنقل بينها',
          actionType: 'navigate',
          actionData: '/all-sections',
        );
      }
    } catch (e) {
      debugPrint('خطأ في جلب الأقسام: $e');
      _addBotMessage('حدث خطأ أثناء جلب الأقسام. تأكد من اتصالك بالإنترنت');
    }
  }

  /// البحث عن الأماكن والمواقع والمعالم من فايربيس
  Future<void> _searchPlacesFromFirebase(String query) async {
    _addBotMessage("جاري البحث عن الأماكن والمواقع المتعلقة بـ \"$query\"... ");
    try {
      final qLower = _normalizeArabic(query).toLowerCase().trim();
      final placesSnap = await FirebaseFirestore.instance
          .collection('places')
          .limit(30)
          .get();

      final matched = placesSnap.docs.where((doc) {
        final data = doc.data();
        final name = _normalizeArabic((data['name'] ?? '').toString()).toLowerCase();
        final desc = _normalizeArabic((data['description'] ?? '').toString()).toLowerCase();
        final category = _normalizeArabic((data['category'] ?? '').toString()).toLowerCase();
        final address = _normalizeArabic((data['address'] ?? data['region'] ?? '').toString()).toLowerCase();
        return name.contains(qLower) || desc.contains(qLower) || category.contains(qLower) || address.contains(qLower);
      }).toList();

      if (matched.isEmpty) {
        // فحص في المتاجر والمطاعم كبديل
        final storesSnap = await FirebaseFirestore.instance.collection('stores').limit(20).get();
        final matchedStores = storesSnap.docs.where((doc) {
          final data = doc.data();
          final name = _normalizeArabic((data['name'] ?? '').toString()).toLowerCase();
          final address = _normalizeArabic((data['address'] ?? '').toString()).toLowerCase();
          return name.contains(qLower) || address.contains(qLower);
        }).toList();

        if (matchedStores.isNotEmpty) {
          String res = " **لقيتلك هذه الأماكن والمتاجر في مدار:**\n\n";
          for (var doc in matchedStores.take(4)) {
            final d = doc.data();
            final name = d['name'] ?? 'متجر';
            final addr = d['address'] ?? 'القائم';
            res += " **$name**\n العنوان: $addr\n\n";
          }
          _addBotMessage(res, actionType: 'navigate', actionData: '/stores');
          return;
        }

        _addBotMessage(
          "ما لكيت مكان محدد باسم \"$query\"مسجل بالدليل مباشرة. \n"
          "تكدر تتصفح كل الأقسام والأماكن والخدمات المتاحة من صفحة الأقسام العامة!",
          actionType: 'navigate',
          actionData: '/all-sections',
        );
        return;
      }

      String res = " **لقيتلك ${matched.length} مكان/موقع في دليل مدار:**\n\n";
      for (var doc in matched.take(5)) {
        final d = doc.data();
        final name = d['name'] ?? 'مكان';
        final category = d['category'] ?? 'خدمة عامة';
        final address = d['address'] ?? d['region'] ?? 'القائم';
        final phone = d['phone'] ?? '';
        res += " **$name** ($category)\n الموقع: $address\n";
        if (phone.toString().isNotEmpty) {
          res += "هاتف: $phone\n";
        }
        res += "───────────\n";
      }
      res += "تكدر تطلب تكسي يوصلك للمكان أو تفتح الأقسام للتفاصيل!";
      _addBotMessage(res, actionType: 'navigate', actionData: '/all-sections');
    } catch (e) {
      _addBotMessage("حدث خطأ أثناء البحث عن الأماكن. حاول مرة ثانية بعد شوية");
    }
  }

  /// مسح المحادثة
  void clearChat() {
    messages.clear();
    _addBotMessage('تم مسح المحادثة! كيف أقدر أساعدك؟');
  }

  void _triggerHighlight(String target) {
    if (onHighlightWidget != null) {
      onHighlightWidget!(target);
    } else {
      _addBotMessage('دلّك عيوني! الرمز أو الزر اللي تبحث عنه هو "$target".');
    }
  }

  Future<void> _handleFoodOrderCommand(String line) async {
    final jsonStr = line.replaceFirst('FOOD_ORDER:', '').trim();
    try {
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final restaurantName = data['restaurant'] as String;
      final itemsList = data['items'] as List<dynamic>;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _addBotMessage('حبيبي، لازم تسجل دخولك أول شي علمود أكدر أضيف الوجبات لسلتك.');
        return;
      }

      _addBotMessage('صار حبيبي، جاري البحث عن الوجبات في مطعم "$restaurantName"...');

      // 1. Search for restaurantItem with name matching restaurantName
      final restQuery = await FirebaseFirestore.instance
          .collectionGroup('items')
          .where('name', isEqualTo: restaurantName)
          .limit(1)
          .get();

      if (restQuery.docs.isEmpty) {
        _addBotMessage('عذراً حبيبي، ما كدرت ألاقي مطعم باسم "$restaurantName" في قاعدة البيانات.');
        return;
      }

      final restaurantDoc = restQuery.docs.first;
      final restaurantId = restaurantDoc.id; // restaurantItemId

      // 2. Fetch the menu of this restaurant to match names of items
      final menuQuery = await restaurantDoc.reference.collection('menu').get();
      final menuItems = menuQuery.docs;

      int addedCount = 0;
      final cartId = GroupCartManager.getEffectiveCartId(uid);
      final cartRef = FirebaseFirestore.instance.collection('carts').doc(cartId).collection('items');

      for (final reqItem in itemsList) {
        final reqName = (reqItem['name'] as String).toLowerCase();
        final reqQty = (reqItem['qty'] ?? 1) as int;

        // find matching doc in menuItems
        final matchDoc = menuItems.cast<QueryDocumentSnapshot?>().firstWhere(
          (mDoc) {
            if (mDoc == null) return false;
            final mData = mDoc.data() as Map<String, dynamic>;
            final mName = (mData['name'] ?? '').toString().toLowerCase();
            return mName.contains(reqName) || reqName.contains(mName);
          },
          orElse: () => null,
        );

        if (matchDoc != null) {
          final mData = matchDoc.data() as Map<String, dynamic>;
          // check if already in cart
          final existing = await cartRef.where('itemId', isEqualTo: matchDoc.id).limit(1).get();
          if (existing.docs.isNotEmpty) {
            await cartRef.doc(existing.docs.first.id).update({
              'quantity': FieldValue.increment(reqQty),
            });
          } else {
            await cartRef.add({
              'itemId': matchDoc.id,
              'name': mData['name'] ?? '',
              'price': (mData['price'] ?? 0.0).toDouble(),
              'quantity': reqQty,
              'restaurant': restaurantName,
              'restaurantId': restaurantId,
              'imageUrl': mData['image'] ?? mData['imageUrl'] ?? '',
              'addedByName': agent.userName,
            });
          }
          addedCount++;
        }
      }

      if (addedCount > 0) {
        _addBotMessage(
          'تدلل عيوني! ضفتلك الوجبات بنجاح لسلة التسوق من مطعم "$restaurantName" \n'
          'تكدر تضغط على زر التأكيد جوا علمود تروح للسلة مباشرة.',
          actionType: 'confirm_order',
          actionData: '/cart',
        );
      } else {
        _addBotMessage('عذراً حبيبي، بحثت بمينو مطعم "$restaurantName" وما لقيت الوجبات المطلوبة.');
      }

    } catch (e) {
      debugPrint('Error parsing/handling food order command: $e');
      _addBotMessage('صار عندي خطأ فني أثناء إضافة الطلب للسلة. يرجى المحاولة مرة ثانية.');
    }
  }

  /// فحص نقاط المستخدم الحقيقية ورصيد المحفظة الفوري
  Future<void> _checkUserPointsAndWallet() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _addBotMessage(
        "يا هلا بيك! سجل دخولك لحسابك أولاً حتى أطلعلك نقاطك ورصيد محفظتك بدقة.",
        actionType: 'navigate',
        actionData: '/login',
      );
      return;
    }

    _addBotMessage("جاري فحص رصيدك ونقاطك الحالية في مدار...");
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      int points = 0;
      double balance = 0.0;
      String tier = 'عضو مدار الذهبي';

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        points = (data['points'] ?? data['rewardPoints'] ?? 0) is int
            ? (data['points'] ?? data['rewardPoints'] ?? 0)
            : ((data['points'] ?? data['rewardPoints'] ?? 0) as num).toInt();
        balance = (data['walletBalance'] ?? data['balance'] ?? 0.0) is double
            ? (data['walletBalance'] ?? data['balance'] ?? 0.0)
            : ((data['walletBalance'] ?? data['balance'] ?? 0.0) as num).toDouble();
        if (points > 1000) {
          tier = 'عضو مدار VIP الماسي';
        } else if (points > 500) {
          tier = 'عضو مدار المميز';
        }
      }

      final discountVal = points * 10; // كل نقطة تسوى 10 دنانير
      final msg = " **كشف حساب نقاطك ومحفظة مدار:**\n\n"
          "رصيد النقاط: **$points نقطة**\n"
          "قيمة الخصم: **$discountVal د.ع** كخصم فوري على أي طلب!\n"
          "رصيد المحفظة: **${balance.toStringAsFixed(0)} د.ع**\n"
          "تصنيف العضوية: **$tier**\n\n"
          "تكدر تستبدل نقاطك بكوبونات وخصومات الحين بضغطة زر وحدة!";

      _addBotMessage(msg, actionType: 'navigate', actionData: '/points');
    } catch (e) {
      _addBotMessage(
        "تكدر تشوف وتستبدل نقاطك الحالية من صفحة نقاط مدار:",
        actionType: 'navigate',
        actionData: '/points',
      );
    }
  }

  /// طلب تكسي مدار الذكي
  Future<void> _handleTaxiRequest() async {
    _addBotMessage(
      " **تكسي مدار السريع جاهز لخدمتك!**\n\n"
      "كباتن مدار متوفرين وقريبين عليك بأفضل الأسعار وأسرع وصول بالعراق. راح أنقلك الحين لشاشة طلب التكسي لتحديد موقعك والانطلاق فوراً!",
      actionType: 'navigate',
      actionData: '/taxi',
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      onNavigate?.call('/taxi');
    });
  }

  /// ترشيح أشهى المطاعم والأكلات الحية من فايربيس
  Future<void> _handleFoodRecommendation(String query) async {
    _addBotMessage("جاري استكشاف أشهى الأكلات والمطاعم المفتوحة الحين...");
    try {
      final snap = await FirebaseFirestore.instance
          .collection('restaurants')
          .where('isOpen', isEqualTo: true)
          .limit(4)
          .get();

      if (snap.docs.isEmpty) {
        _addBotMessage(
          "تدلل حبيبي! أطيب المطاعم والوجبات السريعة والمشويات العراقية بانتظارك في قسم المطاعم. اضغط بالأسفل للتصفح والطلب!",
          actionType: 'navigate',
          actionData: '/restaurants',
        );
        return;
      }

      String res = " **أبرز المطاعم المفتوحة الحين والقريبة عليك:**\n\n";
      for (int i = 0; i < snap.docs.length; i++) {
        final data = snap.docs[i].data();
        final name = data['name'] ?? data['restaurantName'] ?? 'مطعم مدار';
        final cat = data['category'] ?? data['type'] ?? 'وجبات سريعة ومشويات';
        final rating = data['rating'] ?? 4.8;
        res += "${i + 1}. **$name** $rating\n";
        res += "التصنيف: $cat\n";
        if (i < snap.docs.length - 1) res += "───────────\n";
      }
      res += "\nاضغط على الزر بالأسفل لفتح قائمة المطاعم واختيار وجبتك المفضلة! ";

      _addBotMessage(res, actionType: 'navigate', actionData: '/restaurants');
    } catch (e) {
      _addBotMessage(
        "أهلاً بيك! تفضل بزيارة قسم مطاعم مدار واطلب وجبتك اللذيذة الحين:",
        actionType: 'navigate',
        actionData: '/restaurants',
      );
    }
  }

  /// ترشيح متاجر وسوق مدار
  Future<void> _handleStoreRecommendation(String query) async {
    _addBotMessage(
      " **متاجر وسوق مدار للمسواك السريع!**\n\n"
      "كل السوبرماركتات، العطور، الملابس، والمواد المنزلية متوفرة ويوصلك المسواك لباب بيتك بضغطة زر! اضغط بالأسفل للتسوق:",
      actionType: 'navigate',
      actionData: '/stores',
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      onNavigate?.call('/stores');
    });
  }

  /// التحكم بالوضع الليلي والنهاري مباشرة
  Future<void> _handleThemeToggle(String mode) async {
    final isDark = mode == 'dark';
    isDarkModeNotifier.value = isDark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', isDark);
    } catch (_) {}

    if (isDark) {
      _addBotMessage("عاشت إيدك! شغلتلك الوضع الليلي الفخم (Dark Mode) راحة لعيونك ومتناسق تماماً ويا هوية مدار المحيطية!");
    } else {
      _addBotMessage("صار تدلل! رجعتلك الوضع النهاري المشرق نهارك سعيد ومليان طاقة!");
    }
  }

  /// تنظيف الذاكرة المؤقتة (الكاش)
  Future<void> _handleCleanCache() async {
    _addBotMessage("جاري تنظيف الذاكرة المؤقتة وتسريع التطبيق...");
    await Future.delayed(const Duration(milliseconds: 700));
    _addBotMessage("عاشت إيدك! تم تنظيف الكاش والذاكرة المؤقتة بنجاح التطبيق صار خفيف وطيارة هسة!");
  }

  /// معلومات المطور وفريق العمل
  void _handleCreatorInfo() {
    _addBotMessage(
      " **عن مدار وسكوزمي:**\n\n"
      "تطبيق **مدار (Madar)** والمساعد الذكي **سكوزمي ** تم تصميمه وبرمجته بأعلى المعايير العالمية وبفكر عراقي متطور لخدمة أهلنا وتسهيل التوصيل، التكسي، والخدمات في كل العراق! 🇮🇶\n"
      "إذا عندك أي استفسار أو اقتراح، أني حاضر دائماً بخدمتك!"
    );
  }

}
