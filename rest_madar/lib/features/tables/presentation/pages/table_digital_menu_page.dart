import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/pos_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_icon_helper.dart';

/// شاشة المنيو الإلكتروني الذكي للطاولة (كما يراها الزبون عند مسح رمز QR أو فتح الرابط)
class TableDigitalMenuPage extends StatefulWidget {
  final String restaurantId;
  final String tableNumber;
  final String? restaurantName;

  const TableDigitalMenuPage({
    super.key,
    required this.restaurantId,
    required this.tableNumber,
    this.restaurantName,
  });

  @override
  State<TableDigitalMenuPage> createState() => _TableDigitalMenuPageState();
}

class _TableDigitalMenuPageState extends State<TableDigitalMenuPage> {
  String _selectedCategory = 'الكل';
  String _searchQuery = '';
  String _restaurantDisplayName = 'مطعم مدار';
  String? _logoUrl;
  bool _isEnglish = false;

  // سلة طلبات الطاولة المحلية
  final List<Map<String, dynamic>> _cartItems = [];

  double get _subtotal => _cartItems.fold(
      0.0, (accum, item) => accum + ((item['totalPrice'] ?? item['price'] ?? 0) as num).toDouble());

  int get _totalCount =>
      _cartItems.fold(0, (accum, item) => accum + ((item['quantity'] ?? 1) as num).toInt());

  @override
  void initState() {
    super.initState();
    _fetchRestaurantDetails();
  }

