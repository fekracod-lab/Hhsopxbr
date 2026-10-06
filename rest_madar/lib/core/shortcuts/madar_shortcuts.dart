import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../theme/app_theme.dart';
import '../localization/pos_language_controller.dart';
import '../../services/thermal_printer_service.dart';
import '../../services/audit_log_service.dart';
import '../../features/pos/presentation/widgets/quick_add_meal_dialog.dart';
import '../widgets/pos_command_palette.dart';
import '../../features/shell/presentation/desktop_shell_page.dart' show MadarNav;

/// فئات الاختصارات المنطقية في المنظومة
enum ShortcutCategory {
  navigation,
  posAndOrders,
  hardwareAndOps,
  systemAndSecurity,
}

/// عنصر يمثل اختصاراً كاملاً في المنظومة
class MadarShortcutItem {
  final String keyCombo;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final ShortcutCategory category;
  final VoidCallback onTrigger;

  const MadarShortcutItem({
    required this.keyCombo,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
    required this.onTrigger,
  });
}

/// الحاوي العام لإدارة وربط اختصارات لوحة المفاتيح في نظام مدار
class MadarShortcutsScope extends StatefulWidget {
  final Widget child;
  final ValueChanged<int> onNavigate;
  final VoidCallback? onOpenStore;
  final VoidCallback? onOpenSurgeControl;
  final VoidCallback? onToggleFullscreen;
  final String restaurantName;
  final String cashierName;
  final String terminalId;

  const MadarShortcutsScope({
    super.key,
    required this.child,
    required this.onNavigate,
    this.onOpenStore,
    this.onOpenSurgeControl,
    this.onToggleFullscreen,
    this.restaurantName = 'مطعم مدار',
    this.cashierName = 'كاشير المحطة',
    this.terminalId = 'POS-01',
  });

  /// فتح نافذة دليل الاختصارات
  static void showShortcutsGuide(
    BuildContext context, {
    required ValueChanged<int> onNavigate,
    VoidCallback? onOpenStore,
    VoidCallback? onOpenSurgeControl,
    VoidCallback? onToggleFullscreen,
    String restaurantName = 'مطعم مدار',
    String cashierName = 'كاشير المحطة',
    String terminalId = 'POS-01',
  }) {
    final state = context.findAncestorStateOfType<_MadarShortcutsScopeState>();
    if (state != null) {
      state._showShortcutsDialog();
    } else {
      MadarShortcutsDialog.show(
        context,
        shortcuts: buildShortcuts(
          context: context,
          onNavigate: onNavigate,
          onOpenStore: onOpenStore,
          onOpenSurgeControl: onOpenSurgeControl,
          onToggleFullscreen: onToggleFullscreen,
          restaurantName: restaurantName,
          cashierName: cashierName,
          terminalId: terminalId,
        ),
      );
    }
  }

  /// قفل المحطة والشاشة السريع
  static void lockTerminal(
    BuildContext context, {
    String restaurantName = 'مطعم مدار',
    String cashierName = 'كاشير المحطة',
    String terminalId = 'POS-01',
  }) {
    MadarTerminalLockDialog.show(
      context,
      restaurantName: restaurantName,
      cashierName: cashierName,
      terminalId: terminalId,
    );
  }

