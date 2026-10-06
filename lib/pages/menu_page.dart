import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cart_page.dart';

// --- Palette Configuration ---
const Color primaryColor = Color(0xFF26A69A);
const Color accentColor = Color(0xFF00796B);
const Color backgroundColor = Color(0xFFFFFFFF);
const Color textColor = Color(0xFF333333);
const Color hintColor = Color(0xFF9E9E9E);
const Color subTextColor = Color(0xFF757575);
const Color surfaceColor = Color(0xFFF8F9FA);

// --- Dark Mode Palette ---
const Color darkBackground = Color(0xFF07191A);
const Color darkSurface = Color(0xFF0F2323);
const Color darkCard = Color(0xFF113033);
const Color darkText = Color(0xFFE0F2F1);
const Color darkSubText = Color(0xFF80CBC4);
const Color darkHint = Color(0xFF4DB6AC);

class MenuPage extends StatefulWidget {
  final String sectionId;
  final String restaurantItemId;
  final String restaurantName;

  const MenuPage({
    super.key,
    required this.sectionId,
    required this.restaurantItemId,
    required this.restaurantName,
  });

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  // حالة السلة المحلية (للعرض الفوري)
  Map<String, int> _cartQuantities = {};
  double _cartTotal = 0.0;
  int _cartCount = 0;

  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _subscribeToCart();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // الاستماع للسلة لضمان تزامن الكميات
  void _subscribeToCart() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    FirebaseFirestore.instance.collection('carts').doc(uid).collection('items').snapshots().listen((
      snapshot,
    ) {
      final quantities = <String, int>{};
      double total = 0.0;
      int count = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final itemId = data['itemId']?.toString() ?? '';
        final qty = (data['quantity'] ?? 0) as int;
        final price = (data['price'] ?? 0).toDouble();

        if (itemId.isNotEmpty) {
          quantities[itemId] = qty;
        }
        total += (price * qty);
        count += qty;
      }

      if (mounted) {
        setState(() {
          _cartQuantities = quantities;
          _cartTotal = total;
          _cartCount = count;
        });
      }
    });
  }

  // إضافة للسلة
  Future<void> _addToCart(Map<String, dynamic> food, String docId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('سجّل دخولك أولاً')));
      return;
    }

    final cartRef = FirebaseFirestore.instance.collection('carts').doc(uid).collection('items');

    // التحقق هل العنصر موجود
    final existing = await cartRef.where('itemId', isEqualTo: docId).limit(1).get();

    if (existing.docs.isNotEmpty) {
      final existingDoc = existing.docs.first;
      await cartRef.doc(existingDoc.id).update({'quantity': FieldValue.increment(1)});
    } else {
      // إضافة جديد
      await cartRef.add({
        'itemId': docId,
        'name': food['name'],
        'price': food['price'],
        'image': food['imageUrl'],
        'restaurantId': widget.restaurantItemId, // مهم جداً لعملية الدفع
        'restaurant': widget.restaurantName, // اسم المطعم للعرض
        'quantity': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // حذف من السلة
  Future<void> _removeFromCart(String docId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final cartRef = FirebaseFirestore.instance.collection('carts').doc(uid).collection('items');
    final existing = await cartRef.where('itemId', isEqualTo: docId).limit(1).get();

    if (existing.docs.isNotEmpty) {
      final existingDoc = existing.docs.first;
      final currentQty = existingDoc.data()['quantity'] as int;

      if (currentQty > 1) {
        await cartRef.doc(existingDoc.id).update({'quantity': FieldValue.increment(-1)});
      } else {
        await cartRef.doc(existingDoc.id).delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? darkBackground : backgroundColor;
    final mainTextColor = isDark ? darkText : textColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(isDark, mainTextColor),
              _buildSearchBar(isDark),
              _buildMenuList(isDark),
              // مساحة فارغة في الأسفل لكي لا يغطي الزر العائم المحتوى
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // شريط السلة العائم
          if (_cartCount > 0)
            Positioned(bottom: 20, left: 20, right: 20, child: _buildFloatingCartBar(isDark)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark, Color titleColor) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: true,
      pinned: true,
      backgroundColor: isDark ? darkSurface : primaryColor,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? darkCard.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          widget.restaurantName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                isDark ? darkSurface : primaryColor,
                isDark ? darkBackground : primaryColor.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: const Center(
            child: Icon(Icons.restaurant_menu_rounded, size: 60, color: Colors.white24),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          style: TextStyle(color: isDark ? darkText : textColor),
          decoration: InputDecoration(
            hintText: 'ابحث عن وجبة...',
            hintStyle: TextStyle(color: isDark ? darkHint : hintColor),
            prefixIcon: Icon(Icons.search, color: isDark ? darkSubText : primaryColor),
            filled: true,
            fillColor: isDark ? darkCard : surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuList(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('sections')
              .doc(widget.sectionId)
              .collection('items')
              .doc(widget.restaurantItemId)
              .collection('menu')
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: primaryColor)),
          );
        }

        if (snapshot.hasError) {
          return SliverFillRemaining(
            child: Center(
              child: Text(
                'حدث خطأ في التحميل',
                style: TextStyle(color: isDark ? darkText : textColor),
              ),
            ),
          );
        }

        var foods = snapshot.data?.docs ?? [];

        // فلترة البحث
        if (_searchQuery.isNotEmpty) {
          foods =
              foods.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery.toLowerCase());
              }).toList();
        }

        if (foods.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fastfood_outlined,
                    size: 60,
                    color: isDark ? darkHint : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ماكو وجبات حالياً متاحة حالياً',
                    style: TextStyle(
                      color: isDark ? darkSubText : subTextColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final doc = foods[index];
            final food = doc.data() as Map<String, dynamic>;
            return _buildFoodCard(food, doc.id, isDark);
          }, childCount: foods.length),
        );
      },
    );
  }

  Widget _buildFoodCard(Map<String, dynamic> food, String docId, bool isDark) {
    final qty = _cartQuantities[docId] ?? 0;

    // التعامل مع أنواع البيانات المختلفة للسعر
    double price = 0.0;
    if (food['price'] is num) {
      price = (food['price'] as num).toDouble();
    } else if (food['price'] is String) {
      price = double.tryParse(food['price']) ?? 0.0;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصورة
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                food['imageUrl'] ?? '',
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      width: 90,
                      height: 90,
                      color: Colors.grey[300],
                      child: const Icon(Icons.fastfood, color: Colors.grey),
                    ),
              ),
            ),
            const SizedBox(width: 16),

            // التفاصيل
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food['name'] ?? 'بدون اسم',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? darkText : textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    food['description'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? darkSubText : subTextColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$price د.ع',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 16,
                        ),
                      ),
                      // أزرار التحكم بالكمية
                      _buildQuantityControls(docId, qty, food, isDark),
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

  Widget _buildQuantityControls(String docId, int qty, Map<String, dynamic> food, bool isDark) {
    if (qty == 0) {
      return InkWell(
        onTap: () => _addToCart(food, docId),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? darkSurface : surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
          ),
          child: const Icon(Icons.add, color: primaryColor, size: 20),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _removeFromCart(docId),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.remove, color: Colors.white, size: 18),
            ),
          ),
          Text(
            '$qty',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          InkWell(
            onTap: () => _addToCart(food, docId),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.add, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingCartBar(bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CartPage(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$_cartCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'المجموع',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
                Text(
                  '$_cartTotal د.ع',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Text(
              'عرض السلة',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
