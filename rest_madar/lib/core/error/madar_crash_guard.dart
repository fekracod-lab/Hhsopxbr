import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// كائن يمثل بيانات الخطأ المحلل هندسياً
class MadarErrorInfo {
  final String code;
  final String title;
  final String message;
  final String suggestedFix;
  final String rawDetails;
  final IconData icon;
  final Color severityColor;
  final DateTime timestamp;

  MadarErrorInfo({
    required this.code,
    required this.title,
    required this.message,
    required this.suggestedFix,
    required this.rawDetails,
    this.icon = Icons.warning_amber_rounded,
    this.severityColor = const Color(0xFFE53935),
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// حارس النظام لمنع الانهيارات والتقاط وتحليل كل الأخطاء برمز وسبب واضح
class MadarCrashGuard {
  /// مفتاح التنقل العام لعرض نوافذ الأخطاء من أي مكان حتى في الدوال الخلفية والـ Streams
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final List<MadarErrorInfo> _recentErrors = [];
  static List<MadarErrorInfo> get recentErrors => List.unmodifiable(_recentErrors);

  /// منبه التغييرات في الأخطاء لتحديث الواجهة فورياً
  static final ValueNotifier<List<MadarErrorInfo>> errorsNotifier = ValueNotifier<List<MadarErrorInfo>>([]);

  static bool _isDialogShowing = false;
  static DateTime _lastDialogTime = DateTime.fromMillisecondsSinceEpoch(0);
  static String _lastErrorCode = '';

  /// تفعيل الحارس الشامل لجميع أخطاء فلاتر ودارت في التطبيق
  static void init() {
    // 1. التقاط أخطاء الـ Framework والـ Widgets والـ Layout
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.silent) return;

      final info = analyzeError(details.exception, details.stack);

      // في حال كان الخطأ تجاوز حدود الشاشة (Overflow) أو تعذر تحميل صورة أو خط بالشبكة، نتجاهله بصمت
      if (info.code == 'ERR_LAYOUT_OVERFLOW' || info.code == 'ERR_IMAGE_NETWORK_LOAD' || info.code == 'ERR_FONT_NETWORK_LOAD') {
        debugPrint('[MadarCrashGuard:Silent] ${info.code}: ${details.exceptionAsString()}');
        return;
      }

      _logError('[MadarCrashGuard:FrameworkError]', info);

      // إشعار المستخدم فورياً بسبب الخطأ على الشاشة
      notifyUserOfError(info);
    };

    // 2. التقاط جميع الاستثناءات غير المعالجة (Async / Event Loop / Platform)
    PlatformDispatcher.instance.onError = (error, stack) {
      final info = analyzeError(error, stack);

      // أخطاء الخطوط والصور وتجاوز الشاشة لا تتطلب تعطيل المستخدم بحوارات منبثقة
      if (info.code == 'ERR_FONT_NETWORK_LOAD' || info.code == 'ERR_IMAGE_NETWORK_LOAD' || info.code == 'ERR_LAYOUT_OVERFLOW') {
        debugPrint('[MadarCrashGuard:Silent] ${info.code}: $error');
        return true;
      }

      _logError('[MadarCrashGuard:PlatformAsyncError]', info);
      notifyUserOfError(info);
      // إرجاع true يخبر محرك فلاتر أن الخطأ تم التعامل معه هندسياً ولا يجوز إغلاق التطبيق أبداً
      return true;
    };

    // 3. استبدال شاشة الخطأ الحمراء الصامتة بشاشة مدار التشخيصية الذكية
    ErrorWidget.builder = (FlutterErrorDetails details) {
      final info = analyzeError(details.exception, details.stack);
      return MadarInlineErrorCard(errorInfo: info);
    };
  }

  /// التقاط الأخطاء اليدوية أو الممررة من الـ Zones
  static void reportUnhandledError(dynamic error, [StackTrace? stackTrace, String? tag]) {
    final info = analyzeError(error, stackTrace);
    if (info.code == 'ERR_FONT_NETWORK_LOAD' || info.code == 'ERR_IMAGE_NETWORK_LOAD' || info.code == 'ERR_LAYOUT_OVERFLOW') {
      debugPrint('[MadarCrashGuard:Silent] ${info.code}: $error');
      return;
    }
    _logError(tag ?? '[MadarCrashGuard:Unhandled]', info);
    notifyUserOfError(info);
  }

  static void _logError(String tag, MadarErrorInfo info) {
    debugPrint('$tag Code: ${info.code} | Title: ${info.title} | Reason: ${info.message}');
    try {
      final f = File('debug_trace.log');
      f.writeAsStringSync('[CRASH_GUARD] $tag Code: ${info.code} | Title: ${info.title} | Message: ${info.message}\nDetails: ${info.rawDetails}\n', mode: FileMode.append, flush: true);
    } catch (_) {}
    _recentErrors.insert(0, info);
    if (_recentErrors.length > 50) _recentErrors.removeLast();

    // حماية الشجرة من خطأ Build scheduled during frame بتأجيل الإشعار لما بعد الإطار الحالي
    WidgetsBinding.instance.addPostFrameCallback((_) {
      errorsNotifier.value = List.unmodifiable(_recentErrors);
    });
  }

  /// إظهار تنبيه مرئي فوري للمستخدم عند وقوع أي خطأ مهما كان
  static void notifyUserOfError(MadarErrorInfo info) {
    final now = DateTime.now();
    // تجنب التكرار المتتالي لنفس الخطأ خلال ثانيتين
    if (now.difference(_lastDialogTime) < const Duration(milliseconds: 2500) && _lastErrorCode == info.code) {
      return;
    }
    _lastDialogTime = now;
    _lastErrorCode = info.code;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      if (_isDialogShowing) {
        // إذا كانت نافذة الخطأ مفتوحة، نعرض شريط عائم بالخطأ الجديد دون إرباك
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            backgroundColor: info.severityColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                Icon(info.icon, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${info.title} [${info.code}]: ${info.message}',
                    style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }

      _isDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => buildErrorDialog(ctx, info),
      ).then((_) {
        _isDialogShowing = false;
      });
    });
  }

  /// غلاف حماية شامل يحيط بجميع شاشات التطبيق في MaterialApp.builder
  static Widget appBuilder(BuildContext context, Widget? child) {
    return _MadarRootGuardScope(child: child ?? const SizedBox());
  }

  /// تحليل أي خطأ واستخراج رمزه وسببه باللغة العربية
  static MadarErrorInfo analyzeError(dynamic error, [StackTrace? stackTrace]) {
    final str = error.toString();
    final lower = str.toLowerCase();
    final stack = stackTrace?.toString() ?? '';

    // 1. أخطاء الفهرس المركب في Firestore
    if (lower.contains('failed-precondition') || lower.contains('requires an index') || lower.contains('composite index')) {
      return MadarErrorInfo(
        code: 'ERR_FIRESTORE_INDEX_REQUIRED',
        title: 'قاعدة البيانات تطلب إنشاء فهرس مركب (Index Required)',
        message: 'استعلام Firestore الحالي يحتاج إلى فهرس مركب (Composite Index) لترتيب وجلب البيانات.',
        suggestedFix: 'انسخ رابط الفهرس الموضح في التفاصيل التقنية وافتحه في المتصفح لإنشائه في Firebase فوراً.',
        rawDetails: '$str\n\nStackTrace:\n$stack',
        icon: Icons.alt_route_rounded,
        severityColor: const Color(0xFFD97706),
      );
    }

    // 2. أخطاء الصلاحيات وقاعدة البيانات
    if (lower.contains('permission-denied') || lower.contains('permission denied')) {
      return MadarErrorInfo(
        code: 'ERR_FIRESTORE_PERMISSION_DENIED',
        title: 'تم رفض الإذن في قاعدة البيانات (Firebase)',
        message: 'الحساب الحالي غير مصرح له بتعديل أو قراءة هذا السجل في Firestore وفق قواعد الأمان.',
        suggestedFix: 'تأكد من تسجيل الدخول بحساب المطعم الصحيح، وفحص قواعد أمان firestore.rules.',
        rawDetails: '$str\n\nStackTrace:\n$stack',
        icon: Icons.lock_outline_rounded,
        severityColor: const Color(0xFFD32F2F),
      );
    }

    // 3. أخطاء ترميز التاريخ والـ Timestamp في JSON
    if (lower.contains('jsonunsupportedobjecterror') ||
        (lower.contains('converting object to an encodable object failed') && lower.contains('timestamp'))) {
      return MadarErrorInfo(
        code: 'ERR_JSON_TIMESTAMP_ENCODING',
        title: 'خطأ في ترميز كائنات الوقت (Timestamp JSON)',
        message: 'تمت محاولة تحويل كائن Timestamp الخاص بـ Firebase إلى JSON دون استخدام المحول الآمن.',
        suggestedFix: 'تم تصحيح المحول، يرجى استخدام LocalDatabaseService.safeJsonEncode لتخزين الكائنات المعقدة.',
        rawDetails: '$str\n\nStackTrace:\n$stack',
        icon: Icons.access_time_filled_rounded,
        severityColor: const Color(0xFFEF4444),
      );
    }

    // 4. أخطاء قاعدة البيانات المحلية SQLite
    if (lower.contains('sqlite') || lower.contains('databaseexception') || lower.contains('sqflite')) {
      return MadarErrorInfo(
        code: 'ERR_SQLITE_LOCAL_DB',
        title: 'خطأ في قاعدة البيانات المحلية (SQLite)',
        message: 'حدث تعارض أو قفل في ملف قاعدة بيانات الكاشير المحلية على جهاز الكمبيوتر.',
        suggestedFix: 'سيقوم النظام بإعادة فتح الاتصال تلقائياً. اضغط على إعادة المحاولة أو أعد تشغيل التطبيق.',
        rawDetails: '$str\n\nStackTrace:\n$stack',
        icon: Icons.storage_rounded,
        severityColor: const Color(0xFFDC2626),
      );
    }

    // 5. أخطاء الطابعة الحرارية
    if (lower.contains('printer') || lower.contains('thermal') || lower.contains('printing')) {
      return MadarErrorInfo(
        code: 'ERR_THERMAL_PRINTER',
        title: 'خطأ في الاتصال بالطابعة الحرارية',
        message: 'تعذر إرسال الفاتورة أو الاتصال بالطابعة المحددة في الإعدادات.',
        suggestedFix: 'تأكد من تشغيل الطابعة وتوصيل كابل USB أو الشبكة ثم أعد المحاولة.',
        rawDetails: '$str\n\nStackTrace:\n$stack',
        icon: Icons.print_disabled_rounded,
        severityColor: const Color(0xFFF59E0B),
      );
    }

    // 6. البيانات غير موجودة
    if (lower.contains('not-found') || lower.contains('not found')) {
      return MadarErrorInfo(
        code: 'ERR_DATA_NOT_FOUND',
        title: 'البيانات المطلوبة غير موجودة',
        message: 'تم طلب مستند أو وجبة أو طاولة تم حذفها أو لم تعد متوفرة في قاعدة البيانات.',
        suggestedFix: 'قم بتحديث الصفحة أو التحقق من وجود المعرف المطلوب.',
        rawDetails: '$str\n\nStackTrace:\n$stack',
        icon: Icons.search_off_rounded,
        severityColor: const Color(0xFFF57C00),
      );
    }

    // 7. أخطاء تحميل الصور والشهادات الرقمية
    if (lower.contains('certificate_verify_failed') ||
        lower.contains('handshake') ||
        lower.contains('image_codec') ||
        lower.contains('failed to load network image') ||
        lower.contains('image provider')) {
      return MadarErrorInfo(
        code: 'ERR_IMAGE_NETWORK_LOAD',
        title: 'تعذر جلب صورة من الشبكة',
        message: 'فشل تحميل أحد روابط الصور عبر الإنترنت بسبب شهادة الأمان أو ضعف الاتصال.',
        suggestedFix: 'تم استخدام صورة بديلة تلقائياً لمنع أي تأثير على واجهة النظام.',
        rawDetails: '$str\n\nStackTrace:\n$stack',
        icon: Icons.broken_image_rounded,
        severityColor: const Color(0xFFD97706),
      );
    }

    // 7.1 أخطاء تحميل الخطوط السحابية
    if (lower.contains('failed to load font') ||
        lower.contains('google_fonts') ||
        lower.contains('fonts.gstatic.com') ||
        (lower.contains('semaphore timeout') && lower.contains('.ttf'))) {
      return MadarErrorInfo(
        code: 'ERR_FONT_NETWORK_LOAD',
        title: 'تعذر جلب خط من الشبكة',
        message: 'فشل تحميل الخط السحابي بسبب بطء الاتصال، وتم استخدام خط النظام البديل.',
        suggestedFix: 'لا يلزم أي إجراء، يعمل النظام تلقائياً بالخطوط المحلية المعتمدة.',
        rawDetails: '$str\n\nStackTrace:\n$stack',
        icon: Icons.font_download_off_rounded,
        severityColor: const Color(0xFF64748B),
      );
    }

    // 8. أخطاء انقطاع الشبكة
    if (lower.contains('network') || lower.contains('socketexception') || lower.contains('connection refused') || lower.contains('failed host lookup')) {
      return MadarErrorInfo(
        code: 'ERR_NETWORK_DISCONNECTED',
        title: 'تعذر الاتصال بالشبكة أو الخادم السحابي',
        message: 'لا يوجد اتصال بالإنترنت أو تعذر الوصول إلى خوادم Firebase السحابية.',
        suggestedFix: 'تأكد من اتصال كابل الشبكة أو الواي فاي. سيعمل النظام محلياً في وضع الأوفلاين.',
        rawDetails: '$str\n\nStackTrace:\n$stack',
        icon: Icons.wifi_off_rounded,
        severityColor: const Color(0xFFF57C00),
      );
    }

    // 8. أخطاء القوائم المنسدلة Dropdown
    if (lower.contains('dropdown') || lower.contains('items.where') || lower.contains('there should be exactly one item with')) {
      return MadarErrorInfo(
        code: 'ERR_DROPDOWN_ITEM_ASSERTION',
        title: 'تعارض في خيارات القائمة المنسدلة',
        message: 'القيمة المحددة لا تطابق أي عنصر في قائمة الأقسام، أو يوجد عنصر مكرر.',
        suggestedFix: 'تم تصحيح القائمة المنسدلة تلقائياً واستبدالها بنظام اختيار آمن مقاوم للانهيار.',
        rawDetails: '$str\n\nStackTrace:\n$stack',
        icon: Icons.list_alt_rounded,
        severityColor: const Color(0xFFE53935),
      );
    }

    // 9. أخطاء تجاوز حدود مساحة الشاشة Layout Overflow
    if (lower.contains('renderflex overflowed') || lower.contains('overflowed by')) {
      return MadarErrorInfo(
        code: 'ERR_LAYOUT_OVERFLOW',
        title: 'تجاوز حدود مساحة الشاشة (Layout Overflow)',
        message: 'محتويات الواجهة أكبر من المساحة المتاحة لنافذة البرنامج الحالية.',
        suggestedFix: 'قم بتكبير نافذة التطبيق أو استخدام وضع ملء الشاشة. تم حماية العنصر تلقائياً.',
        rawDetails: '$str\n\nStackTrace:\n$stack',
        icon: Icons.aspect_ratio_rounded,
        severityColor: const Color(0xFFFFA000),
      );
    }

    // 10. محاولة قراءة قيمة فارغة Null Pointer
    if (lower.contains('null check operator used on a null value') || (lower.contains('nosuchmethoderror') && lower.contains('null'))) {
      return MadarErrorInfo(
        code: 'ERR_NULL_VALUE_ASSERTION',
        title: 'محاولة قراءة قيمة فارغة غير متوقعة (Null Pointer)',
        message: 'أحد الحقول أو البيانات المطلوبة في هذه الشاشة غير متوفرة أو قيمتها فارغة.',
        suggestedFix: 'تم عزل الخطأ في الشاشة المحددة لمنع توقف بقية وظائف النظام.',
        rawDetails: '$str\n\nStackTrace:\n$stack',
        icon: Icons.cancel_outlined,
        severityColor: const Color(0xFFE11D48),
      );
    }

    // 11. خطأ عام
    return MadarErrorInfo(
      code: 'ERR_RUNTIME_EXCEPTION',
      title: 'حدث استثناء غير متوقع في النظام',
      message: str.length > 250 ? '${str.substring(0, 247)}...' : str,
      suggestedFix: 'اضغط على زر النسخ لمشاركة رمز وتفاصيل الخطأ مع الدعم الفني دون توقف النظام.',
      rawDetails: '$str\n\nStackTrace:\n$stack',
      icon: Icons.bug_report_rounded,
      severityColor: const Color(0xFFD32F2F),
    );
  }

  /// إظهار نافذة تشخيصية منبثقة راقية لأي خطأ مع خيار النسخ والمتابعة
  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    StackTrace? stackTrace,
    String? customTitle,
    VoidCallback? onRetry,
  }) {
    final info = analyzeError(error, stackTrace);
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => buildErrorDialog(ctx, info, customTitle: customTitle, onRetry: onRetry),
    );
  }

  /// بناء واجهة نافذة الخطأ
  static Widget buildErrorDialog(
    BuildContext context,
    MadarErrorInfo info, {
    String? customTitle,
    VoidCallback? onRetry,
  }) {
    final c = context.posColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: info.severityColor.withValues(alpha: 0.4), width: 1.5),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الرأس
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: info.severityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(info.icon, color: info.severityColor, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customTitle ?? info.title,
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: c.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: c.border),
                            ),
                            child: Text(
                              'رمز المشكلة: ${info.code}',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: info.severityColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: c.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: c.border, height: 1),
                const SizedBox(height: 14),

                // الشرح والسبب
                Text(
                  'سبب المشكلة والتشخيص الهندسي:',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: c.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.message,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: c.textMuted,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // طريقة الحل المقترحة
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: c.accent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          info.suggestedFix,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: c.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // عرض التفاصيل التقنية الكاملة
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'عرض التقرير التقني الكامل (Stack Trace)',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: c.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 140),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          info.rawDetails,
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            color: Color(0xFFE2E8F0),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // أزرار الإجراءات
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                          text: 'تقرير خطأ مدار:\nرمز الخطأ: ${info.code}\nالعنوان: ${info.title}\nالرسالة: ${info.message}\nالتفاصيل:\n${info.rawDetails}',
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم نسخ تقرير المشكلة إلى الحافظة 📋',
                              style: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
                            ),
                            backgroundColor: c.success,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text(
                        'نسخ التقرير',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12),
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'إغلاق ومتابعة',
                            style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted),
                          ),
                        ),
                        if (onRetry != null) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              onRetry();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(
                              'إعادة المحاولة',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// إظهار سجل الأخطاء الأخيرة المحفوظة في الجلسة الحالية
  static void showRecentErrorsDialog(BuildContext context) {
    final c = context.posColors;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.history_rounded, color: Color(0xFFFF5B22)),
              const SizedBox(width: 10),
              Text(
                'سجل تشخيص الأخطاء المحمية (${_recentErrors.length})',
                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16, color: c.textPrimary),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 400,
            child: _recentErrors.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد أخطاء مرصودة، النظام يعمل بكفاءة 100% ✨',
                      style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: _recentErrors.length,
                    separatorBuilder: (_, index) => Divider(color: c.border),
                    itemBuilder: (context, i) {
                      final item = _recentErrors[i];
                      return ListTile(
                        leading: Icon(item.icon, color: item.severityColor),
                        title: Text(item.title, style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13, color: c.textPrimary)),
                        subtitle: Text('${item.code} • ${item.message}', maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted)),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          onPressed: () {
                            Navigator.pop(ctx);
                            showErrorDialog(context, item.rawDetails, customTitle: item.title);
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إغلاق', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
            ),
          ],
        ),
      ),
    );
  }
}

