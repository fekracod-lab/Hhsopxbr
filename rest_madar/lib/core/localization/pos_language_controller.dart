import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// متحكم لغة النظام الموحد لمنظومة مدار (عربي / إنجليزي)
class PosLanguageController extends ChangeNotifier {
  PosLanguageController._();
  static final PosLanguageController instance = PosLanguageController._();

  static const String _prefsKey = 'madar_pos_app_language';
  String _languageCode = 'en'; // افتراضياً باللغة الإنجليزية كما طلب المستخدم
  bool _loaded = false;

  bool get isEnglish => _languageCode == 'en';
  bool get isArabic => _languageCode == 'ar';
  String get languageCode => _languageCode;
  bool get isLoaded => _loaded;

  TextDirection get textDirection =>
      isEnglish ? TextDirection.ltr : TextDirection.rtl;

  /// دالة ترجمة سريعة تُرجع النص الإنجليزي إذا كان النظام بالإنجليزية والعربي خلاف ذلك
  String tr(String ar, String en) => isEnglish ? en : ar;

  /// تحميل اللغة المحفوظة من التخزين المحلي
  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && (saved == 'en' || saved == 'ar')) {
        _languageCode = saved;
      } else {
        _languageCode = 'en'; // الافتراضي هو الإنجليزية
      }
    } catch (_) {
      _languageCode = 'en';
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// تعيين اللغة وحفظها
  Future<void> setLanguage(String code) async {
    if (_languageCode == code) return;
    _languageCode = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (_) {}
  }

  /// التبديل السريع بين الإنجليزية والعربية
  Future<void> toggle() => setLanguage(isEnglish ? 'ar' : 'en');
}

/// قاموس العبارات الموحد للوصول المباشر في أي مكان بالتطبيق
class PosLocale {
  static PosLanguageController get _c => PosLanguageController.instance;

  // General Actions & Terms
  static String get save => _c.tr('حفظ', 'Save');
  static String get cancel => _c.tr('إلغاء', 'Cancel');
  static String get delete => _c.tr('حذف', 'Delete');
  static String get edit => _c.tr('تعديل', 'Edit');
  static String get close => _c.tr('إغلاق', 'Close');
  static String get back => _c.tr('رجوع', 'Back');
  static String get confirm => _c.tr('تأكيد', 'Confirm');
  static String get retry => _c.tr('إعادة المحاولة', 'Retry');
  static String get search => _c.tr('بحث...', 'Search...');
  static String get all => _c.tr('الكل', 'All');
  static String get loading => _c.tr('جاري التحميل...', 'Loading...');
  static String get noData => _c.tr('لا توجد بيانات', 'No data available');

  // POS & Cashier
  static String get posTerminal => _c.tr('نقطة البيع السريع', 'Quick POS Terminal');
  static String get posSubtitle => _c.tr('البيع المباشر • سفري / صالة / توصيل', 'Direct Sales • Dine-In / Takeaway / Delivery');
  static String get cart => _c.tr('سلة الكاشير', 'Cashier Cart');
  static String get cartEmpty => _c.tr('السلة فارغة', 'Cart is empty');
  static String get cartEmptyDesc => _c.tr('اضغط على أي وجبة لإضافتها إلى السلة', 'Tap any meal to add it to the cart');
  static String get checkout => _c.tr('إتمام الطلب والدفع', 'Checkout & Pay');
  static String get previewCart => _c.tr('معاينة السلة', 'View Cart');
  static String get viewCartPay => _c.tr('عرض السلة / الدفع', 'View Cart / Checkout');
  static String get openDrawer => _c.tr('فتح الدرج', 'Open Drawer');
  static String get addMeal => _c.tr('إضافة وجبة', 'Add Meal');
  static String get subtotal => _c.tr('المجموع الفرعي', 'Subtotal');
  static String get discount => _c.tr('الخصم', 'Discount');
  static String get taxService => _c.tr('الخدمة / الضريبة', 'Service / Tax');
  static String get grandTotal => _c.tr('الإجمالي المطلوب', 'Grand Total');
  static String get holdOrder => _c.tr('تعليق الطلب', 'Hold Order');
  static String get clearCart => _c.tr('إلغاء السلة', 'Clear Cart');
  static String get itemsCount => _c.tr('أصناف', 'items');
  static String get searchMealsHint => _c.tr('ابحث عن وجبة أو مشروب أو باركود...', 'Search meal, drink, or barcode...');

