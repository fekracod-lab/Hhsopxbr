import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'restaurants_page.dart';
import 'user_info_page.dart';

// --- Palette Configuration ---
const Color primaryColor = Color(0xFF26A69A);
const Color accentColor = Color(0xFF00796B);
const Color backgroundColor = Color(0xFFFFFFFF);
const Color textColor = Color(0xFF333333);
const Color subTextColor = Color(0xFF757575);
const Color surfaceColor = Color(0xFFF8F9FA);

// --- Dark Mode Palette ---
const Color darkBackground = Color(0xFF07191A);
const Color darkSurface = Color(0xFF0F2323);
const Color darkCard = Color(0xFF113033);
const Color darkText = Color(0xFFE0F2F1);
const Color darkSubText = Color(0xFF80CBC4);
const Color darkHint = Color(0xFF4DB6AC);

class CartPage extends StatefulWidget {
  final String? userName;
  final String? userPhone;
  final String? userAddress;
  final String? userNotes;
  final String? locationType;
  final double deliveryFee;
  final String? selectedRegion;

  const CartPage({
    super.key,
    this.userName,
    this.userPhone,
    this.userAddress,
    this.userNotes,
    this.locationType,
    this.deliveryFee = 0.0,
    this.selectedRegion,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  // Cart items synced with Firestore
  List<Map<String, dynamic>> _cartItems = [];
  String? _uid;
  StreamSubscription<QuerySnapshot>? _cartSub;
  // الحساب المباشر للمجموع
  double get total => _cartItems.fold(
    0.0,
    (double acc, item) => acc + ((item['price'] ?? 0.0) * (item['quantity'] ?? 0)),
  );

  double get grandTotal => total + widget.deliveryFee;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    if (_uid != null) {
      _subscribeToCart();
      _repairCartDocs();
    }
  }



  @override
  void dispose() {
    _cartSub?.cancel();
    super.dispose();
  }

  void _subscribeToCart() {
    final cartId = GroupCartManager.getEffectiveCartId(_uid!);
    final col = FirebaseFirestore.instance.collection('carts').doc(cartId).collection('items');
    _cartSub = col.snapshots().listen((snap) {
      final items =
          snap.docs.map((d) {
            final data = d.data();
            return {
              'docId': d.id,
              'id': data['itemId'] ?? d.id,
              'name': data['name'] ?? '',
              'restaurant': data['restaurant'] ?? '',
              'price': (data['price'] ?? 0).toDouble(),
              'quantity': (data['quantity'] ?? 1),
              'image': data['imageUrl'] ?? data['image'] ?? '',
              'restaurantId': data['restaurantId'] ?? data['restaurant'],
              'addedByName': data['addedByName'] ?? '',
              'size': data['size'] ?? '',
              'options': data['options'] ?? '',
              'notes': data['notes'] ?? '',
            };
          }).toList();
      if (mounted) {
        setState(() {
          _cartItems = items;
        });
      }
    });
  }

  Future<void> _repairCartDocs() async {
    if (_uid == null) return;
    try {
      final cartId = GroupCartManager.getEffectiveCartId(_uid!);
      final col = FirebaseFirestore.instance.collection('carts').doc(cartId).collection('items');
      final snap = await col.get();
      for (final d in snap.docs) {
        final data = d.data();
        final existing = (data['restaurantId'] ?? data['restaurant'])?.toString();
        if (existing != null && existing.isNotEmpty) continue;
        // Logic for older items if needed
      }
    } catch (e) {
      debugPrint('repairCartDocs failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentBg = isDark ? darkBackground : backgroundColor;

    return Scaffold(
      backgroundColor: currentBg,
      appBar: AppBar(
        backgroundColor: currentBg,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildFrostedCircleButton(
            Icons.chevron_right_rounded,
            isDark,
            onTap: () => Navigator.pop(context),
          ),
        ),
        title: Column(
          children: [
            Text(
              _cartItems.isNotEmpty
                  ? (_cartItems.first['restaurant'] ?? 'سلة المشتريات')
                  : 'سلة المشتريات',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? darkSubText : subTextColor,
              ),
            ),
            Text(
              'مراجعة الطلب',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? darkText : textColor,
              ),
            ),
          ],
        ),
        actions: [
          if (_cartItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildFrostedCircleButton(
                Icons.delete_outline_rounded,
                isDark,
                onTap: () => _clearCart(),
                iconColor: Colors.redAccent,
              ),
            ),
        ],
      ),
      body: _cartItems.isEmpty ? _buildEmptyCart(isDark) : _buildMainContent(isDark),
      bottomNavigationBar: _cartItems.isNotEmpty ? _buildBottomSection(isDark) : null,
    );
  }

