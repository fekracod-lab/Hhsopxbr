import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dalal_alqaim/features/home/pages/home_page.dart';
import 'package:dalal_alqaim/pages/section_admin_page.dart';
import 'package:dalal_alqaim/shared/app_constants.dart';
import 'package:dalal_alqaim/widgets/app_tour_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double kBorderRadius = 24.0;

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'section', 'item'
  final TextEditingController _searchController = TextEditingController();

  final GlobalKey _titleKey = GlobalKey();
  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  bool _showTour = false;

  @override
  void initState() {
    super.initState();
    _checkTourStatus();
  }

  Future<void> _checkTourStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final tourShown = prefs.getBool('app_tour_completed') ?? false;
    if (!tourShown) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        setState(() => _showTour = true);
      }
    }
  }

  Future<void> _onTourComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_tour_completed', true);
    if (mounted) {
      setState(() => _showTour = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body:
          user == null
              ? _buildNotLoggedInView()
              : Stack(
                children: [
                  SafeArea(
                    child: Column(
                      children: [
                        _buildHeader(),
                        _buildSearchBar(),
                        _buildFilterChips(),
                        Expanded(child: _buildFavoritesList(user.uid)),
                      ],
                    ),
                  ),
                  if (_showTour)
                    AppTourOverlay(
                      steps: [
                        TourStep(
                          targetKey: _titleKey,
                          title: 'المفضلة',
                          description:
                              'هنا تجد كل ما قمت بحفظه من أقسام وعناصر للوصول إليها بسرعة.',
                        ),
                        TourStep(
                          targetKey: _searchBarKey,
                          title: 'البحث في المفضلة',
                          description:
                              'إذا كان لديك الكثير من العناصر، يمكنك البحث عنها بالاسم هنا.',
                        ),
                        TourStep(
                          targetKey: _filterKey,
                          title: 'تصفية النتائج',
                          description: 'يمكنك عرض الأقسام فقط أو العناصر فقط لتسهيل التصفح.',
                        ),
                      ],
                      onComplete: _onTourComplete,
                    ),
                ],
              ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleButton(
            Icons.arrow_forward_ios_rounded,
            onTap: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            },
          ),
          Text(
            'المفضلة',
            key: _titleKey,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          _buildCircleButton(
            Icons.help_outline_rounded,
            onTap: () => setState(() => _showTour = true),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: theme.iconTheme.color, size: 20),
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Container(
      key: _searchBarKey,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
        decoration: InputDecoration(
          hintText: 'ابحث في المفضلة...',
          hintStyle: TextStyle(color: theme.hintColor, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: theme.hintColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      key: _filterKey,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _buildFilterChip('الكل', 'all'),
          const SizedBox(width: 10),
          _buildFilterChip('الأقسام', 'section'),
          const SizedBox(width: 10),
          _buildFilterChip('العناصر', 'item'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final theme = Theme.of(context);
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () => setState(() => _filterType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.03),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.colorScheme.onPrimary : theme.textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesList(String userId) {
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('favorites')
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var docs = snapshot.data!.docs;

        if (_filterType != 'all') {
          docs =
              docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['type'] == _filterType;
              }).toList();
        }

        if (_searchQuery.isNotEmpty) {
          docs =
              docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final label = (data['label'] ?? data['name'] ?? '').toString().toLowerCase();
                return label.contains(_searchQuery.toLowerCase());
              }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'ماكو نتائج حالياً',
              style: TextStyle(color: theme.hintColor),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 15),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildFavoriteCard(doc.id, data, userId);
          },
        );
      },
    );
  }

  Widget _buildFavoriteCard(String docId, Map<String, dynamic> data, String userId) {
    final theme = Theme.of(context);
    final type = data['type'] ?? 'item';
    final label = data['label'] ?? data['name'] ?? 'عنصر بدون اسم';
    final isSection = type == 'section';

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(kBorderRadius),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _removeFavorite(docId, userId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(kBorderRadius),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(kBorderRadius),
            onTap: () => _navigateToItem(data),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: (isSection ? theme.colorScheme.primary : theme.colorScheme.secondary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      isSection ? Icons.grid_view_rounded : Icons.star_rounded,
                      color: isSection ? theme.colorScheme.primary : theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isSection
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.secondary)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isSection ? 'قسم' : 'عنصر',
                            style: TextStyle(
                              fontSize: 10,
                              color:
                                  isSection ? theme.colorScheme.primary : theme.colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(Icons.share_outlined, size: 20, color: theme.iconTheme.color),
                        onPressed: () => _shareItem(label, type),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                        onPressed: () => _removeFavorite(docId, userId),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: theme.disabledColor),
          const SizedBox(height: 20),
          Text(
            'بعدك ما ضايف شي للمفضلة عيوني',
            style: TextStyle(
              fontSize: 18,
              color: theme.hintColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تصفح الخدمات والمطاعم وخلي قلب عليها وتدلل!',
            style: TextStyle(
              fontSize: 13,
              color: theme.hintColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotLoggedInView() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 80, color: theme.disabledColor),
          const SizedBox(height: 20),
          Text(
            'لازم تسجل دخولك يا هلا',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/welcome');
            },
            child: Text(
              'سجل دخولك هسّه',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToItem(Map<String, dynamic> data) {
    final type = data['type'];
    final itemId = data['itemId'];
    final theme = Theme.of(context);

    if (type == 'section') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => SectionAdminPage(
                sectionId: itemId,
                sectionLabel: data['label'] ?? 'القسم',
                sectionIcon: Icons.category,
                sectionColor: theme.colorScheme.primary,
              ),
        ),
      );
    }
  }

  Future<void> _removeFavorite(String docId, String userId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(docId)
        .delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الحذف من المفضلة', style: TextStyle()),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _shareItem(String label, String type) {
    Share.share(
      'شاهد هذا ${type =='section' ? 'القسم' : 'العنصر'} المميز في ${AppConstants.appName}: $label',
    );
  }
}