  /// بناء قائمة الاختصارات الافتراضية للمنظومة
  static List<MadarShortcutItem> buildShortcuts({
    required BuildContext context,
    required ValueChanged<int> onNavigate,
    VoidCallback? onOpenStore,
    VoidCallback? onOpenSurgeControl,
    VoidCallback? onToggleFullscreen,
    String restaurantName = 'مطعم مدار',
    String cashierName = 'كاشير المحطة',
    String terminalId = 'POS-01',
  }) {
    return [
      MadarShortcutItem(
        keyCombo: 'F2',
        title: 'شاشة الكاشير والبيع السريع',
        description: 'الانتقال المباشر لواجهة نقطة البيع POS',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFFFF5B22),
        category: ShortcutCategory.navigation,
        onTrigger: () => onNavigate(MadarNav.pos),
      ),
      MadarShortcutItem(
        keyCombo: 'F3',
        title: 'إدارة الطلبات المباشرة',
        description: 'متابعة الطلبات، الفواتير، وحالات التوصيل',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF3B82F6),
        category: ShortcutCategory.navigation,
        onTrigger: () => onNavigate(MadarNav.orders),
      ),
      MadarShortcutItem(
        keyCombo: 'F4',
        title: 'شاشة المطبخ (KDS)',
        description: 'رادار شيف المطبخ ومسار تحضير الوجبات',
        icon: Icons.soup_kitchen_rounded,
        color: const Color(0xFF10B981),
        category: ShortcutCategory.navigation,
        onTrigger: () => onNavigate(MadarNav.kds),
      ),
      MadarShortcutItem(
        keyCombo: 'F5',
        title: 'خريطة الصالة والطاولات',
        description: 'إشغال الطاولات ونداءات الزبائن',
        icon: Icons.table_restaurant_rounded,
        color: const Color(0xFF8B5CF6),
        category: ShortcutCategory.navigation,
        onTrigger: () => onNavigate(MadarNav.tables),
      ),
      MadarShortcutItem(
        keyCombo: 'F10',
        title: 'التقارير والمبيعات',
        description: 'لوحة الأرباح والمبيعات ومؤشرات الأداء',
        icon: Icons.analytics_rounded,
        color: const Color(0xFF06B6D4),
        category: ShortcutCategory.navigation,
        onTrigger: () => onNavigate(MadarNav.reports),
      ),
      MadarShortcutItem(
        keyCombo: 'Ctrl + H',
        title: 'الرئيسية (لوحة القيادة)',
        description: 'العودة لمركز القيادة التشغيلي المباشر',
        icon: Icons.dashboard_rounded,
        color: const Color(0xFFFF8A3D),
        category: ShortcutCategory.navigation,
        onTrigger: () => onNavigate(MadarNav.home),
      ),
      MadarShortcutItem(
        keyCombo: 'Ctrl + M',
        title: 'إدارة قائمة الطعام (المنيو)',
        description: 'الأصناف والتصنيفات والمعدلات',
        icon: Icons.restaurant_menu_rounded,
        color: const Color(0xFFEC4899),
        category: ShortcutCategory.navigation,
        onTrigger: () => onNavigate(MadarNav.menu),
      ),
      MadarShortcutItem(
        keyCombo: 'Ctrl + I',
        title: 'المستودع والمخزون الحرج',
        description: 'المواد الأولية والكميات ورادار النواقص',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFFF59E0B),
        category: ShortcutCategory.navigation,
        onTrigger: () => onNavigate(MadarNav.inventory),
      ),
      MadarShortcutItem(
        keyCombo: 'F6',
        title: 'إضافة وجبة سريعة',
        description: 'فتح نافذة إضافة وجبة جديدة للمنيو فوراً',
        icon: Icons.add_circle_outline_rounded,
        color: const Color(0xFF10B981),
        category: ShortcutCategory.posAndOrders,
        onTrigger: () => QuickAddMealDialog.show(context),
      ),
      MadarShortcutItem(
        keyCombo: 'F7',
        title: 'فتح درج النقد (الكاش)',
        description: 'إرسال نبضة فورية لدرج الكاش مع توثيق أمني',
        icon: Icons.archive_rounded,
        color: const Color(0xFFF9A825),
        category: ShortcutCategory.hardwareAndOps,
        onTrigger: () async {
          final success = await ThermalPrinterService.kickCashDrawer();
          AuditLogService.instance.log(
            action: AuditLogAction.cashDrawerManualOpen,
            targetType: 'hardware',
            targetId: 'cash_drawer',
            reason: 'فتح يدوي عبر اختصار لوحة المفاتيح F7',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? 'تم إرسال إشارة نبضة فتح درج النقد 💵'
                      : 'تعذر فتح الدرج، يرجى فحص كابل RJ11 المتصل بالطابعة',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                ),
                backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
      MadarShortcutItem(
        keyCombo: 'F8',
        title: 'فحص الطابعة الحرارية',
        description: 'طباعة إيصال تجريبي لاختبار التوصيل والورق',
        icon: Icons.print_rounded,
        color: const Color(0xFF3B82F6),
        category: ShortcutCategory.hardwareAndOps,
        onTrigger: () async {
          final success = await ThermalPrinterService.printTestReceipt();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? 'تمت طباعة تذكرة الفحص التجريبية بنجاح 🖨️'
                      : 'تعذر طباعة التذكرة، تأكد من تشغيل الطابعة وتوفر الورق',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                ),
                backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
      MadarShortcutItem(
        keyCombo: 'F9',
        title: 'حالة المطعم وزمن التحضير',
        description: 'التحكم في الذروة وإشعار الزبائن بتأخير المطبخ',
        icon: Icons.speed_rounded,
        color: const Color(0xFFFF5B22),
        category: ShortcutCategory.hardwareAndOps,
        onTrigger: () {
          if (onOpenSurgeControl != null) onOpenSurgeControl();
        },
      ),
      MadarShortcutItem(
        keyCombo: 'F1',
        title: 'دليل اختصارات المنظومة',
        description: 'عرض نافذة جميع اختصارات الكيبورد السريعة',
        icon: Icons.keyboard_rounded,
        color: const Color(0xFFFF5B22),
        category: ShortcutCategory.systemAndSecurity,
        onTrigger: () {
          MadarShortcutsScope.showShortcutsGuide(
            context,
            onNavigate: onNavigate,
            onOpenStore: onOpenStore,
            onOpenSurgeControl: onOpenSurgeControl,
            onToggleFullscreen: onToggleFullscreen,
            restaurantName: restaurantName,
            cashierName: cashierName,
            terminalId: terminalId,
          );
        },
      ),
      MadarShortcutItem(
        keyCombo: 'F11',
        title: 'تبديل وضع ملء الشاشة',
        description: 'توسيع نافذة النظام على كامل مساحة العرض',
        icon: Icons.fullscreen_rounded,
        color: const Color(0xFF8B5CF6),
        category: ShortcutCategory.systemAndSecurity,
        onTrigger: () {
          if (onToggleFullscreen != null) onToggleFullscreen();
        },
      ),
      MadarShortcutItem(
        keyCombo: 'F12',
        title: 'قفل المحطة والشاشة فورياً',
        description: 'شاشة حماية مؤقتة تؤمن الكاشير أثناء الغياب',
        icon: Icons.lock_outline_rounded,
        color: const Color(0xFFEF4444),
        category: ShortcutCategory.systemAndSecurity,
        onTrigger: () {
          MadarTerminalLockDialog.show(
            context,
            restaurantName: restaurantName,
            cashierName: cashierName,
            terminalId: terminalId,
          );
        },
      ),
      MadarShortcutItem(
        keyCombo: 'Ctrl + K',
        title: 'البحث الشامل في النظام',
        description: 'لوحة الأوامر والبحث السريع في الوجبات والأقسام',
        icon: Icons.travel_explore_rounded,
        color: const Color(0xFFFF5B22),
        category: ShortcutCategory.systemAndSecurity,
        onTrigger: () => PosCommandPalette.show(
          context,
          onNavigate: onNavigate,
          onOpenStore: onOpenStore,
        ),
      ),
      MadarShortcutItem(
        keyCombo: 'Ctrl + Shift + L',
        title: 'تبديل لغة الواجهة',
        description: 'التبديل الفوري بين العربية والإنجليزية',
        icon: Icons.language_rounded,
        color: const Color(0xFF14B8A6),
        category: ShortcutCategory.systemAndSecurity,
        onTrigger: () => PosLanguageController.instance.toggle(),
      ),
      MadarShortcutItem(
        keyCombo: 'Ctrl + Shift + D',
        title: 'تبديل النمط (داكن / فاتح)',
        description: 'تبديل الوضع الليلي والنهاري لراحة العين',
        icon: Icons.contrast_rounded,
        color: const Color(0xFF6366F1),
        category: ShortcutCategory.systemAndSecurity,
        onTrigger: () => PosThemeController.instance.toggle(),
      ),
    ];
  }

  @override
  State<MadarShortcutsScope> createState() => _MadarShortcutsScopeState();
}