  Widget _buildFrostedCircleButton(
    IconData icon,
    bool isDark, {
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withAlpha((0.15 * 255).round()),
          shape: BoxShape.circle,
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withAlpha((0.1 * 255).round()),
            width: 0.5,
          ),
        ),
        child: Icon(icon, color: iconColor ?? (isDark ? Colors.white : textColor), size: 24),
      ),
    );
  }

  Widget _buildMainContent(bool isDark) {
    return Column(
      children: [
        if (GroupCartManager.groupCartId != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: primaryColor.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withAlpha((0.2 * 255).round())),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded, color: primaryColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'أنت متصل بسلة جماعية مستضافة بواسطة: ${GroupCartManager.groupHostName ?? "صديق"}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? darkSubText : accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: AnimationLimiter(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: _cartItems.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 600),
                  child: SlideAnimation(
                    verticalOffset: 30.0,
                    child: FadeInAnimation(child: _buildCartCard(_cartItems[index], isDark)),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartCard(Map<String, dynamic> item, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? darkCard : Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((isDark ? 0.3 : 0.04).round() * 255),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 80,
                height: 80,
                color: isDark ? darkSurface : surfaceColor,
                child:
                    item['image'].toString().isNotEmpty
                        ? Image.network(item['image'], fit: BoxFit.cover)
                        : Icon(
                          Icons.fastfood_rounded,
                          color: primaryColor.withAlpha((0.3 * 255).round()),
                        ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? darkText : textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item['addedByName'] != null && item['addedByName'].toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '(أضافه ${item['addedByName']})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? darkSubText : subTextColor,
                      ),
                    ),
                  ],
                  if ((item['size'] != null && item['size'].toString().isNotEmpty) ||
                      (item['options'] != null && item['options'].toString().isNotEmpty)) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "${item['size'] != '' ? item['size'] : ''} ${item['options'] != '' ? '• ${item['options']}' : ''}".trim(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                  if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      "ملاحظة: ${item['notes']}",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
                        color: isDark ? darkSubText : subTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${(item['price'] * item['quantity']).toStringAsFixed(0)} د.ع',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                _buildSubtleDeleteBtn(() => _removeItem(item), isDark),
                const SizedBox(height: 10),
                _buildModernQuantitySelector(item, isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtleDeleteBtn(VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha((0.05 * 255).round()),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 18),
      ),
    );
  }

  Widget _buildModernQuantitySelector(Map<String, dynamic> item, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? darkSurface : surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQtyCircleBtn(Icons.add_rounded, () => _updateQuantity(item, 1), true, isDark),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${item['quantity']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? darkText : textColor,
              ),
            ),
          ),
          _buildQtyCircleBtn(
            Icons.remove_rounded,
            () => _updateQuantity(item, -1),
            false,
            isDark,
            disabled: item['quantity'] <= 1,
          ),
        ],
      ),
    );
  }

  Widget _buildQtyCircleBtn(
    IconData icon,
    VoidCallback onTap,
    bool isPrimary,
    bool isDark, {
    bool disabled = false,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color:
              isPrimary
                  ? primaryColor
                  : (isDark ? darkCard.withAlpha((0.5 * 255).round()) : Colors.white),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 14,
          color:
              disabled ? Colors.grey : (isPrimary ? Colors.white : (isDark ? darkText : textColor)),
        ),
      ),
    );
  }

  Widget _buildBottomSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((isDark ? 0.5 : 0.08).round() * 255),
            blurRadius: 25,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummaryRow('المجموع الفرعي', '${total.toStringAsFixed(0)} د.ع', isDark),
          const SizedBox(height: 12),
          _buildSummaryRow('الضريبة (0%)', '0 د.ع', isDark),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'رسوم التوصيل${widget.selectedRegion != null ?' (${widget.selectedRegion})' : ''}',
            '${widget.deliveryFee.toStringAsFixed(0)} د.ع',
            isDark,
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'المجموع الكلي',
            '${grandTotal.toStringAsFixed(0)} د.ع',
            isDark,
            isTotal: true,
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withAlpha((0.3 * 255).round()),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  if (_cartItems.isEmpty) return;
                  final firstItem = _cartItems.first;
                  final restaurantId = (firstItem['restaurantId'] ?? firstItem['restaurant'])?.toString() ?? '';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserInfoPage(
                        restaurantId: restaurantId,
                        cartItems: _cartItems,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: const Text(
                  'المتابعة لتأكيد الطلب',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isTotal ? primaryColor : (isDark ? darkText : textColor),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isDark ? darkSubText : subTextColor,
          ),
        ),
      ],
    );
  }

  Future<void> _updateQuantity(Map<String, dynamic> item, int delta) async {
    final current = (item['quantity'] ?? 1) as int;
    final next = current + delta;
    if (next < 1) return;
    if (_uid != null && item['docId'] != null) {
      final cartId = GroupCartManager.getEffectiveCartId(_uid!);
      final docRef = FirebaseFirestore.instance
          .collection('carts')
          .doc(cartId)
          .collection('items')
          .doc(item['docId']);
      await docRef.update({'quantity': next});
    } else {
      setState(() {
        item['quantity'] = next;
      });
    }
  }

  Future<void> _removeItem(Map<String, dynamic> item) async {
    if (_uid != null && item['docId'] != null) {
      final cartId = GroupCartManager.getEffectiveCartId(_uid!);
      final docRef = FirebaseFirestore.instance
          .collection('carts')
          .doc(cartId)
          .collection('items')
          .doc(item['docId']);
      await docRef.delete();
    } else {
      setState(() {
        _cartItems.removeWhere((e) => e['id'] == item['id']);
      });
    }
  }

  Future<void> _clearCart() async {
    if (_uid != null) {
      final cartId = GroupCartManager.getEffectiveCartId(_uid!);
      final col = FirebaseFirestore.instance.collection('carts').doc(cartId).collection('items');
      final snap = await col.get();
      final batch = FirebaseFirestore.instance.batch();
      for (var d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    setState(() {
      _cartItems.clear();
    });
  }

  Widget _buildEmptyCart(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: isDark ? darkCard : Colors.grey[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: isDark ? darkHint : Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'سلة التسوق فارغة',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'لم تقم بإضافة أي وجبات بعد',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: const Text(
              'ابدأ التسوق',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
