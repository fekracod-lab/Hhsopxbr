import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class RestaurantOffersTab extends StatefulWidget {
  final String restaurantId;

  const RestaurantOffersTab({
    super.key,
    required this.restaurantId,
  });

  @override
  State<RestaurantOffersTab> createState() => _RestaurantOffersTabState();
}

class _RestaurantOffersTabState extends State<RestaurantOffersTab> {
  String _selectedFilter = 'all'; // 'all', 'meal_discount', 'promo_code'
  List<Map<String, dynamic>> _restaurantProducts = [];
  bool _isLoadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurantProducts();
  }

  Future<void> _loadRestaurantProducts() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('merchant_products')
          .doc(widget.restaurantId)
          .collection('products')
          .get();

      if (mounted) {
        setState(() {
          _restaurantProducts = snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();
          _isLoadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  void _showAddOfferOrCouponModal() {
    String offerType = 'meal_discount'; // 'meal_discount' or 'promo_code'

    // Meal discount state
    String? selectedProductId;
    Map<String, dynamic>? selectedProduct;
    final discountPercentCtrl = TextEditingController(text: '20');
    final durationHoursCtrl = TextEditingController(text: '12');
    bool isFlashTimer = true;

    // Promo code state
    final promoCodeCtrl = TextEditingController(
      text: 'MADAR${DateTime.now().millisecondsSinceEpoch % 1000}',
    );
    final promoDiscountCtrl = TextEditingController(text: '15');
    String promoType = 'percent'; // 'percent' or 'fixed'
    final minOrderCtrl = TextEditingController(text: '0');
    final usageLimitCtrl = TextEditingController(text: '50');
    String promoScope = 'all_menu'; // 'all_menu' or 'specific_meal'

    final customTitleCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark ? app_colors.darkCard : Colors.white;
        final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;
        final textSecondary = isDark ? app_colors.darkSubText : app_colors.subTextColor;

        return StatefulBuilder(
          builder: (builderCtx, setModalState) {
            final origPrice = (selectedProduct?['sellingPrice'] ?? selectedProduct?['price'] ?? 0.0) as num;
            final discountVal = double.tryParse(discountPercentCtrl.text) ?? 0.0;
            final priceAfterDiscount = origPrice > 0
                ? (origPrice - (origPrice * (discountVal / 100))).clamp(0, double.infinity)
                : 0.0;

            final currencyFormatter = NumberFormat('#,###', 'ar_IQ');

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(
                    color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle Bar
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: app_colors.goldAccent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.local_offer_rounded, color: app_colors.goldAccent, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'سوي عرض أو كود خصم جديد',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(builderCtx),
                          ),
                        ],
                      ),
                    ),

                    // Offer Type Switch
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFFF0F5F4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setModalState(() => offerType = 'meal_discount'),
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: offerType == 'meal_discount' ? app_colors.primaryColor : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'خصم مباشر على أكلة',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: offerType == 'meal_discount' ? Colors.white : textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: InkWell(
                                onTap: () => setModalState(() => offerType = 'promo_code'),
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: offerType == 'promo_code' ? app_colors.goldAccent : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'كود خصم / كوبون',
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: offerType == 'promo_code' ? Colors.black : textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 16),

                    // Form Fields
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          if (offerType == 'meal_discount') ...[
                            // 1. Direct Meal Discount
                            Text(
                              'اختار الأكلة من قائمة المنيو',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_isLoadingProducts)
                              const Center(child: CircularProgressIndicator(color: app_colors.primaryColor))
                            else if (_restaurantProducts.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  'ماكو أي أكلات مضافة بالمنيو حالياً. ضيف أكلات أولاً حتى تسوي عليها عروض.',
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: Colors.amber.shade900),
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF2F7F6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                child: DropdownButtonFormField<String>(
                                  dropdownColor: cardBg,
                                  initialValue: selectedProductId,
                                  hint: Text(
                                    'اضغط لاختيار الأكلة المراد عمل خصم عليها',
                                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: textSecondary),
                                  ),
                                  decoration: const InputDecoration(border: InputBorder.none),
                                  items: _restaurantProducts.map((prod) {
                                    final pName = prod['name'] ?? 'أكلة';
                                    final pPrice = prod['sellingPrice'] ?? prod['price'] ?? 0;
                                    return DropdownMenuItem<String>(
                                      value: prod['id'].toString(),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.fastfood_rounded, color: app_colors.primaryColor, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            '$pName ($pPrice د.ع)',
                                            style: GoogleFonts.ibmPlexSansArabic(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setModalState(() {
                                      selectedProductId = val;
                                      selectedProduct = _restaurantProducts.firstWhere(
                                        (p) => p['id'].toString() == val,
                                        orElse: () => {},
                                      );
                                    });
                                  },
                                ),
                              ),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: discountPercentCtrl,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.ibmPlexSansArabic(color: textPrimary, fontWeight: FontWeight.bold),
                                    onChanged: (v) => setModalState(() {}),
                                    decoration: InputDecoration(
                                      labelText: 'نسبة الخصم %',
                                      hintText: 'مثال: 20',
                                      labelStyle: GoogleFonts.ibmPlexSansArabic(color: textSecondary, fontSize: 12),
                                      prefixIcon: const Icon(Icons.percent_rounded, color: app_colors.primaryColor, size: 18),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: durationHoursCtrl,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.ibmPlexSansArabic(color: textPrimary, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      labelText: 'مدة العرض (بالساعات)',
                                      hintText: 'مثال: 12',
                                      labelStyle: GoogleFonts.ibmPlexSansArabic(color: textSecondary, fontSize: 12),
                                      prefixIcon: const Icon(Icons.timer_rounded, color: app_colors.goldAccent, size: 18),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (selectedProduct != null)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: app_colors.primaryColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: app_colors.primaryColor.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        Text('السعر الأصلي', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: textSecondary)),
                                        Text(
                                          '${currencyFormatter.format(origPrice.toInt())} د.ع',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.lineThrough,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Icon(Icons.arrow_back_rounded, color: app_colors.primaryColor, size: 18),
                                    Column(
                                      children: [
                                        Text('السعر بعد الخصم', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: app_colors.primaryColor, fontWeight: FontWeight.bold)),
                                        Text(
                                          '${currencyFormatter.format(priceAfterDiscount.toInt())} د.ع',
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: app_colors.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),

                            TextField(
                              controller: customTitleCtrl,
                              style: GoogleFonts.ibmPlexSansArabic(color: textPrimary),
                              decoration: InputDecoration(
                                labelText: 'عنوان أو شعار العرض (اختياري)',
                                hintText: 'مثال: وجبة اليوم المميزة بخصم حارق',
                                labelStyle: GoogleFonts.ibmPlexSansArabic(color: textSecondary, fontSize: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 10),

                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              activeThumbColor: app_colors.goldAccent,
                              activeTrackColor: app_colors.goldAccent.withValues(alpha: 0.3),
                              value: isFlashTimer,
                              onChanged: (v) => setModalState(() => isFlashTimer = v),
                              title: Text(
                                'تفعيل كـ فلاش تايمر تنازلي',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold, color: textPrimary),
                              ),
                              subtitle: Text(
                                'يظهر للزبون عداد تنازلي بالدقائق والثواني لحثه على الطلب فوراً',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: textSecondary),
                              ),
                            ),
                          ] else ...[
                            // 2. Promo Code / Voucher
                            TextField(
                              controller: promoCodeCtrl,
                              textCapitalization: TextCapitalization.characters,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: textPrimary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                labelText: 'رمز كود الخصم (Promo Code)',
                                hintText: 'مثال: BAGHDAD20',
                                labelStyle: GoogleFonts.ibmPlexSansArabic(color: textSecondary, fontSize: 12),
                                prefixIcon: const Icon(Icons.confirmation_number_rounded, color: app_colors.goldAccent),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: promoDiscountCtrl,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.ibmPlexSansArabic(color: textPrimary, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      labelText: promoType == 'percent' ? 'نسبة الخصم %' : 'مبلغ الخصم (د.ع)',
                                      hintText: promoType == 'percent' ? 'مثال: 15' : 'مثال: 2000',
                                      labelStyle: GoogleFonts.ibmPlexSansArabic(color: textSecondary, fontSize: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF2F7F6),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        dropdownColor: cardBg,
                                        value: promoType,
                                        items: [
                                          DropdownMenuItem(
                                            value: 'percent',
                                            child: Text('نسبة %', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                                          ),
                                          DropdownMenuItem(
                                            value: 'fixed',
                                            child: Text('د.ع ثابت', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                                          ),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) setModalState(() => promoType = v);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Text('نطاق تطبيق الكوبون', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold, color: textPrimary)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setModalState(() => promoScope = 'all_menu'),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: promoScope == 'all_menu'
                                            ? app_colors.goldAccent.withValues(alpha: 0.15)
                                            : (isDark ? Colors.black26 : const Color(0xFFF2F7F6)),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: promoScope == 'all_menu' ? app_colors.goldAccent : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'كل المنيو',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: promoScope == 'all_menu' ? app_colors.goldAccent : textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => setModalState(() => promoScope = 'specific_meal'),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: promoScope == 'specific_meal'
                                            ? app_colors.goldAccent.withValues(alpha: 0.15)
                                            : (isDark ? Colors.black26 : const Color(0xFFF2F7F6)),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: promoScope == 'specific_meal' ? app_colors.goldAccent : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'أكلة محددة',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: promoScope == 'specific_meal' ? app_colors.goldAccent : textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (promoScope == 'specific_meal') ...[
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF2F7F6),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                child: DropdownButtonFormField<String>(
                                  dropdownColor: cardBg,
                                  initialValue: selectedProductId,
                                  hint: Text('اختار الأكلة المشمولة بالكود', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: textSecondary)),
                                  decoration: const InputDecoration(border: InputBorder.none),
                                  items: _restaurantProducts.map((prod) {
                                    return DropdownMenuItem<String>(
                                      value: prod['id'].toString(),
                                      child: Text(
                                        (prod['name'] ?? 'أكلة').toString(),
                                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: textPrimary, fontWeight: FontWeight.bold),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (v) {
                                    setModalState(() {
                                      selectedProductId = v;
                                      selectedProduct = _restaurantProducts.firstWhere(
                                        (p) => p['id'].toString() == v,
                                        orElse: () => {},
                                      );
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: minOrderCtrl,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.ibmPlexSansArabic(color: textPrimary, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      labelText: 'أقل قيمة للطلبية (د.ع)',
                                      hintText: 'مثال: 10000',
                                      labelStyle: GoogleFonts.ibmPlexSansArabic(color: textSecondary, fontSize: 11),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: usageLimitCtrl,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.ibmPlexSansArabic(color: textPrimary, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      labelText: 'أقصى عدد استخدامات',
                                      hintText: 'مثال: 50',
                                      labelStyle: GoogleFonts.ibmPlexSansArabic(color: textSecondary, fontSize: 11),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 24),

                          // Submit Action Button
                          ElevatedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              HapticFeedback.heavyImpact();

                              if (offerType == 'meal_discount') {
                                if (selectedProduct == null) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('يرجى اختيار أكلة لعمل الخصم عليها', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                                      backgroundColor: Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                final dVal = double.tryParse(discountPercentCtrl.text) ?? 20.0;
                                final dHours = int.tryParse(durationHoursCtrl.text) ?? 12;
                                final endMs = DateTime.now().add(Duration(hours: dHours)).millisecondsSinceEpoch;

                                final offerData = <String, dynamic>{
                                  'type': 'meal_discount',
                                  'title': customTitleCtrl.text.trim().isNotEmpty
                                      ? customTitleCtrl.text.trim()
                                      : 'خصم خاص على ${(selectedProduct?['name'] ?? 'الوجبة')}',
                                  'productId': selectedProductId,
                                  'productName': selectedProduct?['name'] ?? '',
                                  'productImage': selectedProduct?['imageUrl'] ?? '',
                                  'originalPrice': origPrice,
                                  'discountPercent': dVal,
                                  'priceAfterDiscount': priceAfterDiscount,
                                  'isFlash': isFlashTimer,
                                  'endTime': endMs,
                                  'isActive': true,
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'restaurantId': widget.restaurantId,
                                };

                                await FirebaseFirestore.instance
                                    .collection('merchant_offers')
                                    .doc(widget.restaurantId)
                                    .collection('offers')
                                    .add(offerData);

                                try {
                                  await FirebaseFirestore.instance.collection('offers').add(offerData);
                                } catch (_) {}
                              } else {
                                final code = promoCodeCtrl.text.trim().toUpperCase();
                                if (code.isEmpty) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('اكتب رمز كود الخصم أولاً', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                                      backgroundColor: Colors.redAccent,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                final discAmount = double.tryParse(promoDiscountCtrl.text) ?? 10.0;
                                final minOrd = double.tryParse(minOrderCtrl.text) ?? 0.0;
                                final maxUsg = int.tryParse(usageLimitCtrl.text) ?? 50;

                                final couponData = <String, dynamic>{
                                  'type': 'promo_code',
                                  'code': code,
                                  'discountType': promoType,
                                  'discountValue': discAmount,
                                  'scope': promoScope,
                                  'productId': promoScope == 'specific_meal' ? selectedProductId : null,
                                  'productName': promoScope == 'specific_meal' && selectedProduct != null ? selectedProduct!['name'] : null,
                                  'minOrder': minOrd,
                                  'maxUsage': maxUsg,
                                  'usedCount': 0,
                                  'isActive': true,
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'restaurantId': widget.restaurantId,
                                };

                                await FirebaseFirestore.instance
                                    .collection('merchant_offers')
                                    .doc(widget.restaurantId)
                                    .collection('offers')
                                    .add(couponData);

                                try {
                                  await FirebaseFirestore.instance.collection('coupons').doc(code).set(couponData, SetOptions(merge: true));
                                } catch (_) {}
                              }

                              if (builderCtx.mounted) Navigator.pop(builderCtx);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    offerType == 'meal_discount' ? 'تم تفعيل خصم الأكلة بنجاح وعاشت إيدك!' : 'تم إنشاء كود الخصم ونشره للزبائن بنجاح!',
                                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  backgroundColor: Colors.green.shade700,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            },
                            icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                            label: Text(
                              offerType == 'meal_discount' ? 'نشر وتفعيل خصم الأكلة' : 'إنشاء وتفعيل كود الخصم',
                              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: offerType == 'meal_discount' ? app_colors.primaryColor : app_colors.goldAccent,
                              foregroundColor: offerType == 'meal_discount' ? Colors.white : Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 2,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? app_colors.darkCard : Colors.white;
    final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;
    final textSecondary = isDark ? app_colors.darkSubText : app_colors.subTextColor;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('merchant_offers')
          .doc(widget.restaurantId)
          .collection('offers')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: app_colors.primaryColor),
          );
        }

        final allDocs = snapshot.data!.docs;
        final filteredDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final type = data['type'] ?? (data['code'] != null ? 'promo_code' : 'meal_discount');
          if (_selectedFilter == 'meal_discount') return type == 'meal_discount';
          if (_selectedFilter == 'promo_code') return type == 'promo_code';
          return true;
        }).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          children: [
            const SizedBox(height: 10),

            // 1. Hero Promotional Header Banner
            _buildOffersHeroBanner(),
            const SizedBox(height: 14),

            // 2. Filter Capsule Bar
            Row(
              children: [
                _buildFilterChip('all', 'كل العروض والكوبونات (${allDocs.length})', isDark, textPrimary),
                const SizedBox(width: 8),
                _buildFilterChip('meal_discount', 'خصومات الأكلات', isDark, textPrimary),
                const SizedBox(width: 8),
                _buildFilterChip('promo_code', 'كودات الخصم', isDark, textPrimary),
              ],
            ),
            const SizedBox(height: 14),

            // 3. Offers List or Empty State
            if (filteredDocs.isEmpty)
              _buildEmptyOffersState(cardBg, textPrimary, textSecondary, isDark)
            else
              ...filteredDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final type = data['type'] ?? (data['code'] != null ? 'promo_code' : 'meal_discount');

                if (type == 'promo_code') {
                  return _buildCouponCard(doc.id, data, cardBg, textPrimary, textSecondary, isDark);
                } else {
                  return _buildMealDiscountCard(doc.id, data, cardBg, textPrimary, textSecondary, isDark);
                }
              }),

            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark, Color textPrimary) {
    final isSelected = _selectedFilter == key;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedFilter = key);
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? app_colors.primaryColor
                : (isDark ? app_colors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? app_colors.primaryColor
                  : (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: app_colors.primaryColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildOffersHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00796B), app_colors.primaryColor],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: app_colors.primaryColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt_rounded, color: app_colors.goldAccent, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'العروض وكوبونات الخصم',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'سوّي خصومات على أكلاتك أو طلع كودات ترويجية لزبائنك',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showAddOfferOrCouponModal();
            },
            icon: const Icon(Icons.add_circle_rounded, color: Colors.black, size: 20),
            label: Text(
              'سوي عرض أو كود خصم جديد',
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
                color: Colors.black,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: app_colors.goldAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              minimumSize: const Size.fromHeight(46),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOffersState(Color cardBg, Color textPrimary, Color textSecondary, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.4),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: app_colors.goldAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_offer_outlined, size: 48, color: app_colors.goldAccent),
            ),
            const SizedBox(height: 14),
            Text(
              'ماكو أي عروض أو كودات حالياً',
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'دوس على زر (سوي عرض جديد) فوگ وابدي سوّي عروض تفرح الزبائن وتزيد الطلبيات!',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12,
                color: textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealDiscountCard(
    String docId,
    Map<String, dynamic> data,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final title = data['title'] ?? 'خصم على وجبة';
    final pName = data['productName'] ?? '';
    final pImage = data['productImage'] ?? '';
    final origPrice = (data['originalPrice'] ?? 0) as num;
    final priceAfter = (data['priceAfterDiscount'] ?? 0) as num;
    final discountPercent = data['discountPercent'] ?? 0;
    final isFlash = data['isFlash'] ?? false;
    final endTimeMs = data['endTime'] as int?;
    final isActive = data['isActive'] ?? true;

    final currencyFormatter = NumberFormat('#,###', 'ar_IQ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isFlash
              ? app_colors.goldAccent.withValues(alpha: 0.5)
              : (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.6),
          width: isFlash ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isFlash
                ? app_colors.goldAccent.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal Image Thumbnail with Discount Badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 78,
                    height: 78,
                    color: app_colors.primaryColor.withValues(alpha: 0.08),
                    child: pImage.toString().isNotEmpty
                        ? Image.network(
                            pImage.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(Icons.fastfood_rounded, color: app_colors.primaryColor, size: 30),
                          )
                        : const Icon(Icons.fastfood_rounded, color: app_colors.primaryColor, size: 30),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '-$discountPercent%',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.toString(),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFlash)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: app_colors.goldAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'فلاش',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (pName.toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'الأكلة: $pName',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),

                  // Pricing row
                  Row(
                    children: [
                      Text(
                        '${currencyFormatter.format(origPrice.toInt())} د.ع',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          color: textSecondary.withValues(alpha: 0.7),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${currencyFormatter.format(priceAfter.toInt())} د.ع',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: app_colors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Live Timer if Flash
                  if (isFlash && endTimeMs != null)
                    _FlashCountdown(
                      endTimeMs: endTimeMs,
                      onFinished: () => _deleteOffer(docId),
                    ),
                  const SizedBox(height: 6),

                  // Actions
                  Row(
                    children: [
                      Text(
                        isActive ? 'فعال' : 'موقوف',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.green.shade600 : Colors.redAccent,
                        ),
                      ),
                      Transform.scale(
                        scale: 0.65,
                        child: Switch.adaptive(
                          activeThumbColor: app_colors.primaryColor,
                          value: isActive,
                          onChanged: (val) {
                            FirebaseFirestore.instance
                                .collection('merchant_offers')
                                .doc(widget.restaurantId)
                                .collection('offers')
                                .doc(docId)
                                .update({'isActive': val});
                          },
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        tooltip: 'حذف العرض',
                        onPressed: () => _showDeleteDialog(docId, title.toString()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponCard(
    String docId,
    Map<String, dynamic> data,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    final code = data['code'] ?? 'COUPON';
    final discType = data['discountType'] ?? 'percent';
    final discVal = data['discountValue'] ?? 0;
    final scope = data['scope'] ?? 'all_menu';
    final prodName = data['productName'];
    final minOrd = data['minOrder'] ?? 0;
    final maxUsg = data['maxUsage'] ?? 50;
    final usedCount = data['usedCount'] ?? 0;
    final isActive = data['isActive'] ?? true;

    final discLabel = discType == 'percent' ? '$discVal%' : '$discVal د.ع';
    final scopeLabel = scope == 'specific_meal' ? 'خاص بوجبة: $prodName' : 'شامل كل المنيو';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: app_colors.goldAccent.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: app_colors.goldAccent.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                // Coupon Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: app_colors.goldAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.confirmation_number_rounded, color: app_colors.goldAccent, size: 24),
                ),
                const SizedBox(width: 12),

                // Code and Discount
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withValues(alpha: 0.4) : const Color(0xFFF2F7F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: app_colors.goldAccent.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              code.toString(),
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: app_colors.goldAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.copy_rounded, size: 16, color: app_colors.primaryColor),
                            tooltip: 'نسخ الكود',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code.toString()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تم نسخ كود الخصم: $code', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'قيمة الخصم: $discLabel • $scopeLabel',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'مفعّل' : 'معطّل',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.green.shade700 : Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),

            // Usage & Actions Row
            Row(
              children: [
                Text(
                  'مرات الاستخدام: $usedCount من $maxUsg',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: textSecondary),
                ),
                if (minOrd > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• حد أدنى: $minOrd د.ع',
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: textSecondary),
                  ),
                ],
                const Spacer(),
                Transform.scale(
                  scale: 0.65,
                  child: Switch.adaptive(
                    activeThumbColor: app_colors.goldAccent,
                    value: isActive,
                    onChanged: (val) {
                      FirebaseFirestore.instance
                          .collection('merchant_offers')
                          .doc(widget.restaurantId)
                          .collection('offers')
                          .doc(docId)
                          .update({'isActive': val});
                    },
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  tooltip: 'حذف الكوبون',
                  onPressed: () => _showDeleteDialog(docId, 'كود $code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(String docId, String title) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark ? app_colors.darkCard : Colors.white;
        final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;

        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text('حذف العرض', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary)),
            ],
          ),
          content: Text(
            'متأكد تريد تحذف "$title"؟',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: isDark ? app_colors.darkSubText : app_colors.subTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('لا، رجوع', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _deleteOffer(docId);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text('اي، احذفه', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteOffer(String docId) async {
    await FirebaseFirestore.instance
        .collection('merchant_offers')
        .doc(widget.restaurantId)
        .collection('offers')
        .doc(docId)
        .delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف العرض بنجاح', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

class _FlashCountdown extends StatefulWidget {
  final int endTimeMs;
  final VoidCallback onFinished;

  const _FlashCountdown({
    required this.endTimeMs,
    required this.onFinished,
  });

  @override
  State<_FlashCountdown> createState() => _FlashCountdownState();
}

class _FlashCountdownState extends State<_FlashCountdown> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = widget.endTimeMs - now;

    if (diff <= 0) {
      if (mounted) {
        setState(() => _remaining = Duration.zero);
        widget.onFinished();
      }
      _timer.cancel();
    } else {
      if (mounted) {
        setState(() => _remaining = Duration(milliseconds: diff));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = _remaining.inHours.toString().padLeft(2, '0');
    final minutes = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: app_colors.goldAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: app_colors.goldAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.alarm_rounded, color: app_colors.goldAccent, size: 14),
          const SizedBox(width: 4),
          Text(
            'باقي $hours:$minutes:$seconds',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade900,
            ),
          ),
        ],
      ),
    );
  }
}