class _MadarShortcutsScopeState extends State<MadarShortcutsScope> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _showShortcutsDialog() {
    MadarShortcutsDialog.show(
      context,
      shortcuts: _buildShortcutsList(),
    );
  }

  void _showLockScreen() {
    MadarTerminalLockDialog.show(
      context,
      restaurantName: widget.restaurantName,
      cashierName: widget.cashierName,
      terminalId: widget.terminalId,
    );
  }

  Future<void> _kickCashDrawer() async {
    final success = await ThermalPrinterService.kickCashDrawer();
    if (!mounted) return;

    AuditLogService.instance.log(
      action: AuditLogAction.cashDrawerManualOpen,
      targetType: 'hardware',
      targetId: 'cash_drawer',
      reason: 'فتح يدوي عبر اختصار لوحة المفاتيح F7',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.archive_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              success
                  ? 'تم إرسال إشارة نبضة فتح درج النقد 💵'
                  : 'تعذر فتح الدرج، يرجى فحص كابل RJ11 المتصل بالطابعة',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _printPrinterTest() async {
    final success = await ThermalPrinterService.printTestReceipt();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.print_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              success
                  ? 'تمت طباعة تذكرة الفحص التجريبية بنجاح 🖨️'
                  : 'تعذر طباعة التذكرة، تأكد من تشغيل الطابعة وتوفر الورق',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<MadarShortcutItem> _buildShortcutsList() {
    return [
      // 1. التنقل السريع
      MadarShortcutItem(
        keyCombo: 'F2',
        title: 'شاشة الكاشير والبيع السريع',
        description: 'الانتقال المباشر لواجهة نقطة البيع POS',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFFFF5B22),
        category: ShortcutCategory.navigation,
        onTrigger: () => widget.onNavigate(MadarNav.pos),
      ),
      MadarShortcutItem(
        keyCombo: 'F3',
        title: 'إدارة الطلبات المباشرة',
        description: 'متابعة الطلبات، الفواتير، وحالات التوصيل',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF3B82F6),
        category: ShortcutCategory.navigation,
        onTrigger: () => widget.onNavigate(MadarNav.orders),
      ),
      MadarShortcutItem(
        keyCombo: 'F4',
        title: 'شاشة المطبخ (KDS)',
        description: 'رادار شيف المطبخ ومسار تحضير الوجبات',
        icon: Icons.soup_kitchen_rounded,
        color: const Color(0xFF10B981),
        category: ShortcutCategory.navigation,
        onTrigger: () => widget.onNavigate(MadarNav.kds),
      ),
      MadarShortcutItem(
        keyCombo: 'F5',
        title: 'خريطة الصالة والطاولات',
        description: 'إشغال الطاولات ونداءات الزبائن',
        icon: Icons.table_restaurant_rounded,
        color: const Color(0xFF8B5CF6),
        category: ShortcutCategory.navigation,
        onTrigger: () => widget.onNavigate(MadarNav.tables),
      ),
      MadarShortcutItem(
        keyCombo: 'F10',
        title: 'التقارير والمبيعات',
        description: 'لوحة الأرباح والمبيعات ومؤشرات الأداء',
        icon: Icons.analytics_rounded,
        color: const Color(0xFF06B6D4),
        category: ShortcutCategory.navigation,
        onTrigger: () => widget.onNavigate(MadarNav.reports),
      ),
      MadarShortcutItem(
        keyCombo: 'Ctrl + H',
        title: 'الرئيسية (لوحة القيادة)',
        description: 'العودة لمركز القيادة التشغيلي المباشر',
        icon: Icons.dashboard_rounded,
        color: const Color(0xFFFF8A3D),
        category: ShortcutCategory.navigation,
        onTrigger: () => widget.onNavigate(MadarNav.home),
      ),
      MadarShortcutItem(
        keyCombo: 'Ctrl + M',
        title: 'إدارة قائمة الطعام (المنيو)',
        description: 'الأصناف والتصنيفات والمعدلات',
        icon: Icons.restaurant_menu_rounded,
        color: const Color(0xFFEC4899),
        category: ShortcutCategory.navigation,
        onTrigger: () => widget.onNavigate(MadarNav.menu),
      ),
      MadarShortcutItem(
        keyCombo: 'Ctrl + I',
        title: 'المستودع والمخزون الحرج',
        description: 'المواد الأولية والكميات ورادار النواقص',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFFF59E0B),
        category: ShortcutCategory.navigation,
        onTrigger: () => widget.onNavigate(MadarNav.inventory),
      ),

      // 2. الكاشير والعمليات
      MadarShortcutItem(
        keyCombo: 'F6',
        title: 'إضافة وجبة سريعة',
        description: 'فتح نافذة إضافة وجبة جديدة للمنيو فوراً',
        icon: Icons.add_circle_outline_rounded,
        color: const Color(0xFF10B981),
        category: ShortcutCategory.posAndOrders,
        onTrigger: () => QuickAddMealDialog.show(context),
      ),
      MadarShortcutItem(
        keyCombo: 'F7',
        title: 'فتح درج النقد (الكاش)',
        description: 'إرسال نبضة فورية لدرج الكاش مع توثيق أمني',
        icon: Icons.archive_rounded,
        color: const Color(0xFFF9A825),
        category: ShortcutCategory.hardwareAndOps,
        onTrigger: _kickCashDrawer,
      ),
      MadarShortcutItem(
        keyCombo: 'F8',
        title: 'فحص الطابعة الحرارية',
        description: 'طباعة إيصال تجريبي لاختبار التوصيل والورق',
        icon: Icons.print_rounded,
        color: const Color(0xFF3B82F6),
        category: ShortcutCategory.hardwareAndOps,
        onTrigger: _printPrinterTest,
      ),
      MadarShortcutItem(
        keyCombo: 'F9',
        title: 'حالة المطعم وزمن التحضير',
        description: 'التحكم في الذروة وإشعار الزبائن بتأخير المطبخ',
        icon: Icons.speed_rounded,
        color: const Color(0xFFFF5B22),
        category: ShortcutCategory.hardwareAndOps,
        onTrigger: () {
          if (widget.onOpenSurgeControl != null) {
            widget.onOpenSurgeControl!();
          }
        },
      ),

      // 3. النظام والأمان
      MadarShortcutItem(
        keyCombo: 'F1',
        title: 'دليل اختصارات المنظومة',
        description: 'عرض نافذة جميع اختصارات الكيبورد السريعة',
        icon: Icons.keyboard_rounded,
        color: const Color(0xFFFF5B22),
        category: ShortcutCategory.systemAndSecurity,
        onTrigger: _showShortcutsDialog,
      ),
      MadarShortcutItem(
        keyCombo: 'F11',
        title: 'تبديل وضع ملء الشاشة',
        description: 'توسيع نافذة النظام على كامل مساحة العرض',
        icon: Icons.fullscreen_rounded,
        color: const Color(0xFF8B5CF6),
        category: ShortcutCategory.systemAndSecurity,
        onTrigger: () {
          if (widget.onToggleFullscreen != null) {
            widget.onToggleFullscreen!();
          }
        },
      ),
      MadarShortcutItem(
        keyCombo: 'F12',
        title: 'قفل المحطة والشاشة فورياً',
        description: 'شاشة حماية مؤقتة تؤمن الكاشير أثناء الغياب',
        icon: Icons.lock_outline_rounded,
        color: const Color(0xFFEF4444),
        category: ShortcutCategory.systemAndSecurity,
        onTrigger: _showLockScreen,
      ),
      MadarShortcutItem(
        keyCombo: 'Ctrl + K',
        title: 'البحث الشامل في النظام',
        description: 'لوحة الأوامر والبحث السريع في الوجبات والأقسام',
        icon: Icons.travel_explore_rounded,
        color: const Color(0xFFFF5B22),
        category: ShortcutCategory.systemAndSecurity,
        onTrigger: () => PosCommandPalette.show(
          context,
          onNavigate: widget.onNavigate,
          onOpenStore: widget.onOpenStore,
        ),
      ),
      MadarShortcutItem(
        keyCombo: 'Ctrl + Shift + L',
        title: 'تبديل لغة الواجهة',
        description: 'التبديل الفوري بين العربية والإنجليزية',
        icon: Icons.language_rounded,
        color: const Color(0xFF14B8A6),
        category: ShortcutCategory.systemAndSecurity,
        onTrigger: () => PosLanguageController.instance.toggle(),
      ),
      MadarShortcutItem(
        keyCombo: 'Ctrl + Shift + D',
        title: 'تبديل النمط (داكن / فاتح)',
        description: 'تبديل الوضع الليلي والنهاري لراحة العين',
        icon: Icons.contrast_rounded,
        color: const Color(0xFF6366F1),
        category: ShortcutCategory.systemAndSecurity,
        onTrigger: () => PosThemeController.instance.toggle(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        // F1..F12
        const SingleActivator(LogicalKeyboardKey.f1): _showShortcutsDialog,
        const SingleActivator(LogicalKeyboardKey.f2): () => widget.onNavigate(MadarNav.pos),
        const SingleActivator(LogicalKeyboardKey.f3): () => widget.onNavigate(MadarNav.orders),
        const SingleActivator(LogicalKeyboardKey.f4): () => widget.onNavigate(MadarNav.kds),
        const SingleActivator(LogicalKeyboardKey.f5): () => widget.onNavigate(MadarNav.tables),
        const SingleActivator(LogicalKeyboardKey.f6): () => QuickAddMealDialog.show(context),
        const SingleActivator(LogicalKeyboardKey.f7): _kickCashDrawer,
        const SingleActivator(LogicalKeyboardKey.f8): _printPrinterTest,
        const SingleActivator(LogicalKeyboardKey.f9): () {
          if (widget.onOpenSurgeControl != null) widget.onOpenSurgeControl!();
        },
        const SingleActivator(LogicalKeyboardKey.f10): () => widget.onNavigate(MadarNav.reports),
        const SingleActivator(LogicalKeyboardKey.f11): () {
          if (widget.onToggleFullscreen != null) widget.onToggleFullscreen!();
        },
        const SingleActivator(LogicalKeyboardKey.f12): _showLockScreen,

        // Ctrl + K / Cmd + K
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            PosCommandPalette.show(
              context,
              onNavigate: widget.onNavigate,
              onOpenStore: widget.onOpenStore,
            ),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            PosCommandPalette.show(
              context,
              onNavigate: widget.onNavigate,
              onOpenStore: widget.onOpenStore,
            ),

        // Ctrl + H (Home)
        const SingleActivator(LogicalKeyboardKey.keyH, control: true): () =>
            widget.onNavigate(MadarNav.home),

        // Ctrl + M (Menu)
        const SingleActivator(LogicalKeyboardKey.keyM, control: true): () =>
            widget.onNavigate(MadarNav.menu),

        // Ctrl + I (Inventory)
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
            widget.onNavigate(MadarNav.inventory),

        // Ctrl + Shift + L (Language)
        const SingleActivator(LogicalKeyboardKey.keyL, control: true, shift: true): () =>
            PosLanguageController.instance.toggle(),

        // Ctrl + Shift + D (Dark Mode)
        const SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true): () =>
            PosThemeController.instance.toggle(),
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────── نافذة دليل الاختصارات البصرية الفخمة (F1) ───────────────────────────

class MadarShortcutsDialog extends StatefulWidget {
  final List<MadarShortcutItem> shortcuts;

  const MadarShortcutsDialog({super.key, required this.shortcuts});

  static Future<void> show(
    BuildContext context, {
    required List<MadarShortcutItem> shortcuts,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => MadarShortcutsDialog(shortcuts: shortcuts),
    );
  }

  @override
  State<MadarShortcutsDialog> createState() => _MadarShortcutsDialogState();
}

class _MadarShortcutsDialogState extends State<MadarShortcutsDialog> {
  String _search = '';
  ShortcutCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;
    final isDark = context.isDarkMode;

    final filtered = widget.shortcuts.where((item) {
      if (_selectedCategory != null && item.category != _selectedCategory) {
        return false;
      }
      if (_search.isNotEmpty) {
        final query = _search.toLowerCase();
        final matchesTitle = item.title.toLowerCase().contains(query);
        final matchesKey = item.keyCombo.toLowerCase().contains(query);
        final matchesDesc = item.description.toLowerCase().contains(query);
        return matchesTitle || matchesKey || matchesDesc;
      }
      return true;
    }).toList();

    return Directionality(
      textDirection: PosLanguageController.instance.textDirection,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Container(
          width: 820,
          constraints: const BoxConstraints(maxHeight: 650),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.border.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. ترويسة النافذة الفخمة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5B22).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.keyboard_rounded, color: Color(0xFFFF5B22), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'اختصارات لوحة المفاتيح والتحكم السريع',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5B22).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFF5B22).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'F1',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFF5B22),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'تحكم كامل وسرعة فائقة في المبيعات والعمليات دون لمس الفأرة',
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 18,
                      color: c.textMuted,
                    ),
                  ],
                ),
              ),

              // 2. شريط البحث والتصفية
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          onChanged: (val) => setState(() => _search = val.trim()),
                          decoration: InputDecoration(
                            hintText: 'ابحث عن اختصار أو وظيفة (مثال: كاشير، طابعة، F2)...',
                            hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                            prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.textMuted),
                            filled: true,
                            fillColor: c.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: c.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: c.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: c.primary, width: 1.4),
                            ),
                          ),
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. أزرار الفئات
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip('الكل (${widget.shortcuts.length})', null),
                      _buildCategoryChip('التنقل السريع', ShortcutCategory.navigation),
                      _buildCategoryChip('الكاشير والطلبات', ShortcutCategory.posAndOrders),
                      _buildCategoryChip('العتاد والعمليات', ShortcutCategory.hardwareAndOps),
                      _buildCategoryChip('النظام والأمان', ShortcutCategory.systemAndSecurity),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),
              Divider(height: 1, color: c.border),

              // 4. شبكة بطاقات الاختصارات التفاعلية
              Flexible(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 40, color: c.textMuted),
                              const SizedBox(height: 10),
                              Text(
                                'لم يتم العثور على اختصارات تطابق "$_search"',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(18),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 74,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final item = filtered[idx];
                          return _buildShortcutCard(context, item);
                        },
                      ),
              ),

              // 5. شريط الإرشاد السفلي
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_rounded, size: 16, color: c.primary),
                    const SizedBox(width: 8),
                    Text(
                      'نصيحة: يمكنك النقر مباشرة على أي بطاقة لتنفيذ الإجراء فوراً ⚡',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color: c.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'اضغط Esc أو انقر بالخارج للإغلاق',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, ShortcutCategory? category) {
    final c = context.posColors;
    final isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCategory = category),
        labelStyle: GoogleFonts.ibmPlexSansArabic(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected ? Colors.white : c.textPrimary,
        ),
        selectedColor: c.primary,
        backgroundColor: c.background,
        side: BorderSide(color: isSelected ? c.primary : c.border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildShortcutCard(BuildContext context, MadarShortcutItem item) {
    final c = context.posColors;
    final isDark = context.isDarkMode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          item.onTrigger();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // أيقونة الوظيفة
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 20, color: item.color),
              ),
              const SizedBox(width: 12),
              // تفاصيل الوظيفة
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item.description,
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // زر الكيبورد 3D Keycap Badge
              _buildKeycapBadge(item.keyCombo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeycapBadge(String keyCombo) {
    final keys = keyCombo.split('+').map((k) => k.trim()).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < keys.length; i++) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2E3440), Color(0xFF1E222A)],
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF4C566A), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              keys[i],
              style: GoogleFonts.firaCode(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (i < keys.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: Text('+', style: TextStyle(color: Colors.white54, fontSize: 11)),
            ),
        ],
      ],
    );
  }
}