  Future<void> _fetchRestaurantDetails() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.restaurantId).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _restaurantDisplayName =
              data?['restaurantName'] ?? data?['fullName'] ?? widget.restaurantName ?? 'مطعم مدار';
          _logoUrl = data?['photoUrl'] ?? data?['imageUrl'];
        });
      }
    } catch (_) {}
  }

  String _translateCategory(String cat) {
    if (!_isEnglish) return cat;
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isEnglish ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B131E),
        body: SafeArea(
          child: Column(
            children: [
              // رأس المنيو وبيانات الطاولة
              _buildHeader(),

              // شريط البحث
              _buildSearchBar(),

              // شريط الأقسام والأيقونات
              _buildCategoriesBar(),

              // شبكة الوجبات
              Expanded(child: _buildMealsGrid()),

              // شريط السلة العائم في الأسفل عند وجود عناصر
              if (_cartItems.isNotEmpty) _buildBottomCartBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFF131D2A),
        border: Border(bottom: BorderSide(color: Color(0xFF223247))),
      ),
      child: Row(
        children: [
          // زر الرجوع إلى شاشة إدارة الطاولات
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: _isEnglish ? 'Back' : 'رجوع',
            icon: Icon(
              _isEnglish ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: PosTheme.cardDark,
              border: Border.all(color: PosTheme.primary, width: 1.8),
            ),
            child: _logoUrl != null && _logoUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(23),
                    child: Image.network(_logoUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.restaurant, color: PosTheme.accent)),
                  )
                : const Icon(Icons.restaurant_rounded, color: PosTheme.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _restaurantDisplayName,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _isEnglish ? 'Dine-In Digital Table Menu' : 'منيو الطلب المباشر من الصالة',
                  style: GoogleFonts.ibmPlexSansArabic(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),

          // زر تبديل اللغة السريع للزبون (عربي / English)
          InkWell(
            onTap: () => setState(() => _isEnglish = !_isEnglish),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2D40),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PosTheme.primary.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded, size: 14, color: PosTheme.accent),
                  const SizedBox(width: 4),
                  Text(
                    _isEnglish ? 'عربي' : 'EN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // أزرار الخدمة الذكية للطاولة
          IconButton(
            onPressed: _callWaiter,
            tooltip: _isEnglish ? 'Call Waiter' : 'استدعاء الويتر',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: const Icon(Icons.room_service_rounded, color: Color(0xFFF59E0B), size: 16),
            ),
          ),
          IconButton(
            onPressed: _showRequestBillDialog,
            tooltip: _isEnglish ? 'Request Bill' : 'طلب الحساب',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981), size: 16),
            ),
          ),
          const SizedBox(width: 4),

          // شارة رقم الطاولة البارزة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: PosTheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PosTheme.primary),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.table_restaurant_rounded, color: PosTheme.accent, size: 18),
                const SizedBox(width: 6),
                Text(
                  _isEnglish ? 'Table ${widget.tableNumber}' : 'طاولة ${widget.tableNumber}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: PosTheme.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _callWaiter() async {
    try {
      await FirebaseFirestore.instance
          .collection('merchants')
          .doc(widget.restaurantId)
          .collection('table_calls')
          .add({
        'type': 'call_waiter',
        'tableNumber': widget.tableNumber,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isEnglish
                        ? 'Waiter call sent for Table ${widget.tableNumber} - Staff will arrive shortly 🛎️'
                        : 'تم إرسال طلب استدعاء الويتر لطاولة ${widget.tableNumber} - سيصلك المباشر حالاً 🛎️',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF162334),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  void _showRequestBillDialog() {
    String paymentMethod = 'كاش';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Directionality(
          textDirection: _isEnglish ? TextDirection.ltr : TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF162334),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: PosTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isEnglish
                        ? 'Request Bill for Table ${widget.tableNumber}'
                        : 'طلب الحساب لطاولة ${widget.tableNumber}',
                    style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEnglish
                      ? 'Select your preferred payment method:'
                      : 'اختر وسيلة الدفع المفضلة لإحضارها إليك:',
                  style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.payments_rounded, color: Color(0xFF10B981)),
                  title: Text(_isEnglish ? 'Cash' : 'الدفع كاش (نقدي)', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  trailing: paymentMethod == 'كاش' ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)) : null,
                  onTap: () => setSt(() => paymentMethod = 'كاش'),
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF3B82F6)),
                  title: Text(_isEnglish ? 'ZainCash' : 'زين كاش (ZainCash)', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  trailing: paymentMethod == 'زين كاش' ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)) : null,
                  onTap: () => setSt(() => paymentMethod = 'زين كاش'),
                ),
                ListTile(
                  leading: const Icon(Icons.credit_card_rounded, color: Color(0xFFF59E0B)),
                  title: Text(_isEnglish ? 'Qi Card / Master (POS Device)' : 'كي كارد / ماستر (جهاز POS)', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  trailing: paymentMethod == 'كي كارد' ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)) : null,
                  onTap: () => setSt(() => paymentMethod = 'كي كارد'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(_isEnglish ? 'Cancel' : 'إلغاء', style: const TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await FirebaseFirestore.instance
                      .collection('merchants')
                      .doc(widget.restaurantId)
                      .collection('table_calls')
                      .add({
                    'type': 'request_bill',
                    'tableNumber': widget.tableNumber,
                    'paymentMethod': paymentMethod,
                    'status': 'pending',
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _isEnglish
                              ? 'Cashier notified to bring bill for Table ${widget.tableNumber} ($paymentMethod) 🧾'
                              : 'تم إشعار الكاشير بإحضار فاتورة طاولة ${widget.tableNumber} ($paymentMethod) 🧾',
                          style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: PosTheme.primary),
                child: Text(_isEnglish ? 'Send Bill Request 🧾' : 'إرسال طلب الحساب 🧾', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: SizedBox(
        height: 42,
        child: TextField(
          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
          style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: _isEnglish ? 'Search meals or drinks...' : 'ابحث عن وجبة أو مشروب...',
            hintStyle: GoogleFonts.ibmPlexSansArabic(color: Colors.white38, fontSize: 12),
            prefixIcon: const Icon(Icons.search_rounded, color: PosTheme.primary, size: 20),
            filled: true,
            fillColor: const Color(0xFF162334),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('restaurants').doc(widget.restaurantId).snapshots(),
        builder: (context, snapshot) {
          final List<String> cats = ['الكل'];
          if (snapshot.hasData && snapshot.data?.data() != null) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            if (data['categories'] is List) {
              for (var c in data['categories']) {
                final str = c.toString().trim();
                if (str.isNotEmpty && !cats.contains(str)) cats.add(str);
              }
            }
          }

          if (cats.length == 1) {
            cats.addAll(['وجبات رئيسية', 'برجر', 'بيتزا', 'شاورما', 'مشاوي', 'دجاج', 'مقبلات', 'مشروبات', 'حلويات']);
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cats.length,
            separatorBuilder: (c, i) => const SizedBox(width: 8),
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
                      color: isSelected ? PosTheme.primary : const Color(0xFF162334),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? PosTheme.primary : const Color(0xFF223247)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 15, color: isSelected ? Colors.white : color),
                        const SizedBox(width: 6),
                        Text(
                          _isEnglish ? _translateCategory(cat) : cat,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
    );
  }

  Widget _buildMealsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('merchant_products')
          .doc(widget.restaurantId)
          .collection('products')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: PosTheme.primary));
        }

        final docs = snapshot.data?.docs ?? [];
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isAvailable = data['isAvailable'] ?? true;
          if (!isAvailable) return false;

          final name = (data['name'] ?? data['title'] ?? '').toString().toLowerCase();
          final category = (data['category'] ?? '').toString();
          final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery);
          final matchesCat = _selectedCategory == 'الكل' || category == _selectedCategory;
          return matchesSearch && matchesCat;
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.restaurant_menu_rounded, color: Colors.white24, size: 56),
                const SizedBox(height: 12),
                Text(
                  _isEnglish
                      ? 'No meals currently available in this section'
                      : 'لا توجد وجبات متاحة حالياً في هذا القسم',
                  style: GoogleFonts.ibmPlexSansArabic(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 650;
            return GridView.builder(
              padding: const EdgeInsets.all(14),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: isWide ? 260 : 200,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.76,
              ),
              itemCount: filteredDocs.length,
              itemBuilder: (context, i) {
                final doc = filteredDocs[i];
                final data = doc.data() as Map<String, dynamic>;
                return _buildCustomerMealCard(doc.id, data);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCustomerMealCard(String mealId, Map<String, dynamic> data) {
    final name = (data['name'] ?? data['title'] ?? (_isEnglish ? 'Meal' : 'وجبة')).toString();
    final price = (data['price'] ?? data['sellingPrice'] ?? 0).toDouble();
    final imageUrl = (data['imageUrl'] ?? data['photoUrl'] ?? '').toString();
    final category = (data['category'] ?? '').toString();
    final hasOptions = (data['sizes'] is List && (data['sizes'] as List).isNotEmpty) ||
        (data['addons'] is List && (data['addons'] as List).isNotEmpty);

    final catIcon = CategoryIconHelper.getIconForCategory(category);
    final catColor = CategoryIconHelper.getColorForCategory(category);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131D2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF223247)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // صورة الوجبة
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => _buildFallback(catIcon, catColor),
                        )
                      : _buildFallback(catIcon, catColor),
                  if (category.isNotEmpty)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(catIcon, size: 11, color: catColor),
                            const SizedBox(width: 4),
                            Text(
                              _isEnglish ? _translateCategory(category) : category,
                              style: const TextStyle(color: Colors.white, fontSize: 9.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // بيانات الوجبة وزر الإضافة
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          PosConstants.formatMoney(price),
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: PosTheme.gold,
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _addMealToCart(mealId, data, hasOptions),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PosTheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            hasOptions
                                ? (_isEnglish ? 'Options' : 'خيارات')
                                : (_isEnglish ? 'Add' : 'أضف'),
                            style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback(IconData icon, Color color) {
    return Container(
      color: const Color(0xFF1A2636),
      child: Center(child: Icon(icon, color: color.withValues(alpha: 0.6), size: 36)),
    );
  }

  void _addMealToCart(String mealId, Map<String, dynamic> data, bool hasOptions) {
    HapticFeedback.lightImpact();
    if (hasOptions) {
      _showMealOptionsModal(mealId, data);
    } else {
      setState(() {
        final existingIndex = _cartItems.indexWhere((it) => it['mealId'] == mealId);
        if (existingIndex >= 0) {
          _cartItems[existingIndex]['quantity'] += 1;
          _cartItems[existingIndex]['totalPrice'] =
              _cartItems[existingIndex]['unitPrice'] * _cartItems[existingIndex]['quantity'];
        } else {
          final price = (data['price'] ?? data['sellingPrice'] ?? 0).toDouble();
          _cartItems.add({
            'mealId': mealId,
            'name': data['name'] ?? data['title'] ?? 'وجبة',
            'unitPrice': price,
            'quantity': 1,
            'totalPrice': price,
            'selectedSize': '',
            'selectedAddons': [],
            'notes': '',
          });
        }
      });
    }
  }

  void _showMealOptionsModal(String mealId, Map<String, dynamic> data) {
    final sizes = List<Map<String, dynamic>>.from(data['sizes'] ?? []);
    final addons = List<Map<String, dynamic>>.from(data['addons'] ?? []);
    final basePrice = (data['price'] ?? data['sellingPrice'] ?? 0).toDouble();

    String? selectedSizeName = sizes.isNotEmpty ? sizes.first['name'] : null;
    double currentPrice = sizes.isNotEmpty ? (sizes.first['price'] ?? basePrice).toDouble() : basePrice;
    final List<Map<String, dynamic>> selectedAddons = [];
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131D2A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: _isEnglish ? TextDirection.ltr : TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data['name'] ?? (_isEnglish ? 'Customize Meal' : 'تخصيص الوجبة'),
                          style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // اختيار الحجم
                    if (sizes.isNotEmpty) ...[
                      Text(
                        _isEnglish ? 'Select Size:' : 'اختر الحجم:',
                        style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: sizes.map((s) {
                          final isSelected = selectedSizeName == s['name'];
                          final sPrice = (s['price'] ?? basePrice).toDouble();
                          return ChoiceChip(
                            label: Text('${s['name']} (${PosConstants.formatMoney(sPrice)})'),
                            selected: isSelected,
                            selectedColor: PosTheme.primary,
                            backgroundColor: const Color(0xFF1F2D3D),
                            labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 11),
                            onSelected: (_) {
                              setModalState(() {
                                selectedSizeName = s['name'];
                                currentPrice = sPrice;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // اختيار الإضافات
                    if (addons.isNotEmpty) ...[
                      Text(
                        _isEnglish ? 'Add-ons:' : 'الإضافات:',
                        style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      ...addons.map((a) {
                        final aName = a['name'];
                        final aPrice = (a['price'] ?? 0).toDouble();
                        final isChecked = selectedAddons.any((it) => it['name'] == aName);

                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: PosTheme.primary,
                          title: Text('$aName (+${PosConstants.formatMoney(aPrice)})', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          value: isChecked,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selectedAddons.add(a);
                              } else {
                                selectedAddons.removeWhere((it) => it['name'] == aName);
                              }
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 10),
                    ],

                    // ملاحظات خاصة
                    TextField(
                      controller: notesCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: _isEnglish
                            ? 'Special instructions (e.g. no onions, extra sauce...)'
                            : 'ملاحظات خاصة (مثلاً: بدون بصل، زيادة صوص...)',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                        filled: true,
                        fillColor: const Color(0xFF1A2636),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: () {
                        double totalItem = currentPrice;
                        for (var ad in selectedAddons) {
                          totalItem += (ad['price'] ?? 0).toDouble();
                        }
                        setState(() {
                          _cartItems.add({
                            'mealId': mealId,
                            'name': data['name'] ?? (_isEnglish ? 'Meal' : 'وجبة'),
                            'unitPrice': totalItem,
                            'quantity': 1,
                            'totalPrice': totalItem,
                            'selectedSize': selectedSizeName ?? '',
                            'selectedAddons': selectedAddons,
                            'notes': notesCtrl.text.trim(),
                          });
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PosTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        _isEnglish ? 'Add to Order' : 'إضافة للطلب',
                        style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold),
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

  Widget _buildBottomCartBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2A),
        border: const Border(top: BorderSide(color: Color(0xFF223247))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isEnglish ? '$_totalCount items selected' : '$_totalCount وجبات مختارة',
                style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 11),
              ),
              Text(
                PosConstants.formatMoney(_subtotal),
                style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.gold, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _showOrderConfirmationModal,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _isEnglish ? 'Confirm & Send to Kitchen 🚀' : 'تأكيد وإرسال للمطبخ 🚀',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: PosTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderConfirmationModal() {
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: _isEnglish ? TextDirection.ltr : TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFF131D2A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFF223247)),
                ),
                title: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: PosTheme.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isEnglish
                            ? 'Confirm Table ${widget.tableNumber} Order'
                            : 'تأكيد طلب طاولة ${widget.tableNumber}',
                        style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: PosTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: PosTheme.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.table_restaurant_rounded, color: PosTheme.accent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isEnglish
                                    ? 'Order will be sent directly to Table #${widget.tableNumber}'
                                    : 'سيتم إرسال الطلب مباشرة لطاولة رقم ${widget.tableNumber}',
                                style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.accent, fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // الأصناف
                      Text(
                        _isEnglish ? 'Selected Items (${_cartItems.length}):' : 'الأصناف المطلوبة (${_cartItems.length}):',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      ..._cartItems.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item['name']} × ${item['quantity']}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                              Text(PosConstants.formatMoney(item['totalPrice']), style: const TextStyle(color: PosTheme.gold, fontSize: 12)),
                            ],
                          ),
                        );
                      }),
                      const Divider(color: Color(0xFF223247), height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isEnglish ? 'Grand Total:' : 'المجموع الإجمالي:',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(PosConstants.formatMoney(_subtotal), style: const TextStyle(color: PosTheme.gold, fontWeight: FontWeight.w900, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // اسم الزبون
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: _isEnglish ? 'Your Name (optional)' : 'اسمك (اختياري)',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF162334),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ملاحظات للمطبخ
                      TextField(
                        controller: notesCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: _isEnglish ? 'Special notes for kitchen or cashier...' : 'ملاحظات خاصة للمطبخ أو الكاشير...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF162334),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                    child: Text(_isEnglish ? 'Back' : 'رجوع', style: const TextStyle(color: Colors.white60)),
                  ),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setDialogState(() => isSubmitting = true);
                            await _submitDineInOrder(nameCtrl.text.trim(), notesCtrl.text.trim());
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              _showOrderSuccessDialog();
                            }
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: PosTheme.primary),
                    child: isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isEnglish ? 'Send Order 🚀' : 'إرسال الطلب 🚀', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitDineInOrder(String customerName, String notes) async {
    try {
      final defaultCustName = _isEnglish ? 'Table ${widget.tableNumber} Guest' : 'زبون طاولة ${widget.tableNumber}';
      final orderData = {
        'restaurantId': widget.restaurantId,
        'restaurantName': _restaurantDisplayName,
        'orderType': 'dine_in',
        'tableNumber': widget.tableNumber,
        'customerName': customerName.isNotEmpty ? customerName : defaultCustName,
        'notes': notes,
        'items': _cartItems,
        'subtotal': _subtotal,
        'total': _subtotal,
        'totalPrice': _subtotal,
        'status': 'pending',
        'source': 'table_qr_menu',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // إضافة الطلب في Firestore
      final ref = await FirebaseFirestore.instance.collection('orders').add(orderData);
      await ref.update({'orderId': ref.id});

      // تحديث حالة الطاولة في المطعم إلى "مشغولة"
      FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .collection('tables')
          .doc(widget.tableNumber)
          .set({
        'tableNumber': widget.tableNumber,
        'status': 'occupied',
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _cartItems.clear();
      });
    } catch (e) {
      debugPrint('Error submitting dine-in order: $e');
    }
  }

  void _showOrderSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: _isEnglish ? TextDirection.ltr : TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF131D2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: PosTheme.success, size: 64),
              const SizedBox(height: 14),
              Text(
                _isEnglish ? 'Order Placed Successfully! 🍽️' : 'تم إرسال طلبك بنجاح! 🍽️',
                style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _isEnglish
                    ? 'Your order is now being received in the kitchen for Table #${widget.tableNumber}. Food will be prepared immediately.'
                    : 'طلبك الآن قيد الاستلام في المطبخ لطاولة رقم ${widget.tableNumber}. سيتم تحضير طعامك وطباعة الفاتورة فوراً.',
                style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: PosTheme.primary),
                child: Text(_isEnglish ? 'OK' : 'حسناً', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
