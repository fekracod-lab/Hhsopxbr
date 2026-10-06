import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'package:dalal_alqaim/pages/section_admin_page.dart';
import 'package:dalal_alqaim/pages/item_details_page.dart';
import 'package:dalal_alqaim/shared/section_utils.dart';
import 'package:dalal_alqaim/services/app_location_service.dart';
import 'package:dalal_alqaim/widgets/location_selector_widget.dart';
import 'package:dalal_alqaim/widgets/app_tour_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double kBorderRadius = 24.0;

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'section', 'item'
  Map<String, Map<String, dynamic>> _sectionsMetadata = {};

  final GlobalKey _titleKey = GlobalKey();
  final GlobalKey _locationKey = GlobalKey();
  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  bool _showTour = false;

  @override
  void initState() {
    super.initState();
    _fetchSectionsMetadata();
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

  Future<void> _fetchSectionsMetadata() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('sections').get();
      if (mounted) {
        setState(() {
          _sectionsMetadata = {
            for (var doc in snapshot.docs) doc.id: {...doc.data(), 'id': doc.id},
          };
        });
      }
    } catch (e) {
      debugPrint('Error fetching sections metadata: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildFilterChips(),
                Expanded(child: _buildSearchResults()),
              ],
            ),
          ),
          if (_showTour)
            AppTourOverlay(
              steps: [
                TourStep(
                  targetKey: _titleKey,
                  title: 'البحث الذكي',
                  description:
                      'مرحباً بك في محرك البحث؛ هنا يمكنك العثور على أي شيء تريده في ثوانٍ.',
                ),
                TourStep(
                  targetKey: _locationKey,
                  title: 'تحديد المنطقة',
                  description: 'يمكنك حصر نتائج البحث في منطقتك الحالية أو تصفح كل المناطق من هنا.',
                ),
                TourStep(
                  targetKey: _searchBarKey,
                  title: 'مربع البحث',
                  description: 'اكتب اسم المطعم، الوجبة، أو المتجر الذي تبحث عنه هنا.',
                ),
                TourStep(
                  targetKey: _filterKey,
                  title: 'تصنيف النتائج',
                  description:
                      'استخدم هذه الفلاتر للتبديل بين البحث في الأقسام الرئيسية أو العناصر الفرعية.',
                ),
              ],
              onComplete: _onTourComplete,
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (Navigator.canPop(context)) ...[
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    'البحث الذكي',
                    key: _titleKey,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              ListenableBuilder(
                listenable: AppLocationService(),
                builder: (context, _) {
                  final location = AppLocationService().currentLocation;
                  return GestureDetector(
                    onTap: () => _showLocationSelector(),
                    child: Container(
                      key: _locationKey,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 14, color: theme.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            location.governorateName ?? 'كل العراق',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'دور على الي تريده بثواني وتدلل',
                style: TextStyle(fontSize: 14, color: theme.hintColor),
              ),
              IconButton(
                onPressed: () => setState(() => _showTour = true),
                icon: Icon(Icons.help_outline_rounded, color: theme.primaryColor, size: 20),
                tooltip: 'المساعدة',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      key: _searchBarKey,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(kBorderRadius),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: isDark ? 0.05 : 0.08),
            blurRadius: 25,
            spreadRadius: -2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        cursorColor: theme.primaryColor,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF0E282B),
        ),
        decoration: InputDecoration(
          hintText: 'دور على مطعم، محل، أو وجبة طيبة...',
          hintStyle: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white60 : Colors.black45,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: theme.primaryColor, size: 26),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                  : Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.tune_rounded, color: theme.primaryColor, size: 20),
                  ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final theme = Theme.of(context);
    final filters = [
      {'label': 'الكل', 'value': 'all'},
      {'label': 'الأقسام', 'value': 'section'},
      {'label': 'العناصر', 'value': 'item'},
    ];

    return Container(
      key: _filterKey,
      height: 50,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final isSelected = _filterType == filters[index]['value'];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: ChoiceChip(
              label: Text(
                filters[index]['label']!,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : theme.hintColor,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _filterType = filters[index]['value']!);
                }
              },
              selectedColor: theme.primaryColor,
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? theme.primaryColor : theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              elevation: isSelected ? 4 : 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    final theme = Theme.of(context);
    if (_searchQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 80, color: theme.disabledColor.withValues(alpha: 0.2)),
            const SizedBox(height: 20),
            Text(
              'اكتب شتريد تدور عليه عيوني',
              style: TextStyle(
                fontSize: 18,
                color: theme.hintColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: AppLocationService(),
      builder: (context, _) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _searchStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  'ما لكَينا شي بهالاسم، جرب تبحث بغير كلمة',
                  style: TextStyle(color: theme.hintColor, fontWeight: FontWeight.bold),
                ),
              );
            }

            final results = snapshot.data!;

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              itemCount: results.length,
              separatorBuilder: (context, index) => const SizedBox(height: 15),
              itemBuilder: (context, index) {
                return _buildResultCard(results[index]);
              },
            );
          },
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _searchStream() {
    final sectionsStream = FirebaseFirestore.instance
        .collection('sections')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => {
                      ...doc.data(),
                      'id': doc.id,
                      'path': doc.reference.path,
                      'resultType': 'section',
                      'name': doc.data()['label'] ?? 'بدون اسم',
                    },
                  )
                  .toList(),
        );

    final itemsStream = FirebaseFirestore.instance
        .collectionGroup('items')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => {
                      ...doc.data(),
                      'id': doc.id,
                      'path': doc.reference.path,
                      'resultType': 'item',
                    },
                  )
                  .toList(),
        );

    if (_filterType == 'section') {
      return sectionsStream.map((list) => _filterList(list));
    } else if (_filterType == 'item') {
      return itemsStream.map((list) => _filterList(list));
    } else {
      return _combineLatest(sectionsStream, itemsStream, (sections, items) {
        return _filterList([...sections, ...items]);
      });
    }
  }

  Stream<T> _combineLatest<T, A, B>(
    Stream<A> streamA,
    Stream<B> streamB,
    T Function(A, B) combiner,
  ) {
    late StreamController<T> controller;
    A? lastA;
    B? lastB;
    bool hasA = false;
    bool hasB = false;

    controller = StreamController<T>(
      onListen: () {
        final subA = streamA.listen((a) {
          lastA = a;
          hasA = true;
          if (hasB) controller.add(combiner(lastA as A, lastB as B));
        });
        final subB = streamB.listen((b) {
          lastB = b;
          hasB = true;
          if (hasA) controller.add(combiner(lastA as A, lastB as B));
        });

        controller.onCancel = () {
          subA.cancel();
          subB.cancel();
        };
      },
    );

    return controller.stream;
  }

  List<Map<String, dynamic>> _filterList(List<Map<String, dynamic>> list) {
    if (_searchQuery.isEmpty) return [];
    final location = AppLocationService().currentLocation;
    final q = _searchQuery.toLowerCase().trim();

    return list.where((item) {
      final gId = item['governorateId'];
      final rId = item['regionId'];

      if (gId == null) {
        if (location.governorateId != null &&
            location.regionName != 'القائم' &&
            location.governorateName != 'الأنبار') {
          return false;
        }
      } else {
        if (location.governorateId != null) {
          if (gId != location.governorateId) return false;
          if (location.regionId != null && rId != null && rId != location.regionId) {
            return false;
          }
        }
      }

      final label = (item['label'] ?? '').toString().toLowerCase();
      final name = (item['name'] ?? '').toString().toLowerCase();
      final specialty = (item['specialty'] ?? '').toString().toLowerCase();

      return label.contains(q) || name.contains(q) || specialty.contains(q);
    }).toList();
  }

  Widget _buildResultCard(Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final type = data['resultType'] ?? 'item';
    final isSection = type == 'section';
    final name = data['label'] ?? data['name'] ?? 'بدون اسم';
    final image = data['image'] ?? data['imageUrl'] ?? '';
    final rating = data['rating']?.toString() ?? '0.0';
    final specialty = data['specialty'] ?? (isSection ? 'قسم رئيسي' : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: isDark ? 0.05 : 0.02)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (isSection) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => SectionAdminPage(
                        sectionId: data['id'],
                        sectionLabel: name,
                        sectionIcon: sectionIconFromString(data['icon'] ?? 'category'),
                        sectionColor: Color(data['color'] ?? 0xFF2196F3),
                      ),
                ),
              );
            } else {
              final path = data['path'] as String?;
              if (path == null) return;

              final segments = path.split('/');
              String? sId, pId, iId;

              if (segments.length >= 4 && segments[0] == 'sections' && segments[2] == 'items') {
                sId = segments[1];
                iId = segments[3];
              } else if (segments.length >= 6 &&
                  segments[0] == 'sections' &&
                  segments[2] == 'pages' &&
                  segments[4] == 'items') {
                sId = segments[1];
                pId = segments[3];
                iId = segments[5];
              }

              if (sId != null && iId != null) {
                final meta = _sectionsMetadata[sId] ?? {};
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => ItemDetailsPage(
                          sectionId: sId!,
                          itemId: iId!,
                          sectionLabel: meta['label'] ?? 'قسم',
                          sectionIcon: sectionIconFromString(meta['icon'] ?? 'category'),
                          sectionColor: Color(meta['color'] ?? 0xFF26A69A),
                          pageId: pId,
                        ),
                  ),
                );
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color:
                        isDark
                            ? theme.primaryColor.withValues(alpha: 0.1)
                            : theme.primaryColor.withValues(alpha: 0.05),
                    image:
                        image.isNotEmpty
                            ? DecorationImage(image: NetworkImage(image), fit: BoxFit.cover)
                            : null,
                  ),
                  child:
                      image.isEmpty
                          ? Icon(
                            isSection
                                ? sectionIconFromString(data['icon'] ?? 'category')
                                : Icons.store_rounded,
                            color: theme.primaryColor,
                            size: 30,
                          )
                          : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialty,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? theme.hintColor : theme.hintColor.withValues(alpha: 0.8),
                        ),
                      ),
                      if (!isSection) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star_rounded, size: 14, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Text(
                                    rating,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.primaryColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on _SearchPageState {
  void _showLocationSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LocationSelectorWidget(),
    );
  }
}