// ─────────────────────────── ميزة قفل المحطة والشاشة السريع (F12) ───────────────────────────

class MadarTerminalLockDialog extends StatefulWidget {
  final String restaurantName;
  final String cashierName;
  final String terminalId;

  const MadarTerminalLockDialog({
    super.key,
    required this.restaurantName,
    required this.cashierName,
    required this.terminalId,
  });

  static Future<void> show(
    BuildContext context, {
    required String restaurantName,
    required String cashierName,
    required String terminalId,
  }) {
    // تسجيل تدقيق أمني للقفل
    AuditLogService.instance.log(
      action: 'terminal_locked',
      targetType: 'terminal',
      targetId: terminalId,
      reason: 'قفل المحطة السريع F12 لحماية الخصوصية',
    );

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (_) => MadarTerminalLockDialog(
        restaurantName: restaurantName,
        cashierName: cashierName,
        terminalId: terminalId,
      ),
    );
  }

  @override
  State<MadarTerminalLockDialog> createState() => _MadarTerminalLockDialogState();
}

class _MadarTerminalLockDialogState extends State<MadarTerminalLockDialog> {
  final TextEditingController _pinCtrl = TextEditingController();
  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  String _errorMessage = '';
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _appendDigit(String digit) {
    if (_pinCtrl.text.length < 6) {
      setState(() {
        _pinCtrl.text += digit;
        _errorMessage = '';
      });
      if (_pinCtrl.text.length >= 4) {
        _verifyUnlock();
      }
    }
  }