  // Order Types
  static String get dineIn => _c.tr('صالة', 'Dine-In');
  static String get takeaway => _c.tr('سفري', 'Takeaway');
  static String get delivery => _c.tr('توصيل', 'Delivery');

  // Payment
  static String get paymentCash => _c.tr('نقدي (كاش)', 'Cash');
  static String get paymentCard => _c.tr('بطاقة دفع / زين كاش', 'Card / E-Payment');
  static String get paidAmount => _c.tr('المبلغ المستلم', 'Amount Received');
  static String get changeAmount => _c.tr('المبلغ المتبقي للزبون', 'Change to Return');
  static String get exactAmount => _c.tr('المبلغ بالضبط', 'Exact Amount');
  static String get printCustomerReceipt => _c.tr('طباعة فاتورة الزبون', 'Print Customer Receipt');
  static String get printKitchenTicket => _c.tr('طباعة بون المطبخ KDS', 'Print Kitchen Ticket');
  static String get confirmAndPrint => _c.tr('تأكيد الدفع وطباعة الفاتورة', 'Confirm Payment & Print');

  // Tables
  static String get tablesTitle => _c.tr('إدارة الصالة والمنيو الذكي للطاولات', 'Tables & Smart QR Menu Management');
  static String get tablesSubtitle => _c.tr('توليد روابط ورموز QR لكل طاولة لتمكين الزبائن من الطلب المباشر بالهاتف', 'Generate QR codes and web links for guests to order from their phones');
  static String get tableWord => _c.tr('طاولة', 'Table');
  static String get tablesCount => _c.tr('عدد الطاولات', 'Number of Tables');
  static String get available => _c.tr('متاحة', 'Available');
  static String get occupied => _c.tr('مشغولة', 'Occupied');
  static String get reserved => _c.tr('محجوزة', 'Reserved');
  static String get viewQrCode => _c.tr('عرض رمز QR', 'View QR Code');
  static String get openDigitalMenu => _c.tr('فتح المنيو الرقمي', 'Open Digital Menu');

  // Kitchen KDS
  static String get kdsTitle => _c.tr('طلبات مدار الحية (KDS)', 'Live Kitchen Orders (KDS)');
  static String get kdsSubtitle => _c.tr('استقبال طلبات التطبيق والمطبخ مع تنبيه صوتي وطباعة تلقائية', 'Live order dispatch with sound alerts and automatic printing');
  static String get pending => _c.tr('جديد', 'Pending');
  static String get preparing => _c.tr('قيد التحضير', 'Preparing');
  static String get ready => _c.tr('جاهز للتسليم', 'Ready');
  static String get completed => _c.tr('مكتمل', 'Completed');
  static String get cancelled => _c.tr('ملغي', 'Cancelled');
  static String get startPreparing => _c.tr('بدء التحضير', 'Start Preparing');
  static String get markReady => _c.tr('تم التجهيز', 'Mark Ready');
  static String get markCompleted => _c.tr('تسليم الطلب', 'Complete Order');
  static String get muteAlarm => _c.tr('كتم الصوت', 'Mute Alert');
  static String get printerSettings => _c.tr('إعدادات الطابعة', 'Printer Settings');

