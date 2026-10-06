import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/pos_constants.dart';
import '../../../../core/error/madar_crash_guard.dart';
import '../../../../core/localization/pos_language_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/design_system/madar_design_system.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../../../core/widgets/pos_empty_state.dart';
import '../../../../core/widgets/pos_page_header.dart';
import '../../../../core/widgets/pos_search_field.dart';
import '../../../../services/audit_log_service.dart';
import '../../../../services/print_queue_service.dart';
import '../../../../services/thermal_printer_service.dart';
import '../../../../services/offline_auth_service.dart';
import '../../../menu/presentation/widgets/category_manager_dialog.dart';
import '../../application/pos_provider.dart';
import '../widgets/meal_grid_card.dart';
import '../widgets/cart_sidebar.dart';
import '../widgets/item_customization_modal.dart';
import '../widgets/manager_pin_dialog.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/delivery_details_dialog.dart';
import '../widgets/print_queue_indicator_bar.dart';
import '../widgets/quick_add_meal_dialog.dart';

/// شاشة الكاشير الرئيسية: شبكة الوجبات + السلة الجانبية + الدفع
class PosMainPage extends StatefulWidget {
  const PosMainPage({super.key});

  @override
  State<PosMainPage> createState() => _PosMainPageState();
}

class _PosMainPageState extends State<PosMainPage> {
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? OfflineAuthService.instance.currentUid;
  String _effectiveRestaurantId = '';
  String _selectedCategory = 'الكل';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _resolveRestaurantId();
  }

  Future<void> _resolveRestaurantId() async {
    final uid = _uid;
    if (uid.isEmpty) return;
    _effectiveRestaurantId = uid;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data()?['restaurantId'] != null) {
        final rId = doc.data()!['restaurantId'].toString().trim();
        if (rId.isNotEmpty && mounted) {
          setState(() => _effectiveRestaurantId = rId);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isTabletPortrait = MadarResponsive.isTabletPortrait(context);
    final isMobile = MadarResponsive.isMobile(context);
    final isNarrow = isTabletPortrait || isMobile;

    return ListenableBuilder(
      listenable: PosLanguageController.instance,
      builder: (context, _) {
        final isEn = PosLanguageController.instance.isEnglish;
        final cartWidget = !isNarrow
            ? CartSidebar(
                width: MadarResponsive.widthOf(context) >= 1200 ? 350 : 310,
                onCheckout: () => _openPaymentDialog(context),
              )
            : null;

        final mainContent = Expanded(
          child: Column(
            children: [
              // شريط تنبيه طابور الطباعة (يظهر فقط عند وجود فواتير فشلت)
              const PrintQueueIndicatorBar(),

              // الشريط العلوي الموحّد (العنوان + الإجراءات + البحث)
              _buildTopBar(),

              // شريط الأقسام مع الأيقونات
              _buildCategoriesBar(),

              // شبكة الوجبات
              Expanded(child: _buildMealsGrid()),
            ],
          ),
        );

        return Directionality(
          textDirection: PosLanguageController.instance.textDirection,
          child: Scaffold(
            backgroundColor: context.posColors.background,
            bottomNavigationBar: isNarrow ? _buildNarrowBottomCartBar(context) : null,
            body: Row(
              children: [
                // In RTL, the first child is on the right.
                // In LTR, the last child is on the right.
                // Anchoring the cart on the right edge gives a consistent POS layout.
                if (!isEn && cartWidget != null) cartWidget,
                mainContent,
                if (isEn && cartWidget != null) cartWidget,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNarrowBottomCartBar(BuildContext context) {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;

    return Consumer<PosProvider>(
      builder: (context, pos, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // عدد الأصناف والإجمالي
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 16, color: c.primary),
                        const SizedBox(width: 6),
                        Text(
                          pos.isCartEmpty
                              ? (isEn ? 'Cart is empty' : 'السلة فارغة')
                              : (isEn ? 'Cart (${pos.cartItems.length} items)' : 'السلة (${pos.cartItems.length} أصناف)'),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: c.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      PosConstants.formatMoney(pos.grandTotal),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: c.primary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // زر عرض السلة والدفع
                ElevatedButton.icon(
                  onPressed: () => _openCartBottomSheet(context),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                  label: Text(
                    pos.isCartEmpty
                        ? (isEn ? 'Preview Cart' : 'معاينة السلة')
                        : (isEn ? 'View Cart / Checkout' : 'عرض السلة / الدفع'),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    minimumSize: const Size(120, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openCartBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.sizeOf(context).height * 0.85,
          decoration: BoxDecoration(
            color: context.posColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: CartSidebar(
              isBottomSheet: true,
              onCheckout: () {
                Navigator.of(ctx).pop();
                _openPaymentDialog(context);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;

    return PosPageHeader(
      icon: Icons.point_of_sale_rounded,
      title: isEn ? PosLocale.posTerminalEn : PosLocale.posTerminalAr,
      subtitle: isEn ? PosLocale.posSubtitleEn : PosLocale.posSubtitleAr,
      actions: [
        // زر فتح درج النقد (محمي برمز المدير وموثق في سجل التدقيق)
        OutlinedButton.icon(
          onPressed: _openCashDrawer,
          icon: Icon(Icons.archive_outlined, size: 16, color: c.gold),
          label: Text(
            isEn ? PosLocale.openDrawerEn : PosLocale.openDrawerAr,
            style: GoogleFonts.ibmPlexSansArabic(
              color: c.gold,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: c.gold.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 8),

        // زر إضافة وجبة جديدة
        ElevatedButton.icon(
          onPressed: () => QuickAddMealDialog.show(
            context,
            onMealSaved: () {
              if (mounted) setState(() => _selectedCategory = 'الكل');
            },
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(
            isEn ? PosLocale.addMealEn : PosLocale.addMealAr,
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 11.5),
          ),
        ),
        const SizedBox(width: 12),

        // حقل البحث السريع
        PosSearchField(
          width: 240,
          hintText: isEn ? PosLocale.searchMealsHintEn : PosLocale.searchMealsHintAr,
          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
        ),
      ],
    );
  }

  String _translateCategory(String cat, bool isEn) {
    if (!isEn) return cat;
    switch (cat.trim()) {
      case 'الكل':
        return 'All';
      case 'وجبات رئيسية':
        return 'Main Courses';
      case 'برجر':
        return 'Burgers';
      case 'بيتزا':
        return 'Pizza';
      case 'شاورما':
        return 'Shawarma';
      case 'مشاوي':
        return 'Grills';
      case 'دجاج':
        return 'Chicken';
      case 'مقبلات':
        return 'Appetizers';
      case 'مشروبات':
        return 'Beverages';
      case 'حلويات':
        return 'Desserts';
      case 'ساندوتشات':
        return 'Sandwiches';
      case 'وجبات سريعة':
        return 'Fast Food';
      default:
        return cat;
    }
  }

  Future<void> _openCashDrawer() async {
    final isEn = PosLanguageController.instance.isEnglish;
    final auth = await ManagerPinDialog.show(
      context,
      title: isEn ? 'Open Cash Drawer' : 'فتح درج الكاشير',
      actionDescription: isEn ? 'Manual cash drawer open without sale' : 'فتح درج النقد يدوياً بدون عملية بيع',
      requireReason: true,
    );
    if (auth != null && auth.success) {
      await ThermalPrinterService.kickCashDrawer();
      await AuditLogService.instance.log(
        action: AuditLogAction.cashDrawerManualOpen,
        targetType: 'cash_drawer',
        targetId: 'drawer_manual',
        beforeState: 'closed',
        afterState: 'opened',
        reason: auth.reason,
        managerPinVerified: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn ? 'Cash drawer opened and logged to audit' : 'تم فتح درج الكاشير وتوثيق العملية في سجل التدقيق'),
            backgroundColor: context.posColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildCategoriesBar() {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;
    final targetId = _effectiveRestaurantId.isNotEmpty
        ? _effectiveRestaurantId
        : (FirebaseAuth.instance.currentUser?.uid ?? _uid);

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          // زر إدارة الأقسام
          IconButton(
            onPressed: () => CategoryManagerDialog.show(
              context,
              onUpdated: () => setState(() {}),
            ),
            icon: Icon(Icons.tune_rounded, color: c.textMuted, size: 20),
            tooltip: isEn ? 'Manage Categories' : 'إدارة وتخصيص الأقسام',
          ),
          const SizedBox(width: 8),

          // قائمة الأقسام من المطعم
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('restaurants')
                  .doc(targetId)
                  .snapshots(),
              builder: (context, restSnap) {
                final List<String> cats = ['الكل'];
                if (restSnap.hasData && restSnap.data?.data() != null) {
                  final data = restSnap.data!.data() as Map<String, dynamic>;
                  if (data['categories'] is List) {
                    for (var x in data['categories']) {
                      final str = x.toString().trim();
                      if (str.isNotEmpty && !cats.contains(str)) cats.add(str);
                    }
                  }
                }

                // أقسام افتراضية أساسية إذا كانت القائمة فارغة
                if (cats.length == 1) {
                  cats.addAll(['وجبات رئيسية', 'برجر', 'بيتزا', 'شاورما', 'مشاوي', 'دجاج', 'مقبلات', 'مشروبات', 'حلويات']);
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final cat = cats[i];
                    final isSelected = _selectedCategory == cat;
                    final icon = CategoryIconHelper.getIconForCategory(cat);
                    final color = CategoryIconHelper.getColorForCategory(cat);

                    return Center(
                      child: InkWell(
                        onTap: () => setState(() => _selectedCategory = cat),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? c.primary.withValues(alpha: 0.22)
                                : c.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? c.primary : c.border,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 16,
                                color: isSelected ? c.accent : color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _translateCategory(cat, isEn),
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color:
                                      isSelected ? c.textPrimary : c.textMuted,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealsGrid() {
    final c = context.posColors;
    final activeId = _effectiveRestaurantId.isNotEmpty
        ? _effectiveRestaurantId
        : (FirebaseAuth.instance.currentUser?.uid ?? _uid);

    if (activeId.isEmpty) {
      return PosEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'يرجى تسجيل الدخول',
        subtitle: 'سجّل الدخول بحساب المطعم لعرض الوجبات والبدء بالبيع',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('merchant_products')
          .doc(activeId)
          .collection('products')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: c.primary,
              strokeWidth: 3,
            ),
          );
        }

        if (snapshot.hasError) {
          final info = MadarCrashGuard.analyzeError(snapshot.error);
          return Center(
            child: MadarInlineErrorCard(
              errorInfo: info,
              onRetry: () => setState(() {}),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? data['title'] ?? '').toString().toLowerCase();
          final category = (data['category'] ?? '').toString().trim();
          final matchesSearch =
              _searchQuery.isEmpty || name.contains(_searchQuery);
          final matchesCategory =
              _selectedCategory == 'الكل' || category == _selectedCategory.trim();
          return matchesSearch && matchesCategory;
        }).toList();

        if (filteredDocs.isEmpty) {
          return PosEmptyState(
            icon: CategoryIconHelper.getIconForCategory(_selectedCategory),
            title: _searchQuery.isNotEmpty
                ? 'لا توجد نتائج عن "$_searchQuery"'
                : 'لا توجد وجبات في قسم "$_selectedCategory"',
            subtitle: _selectedCategory != 'الكل'
                ? 'انقر أدناه لعرض جميع الوجبات أو أضف وجبة جديدة'
                : 'أضف وجبة جديدة أو غيّر القسم للاستمرار',
            action: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (_selectedCategory != 'الكل')
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _selectedCategory = 'الكل'),
                    icon: const Icon(Icons.apps_rounded, size: 16),
                    label: Text(
                      'عرض جميع الوجبات (الكل)',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: () => QuickAddMealDialog.show(
                    context,
                    onMealSaved: () {
                      if (mounted) setState(() => _selectedCategory = 'الكل');
                    },
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    'إضافة وجبة الآن',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 224,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.78,
          ),
          itemCount: filteredDocs.length,
          itemBuilder: (context, i) {
            final data = filteredDocs[i].data() as Map<String, dynamic>;
            final mealId = filteredDocs[i].id;

            return MealGridCard(
              mealData: data,
              onToggleAvailability: () async {
                final currentAvail = data['isAvailable'] != false &&
                    data['available'] != false &&
                    data['inStock'] != false;
                final newAvail = !currentAvail;
                try {
                  await FirebaseFirestore.instance
                      .collection('merchant_products')
                      .doc(activeId)
                      .collection('products')
                      .doc(mealId)
                      .update({
                    'isAvailable': newAvail,
                    'available': newAvail,
                    'inStock': newAvail,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          newAvail
                              ? 'تمت إعادة إتاحة وجبة "${data['name'] ?? 'الوجبة'}" للزبائن ✓'
                              : 'تم تسجيل نفاد كمية "${data['name'] ?? 'الوجبة'}" اليوم (86\'d) 🚫',
                          style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: newAvail ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تعذر تحديث حالة الوجبة: $e')),
                    );
                  }
                }
              },
              onQuickAdd: () {
                HapticFeedback.lightImpact();
                final pos = context.read<PosProvider>();
                pos.addToCart(
                  mealId: mealId,
                  name: data['name'] ?? 'وجبة',
                  unitPrice: (data['price'] ?? 0).toDouble(),
                  imageUrl: data['imageUrl'] ?? data['photoUrl'],
                );
              },
              onCustomize: () {
                ItemCustomizationModal.show(
                  context,
                  mealData: data,
                  onConfirm: ({
                    required double finalPrice,
                    String? selectedSize,
                    required List<Map<String, dynamic>> selectedAddons,
                    String? notes,
                  }) {
                    final pos = context.read<PosProvider>();
                    pos.addToCart(
                      mealId: mealId,
                      name: data['name'] ?? 'وجبة',
                      unitPrice: finalPrice,
                      selectedSize: selectedSize,
                      selectedAddons: selectedAddons,
                      notes: notes,
                      imageUrl: data['imageUrl'] ?? data['photoUrl'],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _openPaymentDialog(BuildContext context) async {
    final pos = context.read<PosProvider>();
    if (pos.isCartEmpty) return;

    // التحقق الإلزامي من بيانات التوصيل إذا كان نوع الطلب توصيل
    if (pos.orderType == PosConstants.orderTypeDelivery) {
      if (pos.customerName.trim().isEmpty || pos.customerPhone.trim().isEmpty || pos.deliveryAddress.trim().isEmpty) {
        final saved = await DeliveryDetailsDialog.show(context, pos);
        if (saved != true) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تنبيه: يجب تسجيل بيانات التوصيل (الاسم، الهاتف، العنوان) لإتمام الطلب'),
                backgroundColor: Color(0xFFEF4444),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
    }

    if (!context.mounted) return;

    PaymentDialog.show(
      context,
      grandTotal: pos.grandTotal,
      orderType: pos.orderType,
      customerName: pos.customerName,
      customerPhone: pos.customerPhone,
      deliveryAddress: pos.deliveryAddress,
      onConfirmPayment: ({
        required String paymentMethod,
        required double amountPaid,
        required bool printReceipt,
        required bool printKitchenTicket,
      }) async {
        final order = await pos.checkout(
          paymentMethod: paymentMethod,
          amountPaid: amountPaid,
        );

        if (order != null && context.mounted) {
          final messenger = ScaffoldMessenger.of(context);
          final primaryColor = context.posColors.primary;
          messenger.showSnackBar(
            SnackBar(
              content: Text('تم إتمام الطلب #${order.orderId} وحفظه محلياً بنجاح!'),
              backgroundColor: primaryColor,
              duration: const Duration(seconds: 2),
            ),
          );

          if (printReceipt) {
            // إرسال الفاتورة عبر طابور الطباعة المتين (Print Queue State Machine)
            PrintQueueService.instance.enqueueAndPrint(
              order: order,
              isKitchenTicket: printKitchenTicket,
            );
          }
        }
      },
    );
  }
}