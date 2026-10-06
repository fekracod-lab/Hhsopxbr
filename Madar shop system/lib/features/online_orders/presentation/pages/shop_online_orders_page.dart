import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/store_profile.dart';
import '../../domain/entities/shop_online_order.dart';
import '../../data/services/online_orders_service.dart';

/// صفحة استقبال وإدارة طلبات تطبيق مدار الواردة أونلاين (Online Orders Page)
class ShopOnlineOrdersPage extends StatefulWidget {
  final StoreProfile store;

  const ShopOnlineOrdersPage({super.key, required this.store});

  @override
  State<ShopOnlineOrdersPage> createState() => _ShopOnlineOrdersPageState();
}

class _ShopOnlineOrdersPageState extends State<ShopOnlineOrdersPage> {
  String _selectedFilter = 'all'; // 'all', 'pending', 'accepted', 'ready', 'completed'

  @override
  void initState() {
    super.initState();
    OnlineOrdersService.instance.startListening(widget.store.storeId);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: OnlineOrdersService.instance,
      builder: (context, _) {
        final allOrders = OnlineOrdersService.instance.orders;
        final filtered = allOrders.where((o) {
          if (_selectedFilter == 'all') return true;
          return o.status == _selectedFilter;
        }).toList();

        final pendingCount = allOrders.where((o) => o.isPending).length;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Column(
              children: [
                // ── Top Header ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? ShopColors.darkSurface : Colors.white,
                    border: Border(bottom: BorderSide(color: isDark ? ShopColors.darkBorder : ShopColors.lightBorder)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ShopColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delivery_dining_rounded, color: ShopColors.primary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'طلبات تطبيق مدار الرئيسية الواردة',
                              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              'تصلك طلبات زبائن مدار في الوقت الفعلي مع تحديث فوري للحالة',
                              style: GoogleFonts.cairo(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (pendingCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: ShopColors.warning,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.notifications_active_rounded, color: Colors.black87, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '$pendingCount طلب جديد قيد الانتظار!',
                                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Filter Chips ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  color: isDark ? ShopColors.darkCard : ShopColors.lightBg,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'جميع الطلبات (${allOrders.length})', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('pending', 'قيد الانتظار ($pendingCount)', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('accepted', 'قيد التجهيز', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('ready', 'جاهز للتسليم', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('completed', 'المكتملة', isDark),
                    ],
                  ),
                ),

                // ── Orders List ──
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد طلبات في هذا القسم حالياً',
                                style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (ctx2, i) => const SizedBox(height: 12),
                          itemBuilder: (ctx, idx) => _buildOrderCard(context, filtered[idx], isDark),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String id, String label, bool isDark) {
    final selected = _selectedFilter == id;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.cairo(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      selected: selected,
      selectedColor: ShopColors.primary,
      labelStyle: TextStyle(color: selected ? Colors.white : null),
      onSelected: (_) => setState(() => _selectedFilter = id),
    );
  }

  Widget _buildOrderCard(BuildContext context, ShopOnlineOrder order, bool isDark) {
    Color statusColor;
    String statusText;

    switch (order.status) {
      case 'pending':
        statusColor = ShopColors.warning;
        statusText = 'قيد الانتظار (جديد)';
        break;
      case 'accepted':
        statusColor = ShopColors.info;
        statusText = 'قيد التجهيز في المتجر';
        break;
      case 'ready':
        statusColor = ShopColors.primary;
        statusText = 'جاهز للتسليم / للمندوب';
        break;
      case 'completed':
        statusColor = ShopColors.success;
        statusText = 'تم التسليم بنجاح';
        break;
      case 'cancelled':
        statusColor = ShopColors.danger;
        statusText = 'ملغي';
        break;
      default:
        statusColor = Colors.grey;
        statusText = order.status;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? ShopColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: order.isPending
              ? ShopColors.warning
              : (isDark ? ShopColors.darkBorder : ShopColors.lightBorder),
          width: order.isPending ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Text(
                'طلب #${order.orderId.substring(0, order.orderId.length > 8 ? 8 : order.orderId.length)}',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Customer info
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(order.customerName, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              if (order.customerPhone.isNotEmpty) ...[
                const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(order.customerPhone, style: GoogleFonts.cairo(fontSize: 13, color: Colors.grey)),
              ],
            ],
          ),
          if (order.address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order.address,
                    style: GoogleFonts.cairo(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 20),

          // Items summary
          Text('المواد المطلوبة (${order.items.length}):', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          ...order.items.map((it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('• ${it.name} (×${it.quantity})', style: GoogleFonts.cairo(fontSize: 12)),
                    Text('${it.total.toStringAsFixed(0)} د.ع', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
          const Divider(height: 18),

          // Total & Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('الإجمالي المطلوب: ', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(
                    '${order.total.toStringAsFixed(0)} د.ع',
                    style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w900, color: ShopColors.primary),
                  ),
                ],
              ),
              Row(
                children: [
                  if (order.isPending)
                    ElevatedButton.icon(
                      onPressed: () {
                        OnlineOrdersService.instance.updateOrderStatus(
                          storeId: widget.store.storeId,
                          orderId: order.orderId,
                          newStatus: 'accepted',
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: ShopColors.info),
                      icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                      label: Text('قبول الطلب', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  if (order.isAccepted)
                    ElevatedButton.icon(
                      onPressed: () {
                        OnlineOrdersService.instance.updateOrderStatus(
                          storeId: widget.store.storeId,
                          orderId: order.orderId,
                          newStatus: 'ready',
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: ShopColors.primary),
                      icon: const Icon(Icons.done_all_rounded, size: 16, color: Colors.white),
                      label: Text('جاهز للتسليم', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  if (order.isReady)
                    ElevatedButton.icon(
                      onPressed: () {
                        OnlineOrdersService.instance.updateOrderStatus(
                          storeId: widget.store.storeId,
                          orderId: order.orderId,
                          newStatus: 'completed',
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: ShopColors.success),
                      icon: const Icon(Icons.task_alt_rounded, size: 16, color: Colors.white),
                      label: Text('تم التسليم للزبون/المندوب', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  if (!order.isCompleted && !order.isCancelled) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        OnlineOrdersService.instance.updateOrderStatus(
                          storeId: widget.store.storeId,
                          orderId: order.orderId,
                          newStatus: 'cancelled',
                        );
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: ShopColors.danger),
                      child: Text('إلغاء الطلب', style: GoogleFonts.cairo(fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