  // Static English & Arabic variants for explicit usage
  static const String saveEn = 'Save';
  static const String saveAr = 'حفظ';
  static const String cancelEn = 'Cancel';
  static const String cancelAr = 'إلغاء';
  static const String closeEn = 'Close';
  static const String closeAr = 'إغلاق';
  static const String confirmEn = 'Confirm';
  static const String confirmAr = 'تأكيد';
  static const String allEn = 'All';
  static const String allAr = 'الكل';
  static const String addMealEn = 'Add Meal';
  static const String addMealAr = 'إضافة وجبة';
  static const String searchMealsHintEn = 'Search meal, drink, or barcode...';
  static const String searchMealsHintAr = 'ابحث عن وجبة أو مشروب أو باركود...';
  static const String cartTitleEn = 'Cashier Cart';
  static const String cartTitleAr = 'سلة الكاشير';
  static const String holdOrderEn = 'Hold Order';
  static const String holdOrderAr = 'تعليق الطلب';
  static const String takeawayEn = 'Takeaway';
  static const String takeawayAr = 'سفري';
  static const String dineInEn = 'Dine-In';
  static const String dineInAr = 'صالة';
  static const String deliveryEn = 'Delivery';
  static const String deliveryAr = 'توصيل';
  static const String cartEmptyEn = 'Cart is empty';
  static const String cartEmptyAr = 'السلة فارغة';
  static const String cartEmptySubtitleEn = 'Tap any meal to add it to the cart';
  static const String cartEmptySubtitleAr = 'اضغط على أي وجبة لإضافتها إلى السلة';
  static const String discountEn = 'Discount';
  static const String discountAr = 'الخصم';
  static const String subtotalEn = 'Subtotal';
  static const String subtotalAr = 'المجموع الفرعي';
  static const String taxServiceEn = 'Service / Tax';
  static const String taxServiceAr = 'الخدمة / الضريبة';
  static const String totalEn = 'Total';
  static const String totalAr = 'الإجمالي';
  static const String checkoutEn = 'Checkout & Pay';
  static const String checkoutAr = 'إتمام الطلب والدفع';
  static const String occupiedEn = 'Occupied';
  static const String occupiedAr = 'مشغولة';
  static const String vacantEn = 'Available';
  static const String vacantAr = 'شاغرة';
  static const String reservedEn = 'Reserved';
  static const String reservedAr = 'محجوزة';
  static const String cashEn = 'Cash';
  static const String cashAr = 'نقداً (كاش)';
  static const String cardEn = 'Card / E-Payment';
  static const String cardAr = 'بطاقة / كي كارد';
  static const String muteAlarmEn = 'Mute Alert';
  static const String muteAlarmAr = 'كتم الصوت';
  static const String printerSettingsEn = 'Printer Settings';
  static const String printerSettingsAr = 'إعدادات الطابعة';
  static const String pendingEn = 'Pending';
  static const String pendingAr = 'جديد';
  static const String preparingEn = 'Preparing';
  static const String preparingAr = 'قيد التحضير';
  static const String readyEn = 'Ready';
  static const String readyAr = 'جاهز للتسليم';
  static const String completedEn = 'Completed';
  static const String completedAr = 'مكتمل';
  static const String cancelledEn = 'Cancelled';
  static const String cancelledAr = 'ملغي';
  static const String posTerminalEn = 'Quick POS Terminal';
  static const String posTerminalAr = 'نقطة البيع السريع';
  static const String posSubtitleEn = 'Direct Sales • Dine-In / Takeaway / Delivery';
  static const String posSubtitleAr = 'البيع المباشر • سفري / صالة / توصيل';
  static const String openDrawerEn = 'Open Drawer';
  static const String openDrawerAr = 'فتح الدرج';
}

/// امتداد للوصول السريع إلى اللغة الحالية والاتجاه والترجمة من الـ context
extension PosLanguageContext on BuildContext {
  bool get isEnglish => PosLanguageController.instance.isEnglish;
  bool get isArabic => PosLanguageController.instance.isArabic;
  TextDirection get appDirection => PosLanguageController.instance.textDirection;
  String tr(String ar, String en) => PosLanguageController.instance.tr(ar, en);
}
