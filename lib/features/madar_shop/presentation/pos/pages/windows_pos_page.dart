// واجهة نقطة البيع الرئيسية لبيئة ويندوز (MADAR SHOP Windows POS Main Shell)
// Presentation Layer — Keyboard-First, Touch-Friendly, Responsive Layout & Zero Logic Duplication

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/identity/rbac/shop_permission.dart';
import '../controllers/windows_pos_controller.dart';
import '../widgets/pos_cart_pane.dart';
import '../widgets/pos_category_filter.dart';
import '../widgets/pos_customer_dialog.dart';
import '../widgets/pos_discount_dialog.dart';
import '../widgets/pos_payment_dialog.dart';
import '../widgets/pos_product_grid.dart';
import '../widgets/pos_returns_dialog.dart';
import '../widgets/pos_search_bar.dart';
import '../widgets/pos_top_status_bar.dart';
import '../widgets/pos_total_summary_bar.dart';

class WindowsPosPage extends StatefulWidget {
  final WindowsPosController controller;
  final VoidCallback? onLogout;

  const WindowsPosPage({
    super.key,
    required this.controller,
    this.onLogout,
  });

  @override
  State<WindowsPosPage> createState() => _WindowsPosPageState();
}

class _WindowsPosPageState extends State<WindowsPosPage> {
  final FocusNode _searchFocusNode = FocusNode();
  late final WindowsPosController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;

    // التحقق الصارم من صلاحية الجلسة عند الدخول المباشر
    _validateSessionGuard();

    _controller.addListener(_onControllerUpdated);
    _controller.loadCatalog();

    // طلب التركيز على شريط البحث بعد اكتمال البناء الأول
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _validateSessionGuard() {
    final coordinator = _controller.identityCoordinator;
    if (!coordinator.isAuthenticated || !coordinator.hasPermission(ShopPermission.accessPos)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.onLogout != null) {
          widget.onLogout!();
        }
      });
    }
  }

  void _onControllerUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdated);
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ─── معالجات اختصارات لوحة المفاتيح (F1 - F10) ───
  void _handleF1Search() {
    _searchFocusNode.requestFocus();
  }

  void _handleF2Customer() {
    showDialog(
      context: context,
      builder: (_) => PosCustomerDialog(controller: _controller),
    );
  }

  void _handleF3Discount() {
    showDialog(
      context: context,
      builder: (_) => PosDiscountDialog(controller: _controller),
    );
  }

  void _handleF4Hold() {
    _controller.holdCurrentCart();
  }

  void _handleF5Payment() {
    if (_controller.currentCart.isNotEmpty && !_controller.isProcessingPayment) {
      showDialog(
        context: context,
        builder: (_) => PosPaymentDialog(controller: _controller),
      );
    }
  }

  void _handleF8Returns() {
    showDialog(
      context: context,
      builder: (_) => PosReturnsDialog(controller: _controller),
    );
  }

  void _handleF9NewSale() {
    if (_controller.currentCart.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('بدء فاتورة جديدة', style: TextStyle(fontFamily: 'Cairo')),
          content: const Text('هل أنت متأكد من تفريغ السلة الحالية والبدء من جديد؟', style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                _controller.clearCurrentCart();
                Navigator.pop(ctx);
              },
              child: const Text('نعم، تفريغ السلة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      _controller.clearCurrentCart();
    }
  }

  void _handleF10Close() {
    if (widget.onLogout != null) {
      widget.onLogout!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // خريطة اختصارات لوحة المفاتيح
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.f1): _handleF1Search,
      const SingleActivator(LogicalKeyboardKey.f2): _handleF2Customer,
      const SingleActivator(LogicalKeyboardKey.f3): _handleF3Discount,
      const SingleActivator(LogicalKeyboardKey.f4): _handleF4Hold,
      const SingleActivator(LogicalKeyboardKey.f5): _handleF5Payment,
      const SingleActivator(LogicalKeyboardKey.f8): _handleF8Returns,
      const SingleActivator(LogicalKeyboardKey.f9): _handleF9NewSale,
      const SingleActivator(LogicalKeyboardKey.f10): _handleF10Close,
    };

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF4F6F9),
            body: SafeArea(
              child: Column(
                children: [
                  // 1. شريط الحالة العلوي
                  PosTopStatusBar(
                    controller: _controller,
                    onLogout: widget.onLogout,
                  ),

                  // رسالة خطأ سريعة إن وجدت
                  if (_controller.errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.redAccent.withAlpha(30),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _controller.errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 2. المحتوى الرئيسي المقسم: (يسار: كتالوج وبحث — يمين: سلة ومواد)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // حساب العرض النسبي للسلة بحسب دقة الشاشة
                        double cartWidth = 380;
                        if (constraints.maxWidth >= 2560) {
                          cartWidth = 520;
                        } else if (constraints.maxWidth >= 1920) {
                          cartWidth = 440;
                        } else if (constraints.maxWidth >= 1366) {
                          cartWidth = 400;
                        } else {
                          cartWidth = 340;
                        }

                        return Row(
                          children: [
                            // القسم الأيمن في RTL (كتالوج المنتجات والبحث)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                                child: Column(
                                  children: [
                                    // شريط البحث والباركود
                                    PosSearchBar(
                                      controller: _controller,
                                      focusNode: _searchFocusNode,
                                    ),
                                    const SizedBox(height: 10),

                                    // مصفاة الأقسام
                                    PosCategoryFilter(controller: _controller),
                                    const SizedBox(height: 10),

                                    // شبكة المنتجات
                                    Expanded(
                                      child: PosProductGrid(controller: _controller),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // القسم الأيسر في RTL (سلة المشتريات والعميل)
                            SizedBox(
                              width: cartWidth,
                              child: PosCartPane(controller: _controller),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // 3. شريط الملخص المالي وأزرار الدفع
                  PosTotalSummaryBar(controller: _controller),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
