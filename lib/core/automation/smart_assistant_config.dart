import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SmartAssistantConfig {
  /// يتم الاتصال بالذكاء الاصطناعي عبر Cloud Function المؤمّنة (Server Proxy)
  static const bool useServerProxy = true;

  /// مفتاح الحماية السحابي - محفوظ على الخادم حصراً
  static const String geminiApiKey = '';

  /// تهيئة اتصال المساعد الذكي
  static Future<void> loadApiKey() async {
    // API Key is protected and stored strictly server-side in Cloud Functions
    debugPrint(' SmartAssistantConfig: Initialized with authoritative Server-Side AI Proxy.');
  }

  /// إرسال الطلب إلى خادم Cloud Functions الآمن لتوليد الرد بالذكاء الاصطناعي
  static Future<String?> askProxy(String prompt) async {
    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('askSmartAssistant');
      final result = await callable.call({'prompt': prompt});
      final data = result.data;
      if (data is Map && data['success'] == true && data['reply'] != null) {
        return data['reply'].toString();
      }
    } catch (e) {
      debugPrint('SmartAssistant Server Proxy notice: $e');
    }
    return null;
  }

  /// اسم المساعد الذكي
  static const String assistantName = "سكوزمي";

  /// الوصف الكامل للمساعد
  static const String assistantSubtitle = "مساعد مدار الذكي";

  /// لون المساعد الذكي - متناسق مع هوية مدار
  static const Color primaryColor = Color(0xFF26A69A);
  static const Color accentColor = Color(0xFF00796B);
  static const Color darkBg = Color(0xFF07191A);
  static const Color darkCard = Color(0xFF0F2323);
  static const Color darkSurface = Color(0xFF113033);
  static const Color glowColor = Color(0xFF4ECCA3);

  /// الأوامر السريعة المتاحة للمستخدم باللهجة العراقية
  static const List<Map<String, dynamic>> quickActions = [
    {
      'icon': Icons.local_taxi_rounded,
      'label': 'احجزلي تكسي',
      'prompt': 'اريد تكسي مدار يوصلني',
    },
    {
      'icon': Icons.restaurant_menu_rounded,
      'label': 'جوعان رشحلي أكل',
      'prompt': 'جوعان رشحلي أطيب مطاعم وأكلات مفتوحة الحين',
    },
    {
      'icon': Icons.stars_rounded,
      'label': 'شكد نقاطي ومحفظتي؟',
      'prompt': 'شكد نقاطي ورصيد محفظتي الحين؟',
    },
    {
      'icon': Icons.shopping_bag_rounded,
      'label': 'متاجر وسوق مدار',
      'prompt': 'اريد اتسوق من متاجر مدار',
    },
    {
      'icon': Icons.dark_mode_rounded,
      'label': 'الوضع الليلي',
      'prompt': 'شغل الوضع الليلي الدارك مود',
    },
    {
      'icon': Icons.inventory_2_rounded,
      'label': 'وين وصل طلبي؟',
      'prompt': 'وين وصل طلبي وشنو طلباتي السابقة؟',
    },
    {
      'icon': Icons.psychology_rounded,
      'label': 'شنو حافظ عني؟',
      'prompt': 'شنو تعرف عني وشنو حافظ بذاكرتك؟',
    },
    {
      'icon': Icons.favorite_rounded,
      'label': 'ضايج وفضفضة',
      'prompt': 'ضايج وروحي طالعة واحتاج افضفض',
    },
    {
      'icon': Icons.speed_rounded,
      'label': 'تنظيف وتسريع التطبيق',
      'prompt': 'نظف الكاش وسرع التطبيق',
    },
    {
      'icon': Icons.health_and_safety_rounded,
      'label': 'دكتور أو مدرس',
      'prompt': 'ابحث لي عن دكتور او مدرس خصوصي',
    },
    {
      'icon': Icons.work_rounded,
      'label': 'شكو وظائف جديدة؟',
      'prompt': 'شكو وظائف وفرص عمل جديدة متاحة؟',
    },
    {
      'icon': Icons.support_agent_rounded,
      'label': 'تواصل ويا الدعم',
      'prompt': 'اريد اتواصل ويا خدمة العملاء والدعم الفني',
    },
  ];
}