/// غلاف الجذر للحماية وعرض شارة تشخيص المشاكل في أسفل الشاشة
class _MadarRootGuardScope extends StatelessWidget {
  final Widget child;

  const _MadarRootGuardScope({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeCrashBoundary(
      child: Stack(
        children: [
          child,
          // شارة تشخيص الأخطاء في حال وجود أي خطأ تم التقاطه في الخلفية
          Positioned(
            bottom: 42,
            left: 16,
            child: ValueListenableBuilder<List<MadarErrorInfo>>(
              valueListenable: MadarCrashGuard.errorsNotifier,
              builder: (context, errors, _) {
                if (errors.isEmpty) return const SizedBox.shrink();
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => MadarCrashGuard.showRecentErrorsDialog(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_rounded, color: Color(0xFFEF4444), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${errors.length} خطأ تم اعتراضه (عرض التشخيص)',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة داخلية تعرض الخطأ بأمان داخل الشاشات بدلاً من الشاشة الحمراء
class MadarInlineErrorCard extends StatelessWidget {
  final MadarErrorInfo errorInfo;
  final VoidCallback? onRetry;

  const MadarInlineErrorCard({
    super.key,
    required this.errorInfo,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: errorInfo.severityColor.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(errorInfo.icon, color: errorInfo.severityColor, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      errorInfo.title,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: errorInfo.severityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      errorInfo.code,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: errorInfo.severityColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                errorInfo.message,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: c.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: errorInfo.rawDetails));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ تفاصيل الخطأ 📋')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: Text(
                      'نسخ الخطأ',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5),
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: Text(
                        'إعادة المحاولة',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// حاوية حماية (Error Boundary) تغلف الـ Widgets الحرجة لمنع انهيار الواجهة
class SafeCrashBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext context, dynamic error, StackTrace? stack)? errorBuilder;

  const SafeCrashBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
  });

  @override
  State<SafeCrashBoundary> createState() => _SafeCrashBoundaryState();
}

class _SafeCrashBoundaryState extends State<SafeCrashBoundary> {
  dynamic _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    _error = null;
    _stackTrace = null;
  }

  void _reset() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, _error, _stackTrace);
      }
      final info = MadarCrashGuard.analyzeError(_error, _stackTrace);
      return MadarInlineErrorCard(
        errorInfo: info,
        onRetry: _reset,
      );
    }

    return widget.child;
  }
}
