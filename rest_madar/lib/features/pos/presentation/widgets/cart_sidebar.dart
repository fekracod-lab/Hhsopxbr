import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/pos_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pos_empty_state.dart';
import '../../../../core/localization/pos_language_controller.dart';
import '../../../../services/audit_log_service.dart';
import '../../application/pos_provider.dart';
import 'manager_pin_dialog.dart';
import 'delivery_details_dialog.dart';

/// سلة الكاشير الجانبية التفاعلية (Right Sidebar Cart) — تصميم موحّد
class CartSidebar extends StatelessWidget {
  final VoidCallback onCheckout;
  final double? width;
  final bool isBottomSheet;

  const CartSidebar({
    super.key,
    required this.onCheckout,
    this.width,
    this.isBottomSheet = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PosProvider>(
      builder: (context, pos, _) {
        return Container(
          width: isBottomSheet ? double.infinity : (width ?? 350.0),
          decoration: BoxDecoration(
            color: context.posColors.surface,
            border: isBottomSheet
                ? null
                : Border(
                    right: BorderSide(color: context.posColors.border, width: 1),
                  ),
          ),
          child: Column(
            children: [
              // 1) رأس السلة (مع أزرار التعليق والإلغاء)
              _buildCartHeader(context, pos),

              // 2) قائمة الأصناف
              Expanded(
                child: pos.isCartEmpty
                    ? _buildEmptyState(context)
                    : _buildItemsList(context, pos),
              ),

              // 3) قسم الخصم والخدمة
              if (!pos.isCartEmpty) _buildDiscountSection(context, pos),

              // 4) ملخص الحساب والإجمالي
              _buildTotalSection(context, pos),

              // 5) زر الدفع الرئيسي
              _buildCheckoutButton(context, pos),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartHeader(BuildContext context, PosProvider pos) {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.shopping_cart_rounded,
                      color: c.accent,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEn ? PosLocale.cartTitleEn : PosLocale.cartTitleAr,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: c.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                  if (pos.totalItemCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${pos.totalItemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // زر استعراض الطلبات المعلقة إن وُجدت
                  if (pos.heldOrders.isNotEmpty) ...[
                    Tooltip(
                      message: isEn ? 'Held Orders (${pos.heldOrders.length})' : 'الطلبات المعلقة (${pos.heldOrders.length})',
                      child: InkWell(
                        onTap: () => _showHeldOrdersModal(context, pos),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.gold.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c.gold.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.pause_circle_rounded, color: c.gold, size: 15),
                              const SizedBox(width: 4),
                              Text(
                                '${pos.heldOrders.length}',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  color: c.gold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // زر تعليق الطلب الحالي
                  if (!pos.isCartEmpty) ...[
                    Tooltip(
                      message: isEn ? PosLocale.holdOrderEn : PosLocale.holdOrderAr,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          pos.holdCurrentOrder();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEn ? 'Order held temporarily ⏸️ You can restore it anytime' : 'تم تعليق الطلب مؤقتاً ⏸️ يمكنك استرجاعه بأي وقت',
                                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: c.accent,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c.border),
                          ),
                          child: Icon(
                            Icons.pause_rounded,
                            color: c.accent,
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // زر تفريغ السلة
                  if (!pos.isCartEmpty)
                    InkWell(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        final auth = await ManagerPinDialog.show(
                          context,
                          title: isEn ? 'Cancel current order' : 'إلغاء الطلب الحالي',
                          actionDescription: isEn ? 'Clear cart and cancel all items' : 'تفريغ كامل السلة وإلغاء جميع الأصناف المدخلة',
                          requireReason: true,
                        );
                        if (auth != null && auth.success) {
                          final sub = pos.subtotal;
                          pos.clearCart();
                          await AuditLogService.instance.log(
                            action: AuditLogAction.orderCancelled,
                            targetType: 'cart',
                            targetId: 'cart_current',
                            beforeState: {'subtotal': sub},
                            afterState: 'cleared',
                            reason: auth.reason,
                            managerPinVerified: true,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: c.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.danger.withValues(alpha: 0.3)),
                        ),
                        child: Icon(
                          Icons.delete_sweep_rounded,
                          color: c.danger,
                          size: 17,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // شريط اختيار نوع الطلب
          Row(
            children: [
              _buildOrderTypeChip(context, pos, PosConstants.orderTypeTakeaway, isEn ? PosLocale.takeawayEn : PosLocale.takeawayAr, Icons.shopping_bag_rounded),
              const SizedBox(width: 6),
              _buildOrderTypeChip(context, pos, PosConstants.orderTypeDineIn, isEn ? PosLocale.dineInEn : PosLocale.dineInAr, Icons.table_restaurant_rounded),
              const SizedBox(width: 6),
              _buildOrderTypeChip(context, pos, PosConstants.orderTypeDelivery, isEn ? PosLocale.deliveryEn : PosLocale.deliveryAr, Icons.delivery_dining_rounded),
            ],
          ),

          // محدد الطاولة الذكي عند اختيار صالة
          if (pos.orderType == PosConstants.orderTypeDineIn)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: () => _openTableSelectionDialog(context, pos),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: pos.selectedTableNumber != null
                          ? c.primary
                          : c.border,
                      width: pos.selectedTableNumber != null ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.table_restaurant_rounded,
                        color: pos.selectedTableNumber != null ? c.accent : c.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pos.selectedTableNumber != null && pos.selectedTableNumber!.isNotEmpty
                              ? (isEn ? 'Table #${pos.selectedTableNumber}' : 'طاولة رقم ${pos.selectedTableNumber}')
                              : (isEn ? 'Tap to select dining table' : 'انقر لتحديد الطاولة من الصالة'),
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: pos.selectedTableNumber != null ? c.textPrimary : c.textMuted,
                            fontWeight: pos.selectedTableNumber != null ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (pos.selectedTableNumber != null && pos.selectedTableNumber!.isNotEmpty)
                        InkWell(
                          onTap: () {
                            pos.setSelectedTable(null);
                          },
                          child: Icon(Icons.close_rounded, size: 16, color: c.textMuted),
                        )
                      else
                        Icon(Icons.arrow_drop_down_rounded, color: c.textMuted),
                    ],
                  ),
                ),
              ),
            ),

          // بطاقة بيانات التوصيل الذكية عند اختيار توصيل
          if (pos.orderType == PosConstants.orderTypeDelivery)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildDeliveryDetailsCard(context, pos),
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveryDetailsCard(BuildContext context, PosProvider pos) {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;
    final hasDetails = pos.customerName.isNotEmpty ||
        pos.customerPhone.isNotEmpty ||
        pos.deliveryAddress.isNotEmpty;

    if (hasDetails) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: c.accent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.delivery_dining_rounded,
                  color: c.accent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEn ? 'Delivery Details' : 'بيانات عميل التوصيل',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: c.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => DeliveryDetailsDialog.show(context, pos),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Icon(Icons.edit_rounded, size: 16, color: c.accent),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    pos.setCustomerInfo(name: '', phone: '', address: '', notes: '');
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Icon(Icons.close_rounded, size: 16, color: c.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                if (pos.customerName.isNotEmpty) ...[
                  Icon(Icons.person_outline_rounded, size: 13, color: c.textMuted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      pos.customerName,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (pos.customerPhone.isNotEmpty) ...[
                  Icon(Icons.phone_outlined, size: 13, color: c.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    pos.customerPhone,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: c.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
            if (pos.deliveryAddress.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined, size: 13, color: const Color(0xFFEF4444)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      pos.deliveryAddress,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (pos.orderNotes.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.note_alt_outlined, size: 13, color: c.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      pos.orderNotes,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.textMuted,
                        fontStyle: FontStyle.italic,
                        fontSize: 10.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => DeliveryDetailsDialog.show(context, pos),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFF97316).withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.delivery_dining_rounded,
              color: Color(0xFFF97316),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEn ? 'Add Delivery Details (Required)' : 'تسجيل بيانات التوصيل (مطلوبة)',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: const Color(0xFFF97316),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    isEn ? 'Tap to enter customer name, phone & address' : 'انقر لكتابة الاسم، رقم الهاتف، والعنوان',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: c.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.add_circle_outline_rounded,
              color: Color(0xFFF97316),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTypeChip(
    BuildContext context,
    PosProvider pos,
    String type,
    String label,
    IconData icon,
  ) {
    final c = context.posColors;
    final isSelected = pos.orderType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          pos.setOrderType(type);
          if (type == PosConstants.orderTypeDelivery &&
              (pos.customerName.isEmpty || pos.deliveryAddress.isEmpty)) {
            DeliveryDetailsDialog.show(context, pos);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? c.primary.withValues(alpha: 0.2)
                : c.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? c.primary : c.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? c.accent : c.textDisabled,
                size: 18,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isSelected ? c.textPrimary : c.textMuted,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isEn = PosLanguageController.instance.isEnglish;
    return PosEmptyState(
      icon: Icons.add_shopping_cart_rounded,
      title: isEn ? PosLocale.cartEmptyEn : PosLocale.cartEmptyAr,
      subtitle: isEn ? PosLocale.cartEmptySubtitleEn : PosLocale.cartEmptySubtitleAr,
    );
  }

  Widget _buildItemsList(BuildContext context, PosProvider pos) {
    final c = context.posColors;
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: pos.cartItems.length,
      separatorBuilder: (_, _) => Divider(color: c.border, height: 1),
      itemBuilder: (context, i) {
        final item = pos.cartItems[i];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // تفاصيل الصنف
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.selectedSize != null)
                      Text(
                        item.selectedSize!,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: c.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      Text(
                        '📝 ${item.notes}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: c.warning,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      PosConstants.formatMoney(item.totalPrice),
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // أزرار الكمية (+ / عدد / -)
              Container(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildQtyButton(
                      context,
                      icon: item.quantity > 1
                          ? Icons.remove
                          : Icons.delete_rounded,
                      color:
                          item.quantity > 1 ? c.textPrimary : c.danger,
                      onTap: () async {
                        if (item.quantity > 1) {
                          pos.decrementQuantity(item.id);
                        } else {
                          // عند حذف الصنف بالكامل نطلب موافقة المدير
                          final auth = await ManagerPinDialog.show(
                            context,
                            title: 'حذف وجبة من السلة',
                            actionDescription:
                                'حذف (${item.name}) بقيمة ${PosConstants.formatMoney(item.totalPrice)}',
                            requireReason: true,
                          );
                          if (auth != null && auth.success) {
                            pos.decrementQuantity(item.id);
                            await AuditLogService.instance.log(
                              action: AuditLogAction.itemRemoved,
                              targetType: 'meal',
                              targetId: item.mealId,
                              beforeState: {
                                'name': item.name,
                                'price': item.totalPrice,
                                'qty': item.quantity,
                              },
                              afterState: 'removed',
                              reason: auth.reason,
                              managerPinVerified: true,
                            );
                          }
                        }
                      },
                    ),
                    Container(
                      width: 30,
                      alignment: Alignment.center,
                      child: Text(
                        '${item.quantity}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: c.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    _buildQtyButton(
                      context,
                      icon: Icons.add,
                      color: c.primary,
                      onTap: () => pos.incrementQuantity(item.id),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQtyButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 15.5, color: color),
      ),
    );
  }

  Widget _buildDiscountSection(BuildContext context, PosProvider pos) {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.discount_rounded, color: c.gold, size: 16),
          const SizedBox(width: 6),
          Text(
            isEn ? '${PosLocale.discountEn}:' : '${PosLocale.discountAr}:',
            style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 11.5),
          ),
          const Spacer(),
          SizedBox(
            width: 75,
            height: 32,
            child: TextField(
              keyboardType: TextInputType.number,
              style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                hintStyle:
                    GoogleFonts.ibmPlexSansArabic(color: c.textDisabled, fontSize: 12),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              onChanged: (val) {
                final v = double.tryParse(val) ?? 0;
                pos.setDiscount(pos.discountType, v);
              },
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () {
              pos.setDiscount(
                pos.discountType == 'fixed' ? 'percent' : 'fixed',
                pos.discountValue,
              );
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.border),
              ),
              child: Text(
                pos.discountType == 'percent' ? '%' : (isEn ? 'IQD' : 'د.ع'),
                style: GoogleFonts.ibmPlexSansArabic(
                  color: c.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection(BuildContext context, PosProvider pos) {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEn ? '${PosLocale.subtotalEn}:' : '${PosLocale.subtotalAr}:',
                style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 12),
              ),
              Text(
                PosConstants.formatMoney(pos.subtotal),
                style: GoogleFonts.ibmPlexSansArabic(
                  color: c.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (pos.taxOrService > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEn ? '${PosLocale.taxServiceEn}:' : '${PosLocale.taxServiceAr}:',
                  style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 12),
                ),
                Text(
                  PosConstants.formatMoney(pos.taxOrService),
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: c.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          if (pos.discountAmount > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEn ? '${PosLocale.discountEn}:' : '${PosLocale.discountAr}:',
                  style: GoogleFonts.ibmPlexSansArabic(color: c.danger, fontSize: 12),
                ),
                Text(
                  '- ${PosConstants.formatMoney(pos.discountAmount)}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: c.danger,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEn ? '${PosLocale.totalEn}:' : '${PosLocale.totalAr}:',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: c.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15.5,
                ),
              ),
              Text(
                PosConstants.formatMoney(pos.grandTotal),
                style: GoogleFonts.ibmPlexSansArabic(
                  color: c.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutButton(BuildContext context, PosProvider pos) {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;

    return Container(
      padding: const EdgeInsets.all(12),
      child: ElevatedButton(
        onPressed: pos.isProcessing ? null : onCheckout,
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: pos.isProcessing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.point_of_sale_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${isEn ? PosLocale.checkoutEn : PosLocale.checkoutAr} • ${PosConstants.formatMoney(pos.grandTotal)}',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showHeldOrdersModal(BuildContext context, PosProvider pos) {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;

    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: PosLanguageController.instance.textDirection,
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
              maxWidth: 550,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.pause_circle_rounded, color: c.gold, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          isEn ? 'Held Orders (${pos.heldOrders.length})' : 'الطلبات المعلقة (${pos.heldOrders.length})',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: c.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: pos.heldOrders.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final order = pos.heldOrders[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        order.label,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          color: c.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: c.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isEn ? '${order.items.length} items' : '${order.items.length} أصناف',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            color: c.accent,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    order.items.map((it) => '${it.quantity}x ${it.name}').join(' • '),
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: c.textMuted,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    PosConstants.formatMoney(order.total),
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      color: c.gold,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                pos.restoreHeldOrder(order.id);
                              },
                              icon: const Icon(Icons.play_arrow_rounded, size: 16),
                              label: Text(isEn ? 'Restore' : 'استرجاع', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 11.5)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: c.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: () => pos.removeHeldOrder(order.id),
                              icon: Icon(Icons.delete_outline_rounded, color: c.danger, size: 18),
                              tooltip: isEn ? 'Delete held' : 'حذف المعلق',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openTableSelectionDialog(BuildContext context, PosProvider pos) async {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;
    int tableCount = 12;
    try {
      final prefs = await SharedPreferences.getInstance();
      tableCount = prefs.getInt('pos_tables_count') ?? 12;
    } catch (_) {}

    if (!context.mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final manualCtrl = TextEditingController(text: pos.selectedTableNumber ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: PosLanguageController.instance.textDirection,
          child: StreamBuilder<QuerySnapshot>(
            stream: uid.isNotEmpty
                ? FirebaseFirestore.instance
                    .collection('restaurants')
                    .doc(uid)
                    .collection('tables')
                    .snapshots()
                : null,
            builder: (context, snapshot) {
              final occupied = <String>{};
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['status'] == 'occupied' || data['status'] == 'reserved') {
                    occupied.add(doc.id);
                  }
                }
              }

              return AlertDialog(
                backgroundColor: c.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: c.border),
                ),
                title: Row(
                  children: [
                    Icon(Icons.table_restaurant_rounded, color: c.accent, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      isEn ? 'Select Dining Table' : 'اختيار طاولة الصالة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // إدخال يدوي سريع
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: manualCtrl,
                              decoration: InputDecoration(
                                hintText: isEn ? 'Enter table number or name (e.g. 4 or VIP)' : 'اكتب رقم أو اسم الطاولة (مثلاً 4 أو VIP)',
                                prefixIcon: Icon(Icons.edit_rounded, size: 16, color: c.primary),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (manualCtrl.text.trim().isNotEmpty) {
                                pos.setSelectedTable(manualCtrl.text.trim());
                                Navigator.pop(ctx);
                              }
                            },
                            child: Text(isEn ? PosLocale.confirmEn : 'تأكيد', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isEn ? 'Or select directly from dining hall tables:' : 'أو اختر مباشرة من طاولات الصالة:',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: GridView.builder(
                          shrinkWrap: true,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.1,
                          ),
                          itemCount: tableCount,
                          itemBuilder: (context, i) {
                            final tableNum = '${i + 1}';
                            final isOcc = occupied.contains(tableNum);
                            final isCur = pos.selectedTableNumber == tableNum;

                            return InkWell(
                              onTap: () {
                                pos.setSelectedTable(tableNum);
                                Navigator.pop(ctx);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isCur
                                      ? c.primary.withValues(alpha: 0.25)
                                      : (isOcc
                                          ? c.warning.withValues(alpha: 0.12)
                                          : c.card),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isCur
                                        ? c.accent
                                        : (isOcc ? c.warning : c.border),
                                    width: isCur ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.table_bar_rounded,
                                      color: isCur
                                          ? c.accent
                                          : (isOcc ? c.warning : c.textMuted),
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tableNum,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: c.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      isOcc
                                          ? (isEn ? PosLocale.occupiedEn : PosLocale.occupiedAr)
                                          : (isEn ? PosLocale.vacantEn : PosLocale.vacantAr),
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: isOcc ? c.warning : c.success,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      pos.setSelectedTable(null);
                      Navigator.pop(ctx);
                    },
                    child: Text(isEn ? 'Clear table selection' : 'إلغاء تحديد الطاولة', style: GoogleFonts.ibmPlexSansArabic(color: c.danger)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(isEn ? PosLocale.closeEn : PosLocale.closeAr, style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}