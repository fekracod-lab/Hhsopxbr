import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/services/firestore_sync_service.dart';
import 'package:dalal_alqaim/features/restaurant/presentation/pages/add_food_page.dart';

class RestaurantMenuTab extends StatefulWidget {
  final String restaurantId;

  const RestaurantMenuTab({
    super.key,
    required this.restaurantId,
  });

  @override
  State<RestaurantMenuTab> createState() => _RestaurantMenuTabState();
}

class _RestaurantMenuTabState extends State<RestaurantMenuTab> {
  String _selectedCategory = 'الكل';
  List<String> _customCategories = ['الكل'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCustomCategories() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .get();
      if (doc.exists && doc.data()?['categories'] != null) {
        final List<dynamic> cats = doc.data()?['categories'];
        if (mounted) {
          setState(() {
            _customCategories = ['الكل', ...cats.map((e) => e.toString())];
          });
        }
      }
    } catch (_) {}
  }

  void _manageCategoriesDialog() {
    final catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark ? app_colors.darkCard : Colors.white;
        final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;
        final textSecondary = isDark ? app_colors.darkSubText : app_colors.subTextColor;

        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.folder_copy_rounded, color: app_colors.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'ترتيب أقسام المنيو',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: catCtrl,
                      style: GoogleFonts.ibmPlexSansArabic(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'اكتب اسم القسم (مثال: مشاوي، كص وشاورما، بركر)',
                        hintStyle: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          color: textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (catCtrl.text.trim().isNotEmpty) {
                          final newCat = catCtrl.text.trim();
                          final updated = List<String>.from(
                            _customCategories.skip(1),
                          )..add(newCat);

                          await FirebaseFirestore.instance
                              .collection('restaurants')
                              .doc(widget.restaurantId)
                              .set({'categories': updated}, SetOptions(merge: true));

                          setDlgState(() {
                            _customCategories.add(newCat);
                            catCtrl.clear();
                          });
                          if (mounted) setState(() {});
                        }
                      },
                      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      label: Text(
                        'ضيف القسم',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: app_colors.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                    const Divider(height: 26),
                    Text(
                      'الأقسام الموجودة حالياً بالمنيو:',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_customCategories.length <= 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'بعدك ما ضايف أي قسم. اكتب اسم القسم فوگ ودوس إضافة.',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5,
                            color: textSecondary,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _customCategories.skip(1).map((cat) {
                          return Chip(
                            label: Text(
                              cat,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: app_colors.primaryColor,
                              ),
                            ),
                            backgroundColor: app_colors.primaryColor.withValues(alpha: 0.08),
                            deleteIcon: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.redAccent,
                            ),
                            onDeleted: () async {
                              final updated = List<String>.from(
                                _customCategories.skip(1),
                              )..remove(cat);

                              await FirebaseFirestore.instance
                                  .collection('restaurants')
                                  .doc(widget.restaurantId)
                                  .set({'categories': updated}, SetOptions(merge: true));

                              setDlgState(() {
                                _customCategories.remove(cat);
                              });
                              if (mounted) {
                                setState(() {
                                  if (_selectedCategory == cat) {
                                    _selectedCategory = 'الكل';
                                  }
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'رجوع',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
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
          .collection('merchant_products')
          .doc(widget.restaurantId)
          .collection('products')
          .snapshots(),
      builder: (context, snapshot) {
        final docsAll = snapshot.data?.docs ?? [];
        var docs = List<DocumentSnapshot>.from(docsAll);

        // Filter by category
        if (_selectedCategory != 'الكل') {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['category'] == _selectedCategory;
          }).toList();
        }

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final desc = (data['description'] ?? '').toString().toLowerCase();
            final q = _searchQuery.toLowerCase();
            return name.contains(q) || desc.contains(q);
          }).toList();
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          children: [
            const SizedBox(height: 8),

            // 1. Top Action & Add Food Button
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddFoodPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    label: Text(
                      'ضيف أكلة / وجبة جديدة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: app_colors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _manageCategoriesDialog,
                  icon: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: app_colors.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: app_colors.primaryColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.folder_open_rounded,
                      color: app_colors.primaryColor,
                      size: 20,
                    ),
                  ),
                  tooltip: 'ترتيب أقسام المنيو',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Search Box
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: GoogleFonts.ibmPlexSansArabic(
                  color: textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'دوّر على أكلة بالاسم أو المكونات...',
                  hintStyle: GoogleFonts.ibmPlexSansArabic(
                    color: textSecondary.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: app_colors.primaryColor,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 3. Categories Scrollbar
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _customCategories.length,
                itemBuilder: (context, idx) {
                  final cat = _customCategories[idx];
                  final isSel = _selectedCategory == cat;

                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = cat);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSel
                              ? app_colors.primaryColor
                              : (isDark ? app_colors.darkCard : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSel
                                ? app_colors.primaryColor
                                : (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.5),
                          ),
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: app_colors.primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cat,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isSel
                                ? Colors.white
                                : (isDark ? app_colors.darkText : app_colors.textColor),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // 4. Meals Grid / List
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: app_colors.primaryColor),
                ),
              )
            else if (docs.isEmpty)
              _buildEmptyMenuState(cardBg, textPrimary, textSecondary, isDark)
            else
              Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildMealItemCard(
                    context: context,
                    docId: doc.id,
                    data: data,
                    isDark: isDark,
                  );
                }).toList(),
              ),

            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildEmptyMenuState(Color cardBg, Color textPrimary, Color textSecondary, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: app_colors.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              size: 48,
              color: app_colors.primaryColor,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'ماكو أي أكلات بهالقسم حالياً',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'دوس على زر (ضيف أكلة جديدة) فوگ وابدي ضيف أكلاتك الطيبة للمنيو!',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              color: textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealItemCard({
    required BuildContext context,
    required String docId,
    required Map<String, dynamic> data,
    required bool isDark,
  }) {
    final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;
    final textSecondary = isDark ? app_colors.darkSubText : app_colors.subTextColor;
    final cardBg = isDark ? app_colors.darkCard : Colors.white;

    final name = data['name'] ?? 'أكلة طيبة';
    final price = data['sellingPrice'] ?? data['price'] ?? 0;
    final imageUrl = data['imageUrl'] ?? '';
    final desc = data['description'] ?? '';
    final isAvailable = data['isAvailable'] ?? true;
    final category = data['category'] ?? '';
    final sizes = (data['sizes'] as List<dynamic>?) ?? [];
    final isStockLimited = data['isStockLimited'] ?? false;
    final stockCount = data['stockCount'] ?? data['stockLimit'] ?? 0;

    final currencyFormatter = NumberFormat('#,###', 'ar_IQ');
    final formattedPrice = currencyFormatter.format(price is num ? price.toInt() : 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal Image Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 82,
                    height: 82,
                    color: app_colors.primaryColor.withValues(alpha: 0.08),
                    child: imageUrl.toString().isNotEmpty
                        ? Image.network(
                            imageUrl.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.fastfood_rounded,
                              color: app_colors.primaryColor,
                              size: 34,
                            ),
                          )
                        : const Icon(
                            Icons.fastfood_rounded,
                            color: app_colors.primaryColor,
                            size: 34,
                          ),
                  ),
                ),
                if (!isAvailable)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'خلصان',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name.toString(),
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (category.toString().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: app_colors.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            category.toString(),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: app_colors.primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (desc.toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      desc.toString(),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),

                  // Price & Sizes Indicator
                  Row(
                    children: [
                      Text(
                        '$formattedPrice د.ع',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: app_colors.primaryColor,
                        ),
                      ),
                      if (sizes.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${sizes.length} أحجام ',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                      if (isStockLimited) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'باقي $stockCount وجبة',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Actions & Availability Row
                  Row(
                    children: [
                      // Availability Toggle
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isAvailable ? 'متوفر' : 'خلصان',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isAvailable ? Colors.green.shade600 : Colors.redAccent,
                            ),
                          ),
                          Transform.scale(
                            scale: 0.72,
                            child: Switch.adaptive(
                              activeThumbColor: app_colors.primaryColor,
                              activeTrackColor: app_colors.primaryColor.withValues(alpha: 0.3),
                              value: isAvailable,
                              onChanged: (val) async {
                                HapticFeedback.selectionClick();
                                final pRef = FirebaseFirestore.instance
                                    .collection('merchant_products')
                                    .doc(widget.restaurantId)
                                    .collection('products')
                                    .doc(docId);
                                await pRef.update({'isAvailable': val});

                                try {
                                  await FirebaseFirestore.instance
                                      .collection('stores')
                                      .doc(widget.restaurantId)
                                      .collection('products')
                                      .doc(docId)
                                      .update({'isAvailable': val});
                                } catch (_) {}

                                try {
                                  await FirestoreSyncService.syncUpdateMeal(
                                    widget.restaurantId,
                                    docId,
                                    {'isAvailable': val},
                                  );
                                } catch (_) {}
                              },
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Edit Button
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: app_colors.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 15,
                            color: app_colors.primaryColor,
                          ),
                        ),
                        tooltip: 'عدّل الأكلة',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddFoodPage(
                                foodDocId: docId,
                                initialData: data,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),

                      // Delete Button
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            size: 15,
                            color: Colors.redAccent,
                          ),
                        ),
                        tooltip: 'احذف الأكلة',
                        onPressed: () => _showDeleteMealDialog(context, docId, name.toString()),
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

  void _showDeleteMealDialog(BuildContext context, String docId, String mealName) {
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
              Text(
                'حذف الأكلة من المنيو',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            'متأكد تريد تحذف "$mealName" من قائمة المنيو نهائياً؟',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              color: isDark ? app_colors.darkSubText : app_colors.subTextColor,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'لا، رجوع',
                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                Navigator.pop(ctx);

                await FirebaseFirestore.instance
                    .collection('merchant_products')
                    .doc(widget.restaurantId)
                    .collection('products')
                    .doc(docId)
                    .delete();

                try {
                  await FirebaseFirestore.instance
                      .collection('stores')
                      .doc(widget.restaurantId)
                      .collection('products')
                      .doc(docId)
                      .delete();
                } catch (_) {}

                try {
                  await FirestoreSyncService.syncDeleteMeal(widget.restaurantId, docId);
                } catch (_) {}

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'انحذفت الأكلة من المنيو بنجاح',
                        style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'اي، احذفها',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
