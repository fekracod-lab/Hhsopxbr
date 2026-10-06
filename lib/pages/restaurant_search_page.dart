import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/features/trip/presentation/trip_design.dart';
import 'package:dalal_alqaim/services/app_location_service.dart';
import 'restaurant_details_page.dart';

class RestaurantSearchPage extends StatefulWidget {
  final String? initialQuery;
  const RestaurantSearchPage({super.key, this.initialQuery});

  @override
  State<RestaurantSearchPage> createState() => _RestaurantSearchPageState();
}

class _RestaurantSearchPageState extends State<RestaurantSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<String> _recentSearches = ['شاورما', 'بيتزا', 'مشاوي', 'حلويات القائم'];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _searchQuery = widget.initialQuery!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? TripDesign.darkBackground : TripDesign.background;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            _buildSearchBar(isDark),
            Expanded(
              child: _searchQuery.isEmpty ? _buildSuggestions(isDark) : _buildSearchResults(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? TripDesign.darkText : TripDesign.textColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'بحث عن مطعم',
            style: TextStyle(
              fontFamily: TripDesign.kFontFamily,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? TripDesign.darkText : TripDesign.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 55,
      decoration: BoxDecoration(
        color: isDark ? TripDesign.darkSurface : TripDesign.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: TripDesign.softShadow,
        border: Border.all(
          color: isDark ? TripDesign.darkCard : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: isDark ? TripDesign.darkHint : TripDesign.hintColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(
                fontFamily: TripDesign.kFontFamily,
                color: isDark ? TripDesign.darkText : TripDesign.textColor,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'ابحث عن اسم المطعم أو نوع الوجبة...',
                hintStyle: TextStyle(
                  fontFamily: TripDesign.kFontFamily,
                  color: isDark ? TripDesign.darkHint : TripDesign.hintColor,
                  fontSize: 14,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: Icon(
                Icons.close_rounded,
                color: isDark ? TripDesign.darkSubText : TripDesign.subTextColor,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestions(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          _buildSectionTitle('عمليات البحث الأخيرة', isDark),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _recentSearches.map((s) => _buildSearchTag(s, isDark)).toList(),
          ),
          const SizedBox(height: 30),
        ],
        _buildSectionTitle('تصنيفات شائعة', isDark),
        const SizedBox(height: 16),
        _buildCategoryGrid(isDark),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: TripDesign.kFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDark ? TripDesign.darkText : TripDesign.textColor,
      ),
    );
  }

  Widget _buildSearchTag(String text, bool isDark) {
    return GestureDetector(
      onTap: () {
        _searchController.text = text;
        setState(() => _searchQuery = text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? TripDesign.darkSurface : TripDesign.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark ? TripDesign.darkCard : Colors.grey.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: TripDesign.kFontFamily,
            fontSize: 13,
            color: isDark ? TripDesign.darkSubText : TripDesign.subTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(bool isDark) {
    final categories = [
      {'name': 'مطاعم', 'icon': Icons.restaurant_rounded, 'color': Colors.orange},
      {'name': 'حلويات', 'icon': Icons.cake_rounded, 'color': Colors.pink},
      {'name': 'عصائر', 'icon': Icons.local_cafe_rounded, 'color': Colors.blue},
      {'name': 'منزلية', 'icon': Icons.home_rounded, 'color': Colors.green},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
        childAspectRatio: 2.2,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return GestureDetector(
          onTap: () {
            setState(() => _searchQuery = cat['name'] as String);
            _searchController.text = cat['name'] as String;
          },
          child: Container(
            decoration: BoxDecoration(
              color: (cat['color'] as Color).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: (cat['color'] as Color).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 24),
                const SizedBox(width: 10),
                Text(
                  cat['name'] as String,
                  style: TextStyle(
                    fontFamily: TripDesign.kFontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? TripDesign.darkText : TripDesign.textColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: TripDesign.primary));
        }

        return ListenableBuilder(
          listenable: AppLocationService(),
          builder: (context, _) {
            final location = AppLocationService().currentLocation;
            final docs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              
              // 1. Location Filter
              final gId = data['governorateId'];
              bool locationMatch = false;

              if (gId == null) {
                // Legacy data: Show if "All Iraq" OR "Al-Qaim" OR "Anbar"
                if (location.governorateId == null || 
                    location.regionName == 'القائم' || 
                    location.governorateName == 'الأنبار') {
                  locationMatch = true;
                }
              } else {
                // Tagged data: Must match the selected location
                if (location.governorateId == null) {
                  locationMatch = true; 
                } else {
                  if (gId == location.governorateId) {
                    final rId = data['regionId'];
                    if (location.regionId == null || rId == location.regionId) {
                      locationMatch = true;
                    }
                  }
                }
              }

              if (!locationMatch) return false;

              // 2. Search Query Filter
              final name = (data['name'] ?? '').toString().toLowerCase();
              final category = (data['category'] ?? '').toString().toLowerCase();
              return name.contains(_searchQuery.toLowerCase()) ||
                  category.contains(_searchQuery.toLowerCase());
            }).toList();

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 80,
                      color: isDark ? TripDesign.darkHint : TripDesign.hintColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ماكو نتائج حالياً للبحث عن "$_searchQuery"',
                      style: TextStyle(
                        fontFamily: TripDesign.kFontFamily,
                        fontSize: 16,
                        color: isDark ? TripDesign.darkSubText : TripDesign.subTextColor,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return _buildSearchCard(doc.id, data, isDark);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSearchCard(String id, Map<String, dynamic> data, bool isDark) {
    final name = data['name']?.toString() ?? 'مطعم غير معروف';
    final category = data['category']?.toString() ?? 'قسم غير معروف';
    final imageUrl = data['imageUrl']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => RestaurantDetailsPage(
                  restaurantId: id,
                  restaurantName: name,
                  imageUrl: imageUrl,
                ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? TripDesign.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: TripDesign.cardShadow,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 70,
                height: 70,
                child:
                    imageUrl.isNotEmpty
                        ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
                        )
                        : _buildPlaceholder(isDark),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontFamily: TripDesign.kFontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? TripDesign.darkText : TripDesign.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.category_rounded, size: 14, color: TripDesign.primary),
                      const SizedBox(width: 4),
                      Text(
                        category,
                        style: TextStyle(
                          fontFamily: TripDesign.kFontFamily,
                          fontSize: 12,
                          color: isDark ? TripDesign.darkSubText : TripDesign.subTextColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isDark ? TripDesign.darkHint : TripDesign.hintColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? TripDesign.darkSurface : Colors.grey[200],
      child: Icon(Icons.restaurant, color: isDark ? TripDesign.darkHint : TripDesign.hintColor),
    );
  }
}