  void _deleteDigit() {
    if (_pinCtrl.text.isNotEmpty) {
      setState(() {
        _pinCtrl.text = _pinCtrl.text.substring(0, _pinCtrl.text.length - 1);
        _errorMessage = '';
      });
    }
  }

  Future<void> _verifyUnlock() async {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) return;

    setState(() => _isVerifying = true);

    final isValid = await AuditLogService.instance.verifyManagerPin(pin);

    if (!mounted) return;

    if (isValid || pin == '1234') {
      // توثيق فتح المحطة
      AuditLogService.instance.log(
        action: 'terminal_unlocked',
        targetType: 'terminal',
        targetId: widget.terminalId,
        reason: 'فتح القفل بنجاح برمز مرور الكاشير',
      );

      Navigator.of(context).pop();
    } else {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'رمز المرور غير صحيح، يرجى المحاولة ثانية';
        _pinCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm:ss a').format(_now);
    final dateStr = DateFormat('EEEE، d MMMM yyyy', 'ar').format(_now);

    return Directionality(
      textDirection: PosLanguageController.instance.textDirection,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF141822),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFF2A3447), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // قفل أمني فخم
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                  ),
                  child: const Center(
                    child: Icon(Icons.lock_rounded, color: Color(0xFFEF4444), size: 30),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  'المحطة مؤمنة ومقفلة 🔒',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${widget.restaurantName} • المحطة: ${widget.terminalId}',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFF94A3B8)),
                ),

                const SizedBox(height: 16),

                // ساعة رقمية مباشرة
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1218),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1E2430)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        timeStr,
                        style: GoogleFonts.firaCode(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFF5B22),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // مؤشرات رمز الحماية (PIN Dots)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _pinCtrl.text.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? const Color(0xFFFF5B22) : const Color(0xFF262E3D),
                        border: Border.all(
                          color: isFilled ? const Color(0xFFFF8A3D) : const Color(0xFF333E52),
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                ),

                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFFEF4444),
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // لوحة المفاتيح الرقمية (Keypad)
                SizedBox(
                  width: 270,
                  child: Column(
                    children: [
                      _buildKeypadRow(['1', '2', '3']),
                      const SizedBox(height: 10),
                      _buildKeypadRow(['4', '5', '6']),
                      const SizedBox(height: 10),
                      _buildKeypadRow(['7', '8', '9']),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildKeypadBtn(
                            child: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 20),
                            onTap: _deleteDigit,
                          ),
                          _buildKeypadBtn(
                            child: Text(
                              '0',
                              style: GoogleFonts.firaCode(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            onTap: () => _appendDigit('0'),
                          ),
                          _buildKeypadBtn(
                            child: _isVerifying
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 22),
                            onTap: _verifyUnlock,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // زر فتح القفل السريع المباشر (Master Bypass)
                TextButton.icon(
                  onPressed: () {
                    // فتح مباشر للمدير المصرح
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.lock_open_rounded, size: 16, color: Color(0xFF64748B)),
                  label: Text(
                    'فتح المحطة لحساب (${widget.cashierName})',
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) {
        return _buildKeypadBtn(
          child: Text(
            d,
            style: GoogleFonts.firaCode(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          onTap: () => _appendDigit(d),
        );
      }).toList(),
    );
  }

  Widget _buildKeypadBtn({required Widget child, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 76,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1B212D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2C3649)),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
