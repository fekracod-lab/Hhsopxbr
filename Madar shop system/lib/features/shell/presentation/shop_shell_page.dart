import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/entities/store_profile.dart';
import '../../auth/data/services/store_auth_service.dart';
import '../../pos/application/pos_controller.dart';
import '../../pos/presentation/pages/shop_pos_page.dart';
import '../../products/presentation/pages/shop_products_page.dart';
import '../../online_orders/presentation/pages/shop_online_orders_page.dart';
import '../../online_orders/data/services/online_orders_service.dart';
import '../../shifts/presentation/pages/shift_page.dart';
import '../../shifts/data/services/shift_service.dart';

/// الهيكل التكيفي العام لنظام كاشير مدار على سطح المكتب والأجهزة اللوحية (Shop Desktop/Tablet Shell)
class ShopShellPage extends StatefulWidget {
  final StoreProfile store;
  final VoidCallback onSwitchStore;

  const ShopShellPage({
    super.key,
    required this.store,
    required this.onSwitchStore,
  });

  @override
  State<ShopShellPage> createState() => _ShopShellPageState();
}

class _ShopShellPageState extends State<ShopShellPage> {
  int _currentIndex = 0;
  late final PosController _posController;

  @override
  void initState() {
    super.initState();
    _posController = PosController();
    _posController.bindStore(widget.store);
    OnlineOrdersService.instance.startListening(widget.store.storeId);
  }

  @override
  void didUpdateWidget(covariant ShopShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store.storeId != widget.store.storeId) {
      _posController.bindStore(widget.store);
      OnlineOrdersService.instance.startListening(widget.store.storeId);
    }
  }

  @override
  void dispose() {
    _posController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Row(
          children: [
            // ── Sidebar Rail ──
            Container(
              width: 250,
              decoration: BoxDecoration(
                color: isDark ? ShopColors.darkSurface : Colors.white,
                border: Border(left: BorderSide(color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Store Profile Header ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [ShopColors.primary, ShopColors.primaryDark]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.store.name,
                                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(color: ShopColors.success, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'متصل بمدار أونلاين',
                                    style: GoogleFonts.cairo(fontSize: 10, color: ShopColors.success, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Navigation Items ──
                  const SizedBox(height: 12),
                  _buildNavItem(0, 'نقطة البيع (POS)', Icons.point_of_sale_rounded, isDark),
                  _buildNavItem(1, 'المنتجات والمخزون', Icons.inventory_2_rounded, isDark),
                  ListenableBuilder(
                    listenable: OnlineOrdersService.instance,
                    builder: (context, _) {
                      final count = OnlineOrdersService.instance.pendingOrdersCount;
                      return _buildNavItem(2, 'طلبات مدار أونلاين', Icons.delivery_dining_rounded, isDark, count);
                    },
                  ),
                  _buildNavItem(3, 'الوردية والصندوق', Icons.account_balance_wallet_rounded, isDark),

                  const Spacer(),

                  // ── Shift Status Indicator ──
                  ListenableBuilder(
                    listenable: ShiftService.instance,
                    builder: (context, _) {
                      final hasShift = ShiftService.instance.hasActiveShift;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: (hasShift ? ShopColors.success : ShopColors.warning).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: (hasShift ? ShopColors.success : ShopColors.warning).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(hasShift ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 16, color: hasShift ? ShopColors.success : ShopColors.warning),
                            const SizedBox(width: 8),
                            Text(
                              hasShift ? 'الوردية مفتوحة' : 'الوردية مغلقة',
                              style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: hasShift ? ShopColors.success : ShopColors.warning),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // ── Bottom Controls ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
                          tooltip: 'تغيير المظهر (فاتح/داكن)',
                          onPressed: () => ShopThemeController.instance.toggleTheme(),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            StoreAuthService.instance.clearActiveStore();
                            widget.onSwitchStore();
                          },
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: Text('تبديل المتجر', style: GoogleFonts.cairo(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Main Content Area ──
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  ShopPosPage(controller: _posController),
                  ShopProductsPage(store: widget.store),
                  ShopOnlineOrdersPage(store: widget.store),
                  ShiftPage(store: widget.store),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon, bool isDark, [int badge = 0]) {
    final selected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? ShopColors.primary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? ShopColors.primary.withValues(alpha: 0.5) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? ShopColors.primary : (isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    color: selected ? ShopColors.primary : (isDark ? ShopColors.darkText : ShopColors.lightText),
                  ),
                ),
              ),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: ShopColors.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: GoogleFonts.cairo(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
