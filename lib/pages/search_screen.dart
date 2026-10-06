import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dalal_alqaim/services/google_maps_service.dart';

// ============================================================================
// Design Constants & Theme
// ============================================================================
const Color kPrimaryColor = Color(0xFF00897B); // Teal 600
const Color kSecondaryColor = Color(0xFF26A69A); // Teal 400
const Color kAccentColor = Color(0xFFB2DFDB); // Teal 100
const Color kSurfaceColor = Color(0xFFF5F7FA); // Light Grey-Blue
const Color kCardColor = Colors.white;
const Color kTextColor = Color(0xFF2D3436);
const Color kSubTextColor = Color(0xFF636E72);

const double kBorderRadius = 16.0;
const Duration kAnimationDuration = Duration(milliseconds: 300);

// ============================================================================
// Data Model
// ============================================================================
class SearchPlace {
  final String id;
  final String name;
  final String address;
  final String type;
  final LatLng location;
  final String source;
  final String? placeCategory;

  SearchPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.type,
    required this.location,
    required this.source,
    this.placeCategory,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'type': type,
    'lat': location.latitude,
    'lng': location.longitude,
    'source': source,
    'placeCategory': placeCategory,
  };

  factory SearchPlace.fromJson(Map<String, dynamic> json) {
    return SearchPlace(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? json['name'] ?? '',
      type: json['type'] ?? 'place',
      location: LatLng(
        (json['lat'] as num?)?.toDouble() ?? 0.0,
        (json['lng'] as num?)?.toDouble() ?? 0.0,
      ),
      source: json['source'] ?? 'unknown',
      placeCategory: json['placeCategory'],
    );
  }
}

// ============================================================================
// Screen
// ============================================================================
class SearchScreen extends StatefulWidget {
  final LatLng? currentLocation;
  const SearchScreen({super.key, this.currentLocation});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Data
  List<SearchPlace> _searchResults = [];
  List<SearchPlace> _savedPlaces = [];
  List<SearchPlace> _recentPlaces = [];
  final List<SearchPlace> _firestorePlaces = [];
  final List<SearchPlace> _geoJsonPlaces = [];

  // State
  bool _isSearching = false;
  bool _isLoading = false;
  Timer? _debounce;
  StreamSubscription? _placesSub;
  int _lastSearchId = 0;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeController.forward();

    _loadLocalData();
    _loadGeoJsonPlaces();
    _listenToFirestorePlaces();

    // Auto-focus after a short delay for smooth transition
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _placesSub?.cancel();
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // --- Logic Implementation (Preserved) ---

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedString = prefs.getString('saved_places');
    final recentString = prefs.getString('recent_places');

    if (mounted) {
      setState(() {
        if (savedString != null) {
          _savedPlaces =
              (json.decode(savedString) as List).map((e) => SearchPlace.fromJson(e)).toList();
        }
        if (recentString != null) {
          _recentPlaces =
              (json.decode(recentString) as List).map((e) => SearchPlace.fromJson(e)).toList();
        }
      });
    }
  }

  Future<void> _persistLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'saved_places',
      json.encode(_savedPlaces.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'recent_places',
      json.encode(_recentPlaces.map((e) => e.toJson()).toList()),
    );
  }

  void _listenToFirestorePlaces() {
    _placesSub = FirebaseFirestore.instance
        .collection('places')
        .where('published', isEqualTo: true)
        .limit(100)
        .snapshots()
        .listen((snap) {
          _firestorePlaces.clear();
          for (var doc in snap.docs) {
            final d = doc.data();
            _firestorePlaces.add(
              SearchPlace(
                id: doc.id,
                name: d['name'] ?? '',
                address: d['address'] ?? '',
                type: d['type'] ?? 'place',
                location: LatLng((d['lat'] as num).toDouble(), (d['lng'] as num).toDouble()),
                source: 'firestore',
              ),
            );
          }
        });
  }

  Future<void> _loadGeoJsonPlaces() async {
    try {
      final raw = await rootBundle.loadString('assets/al_qaim_roads.geojson');
      final data = json.decode(raw);
      for (var feature in data['features']) {
        if (feature['geometry']['type'] == 'Point') {
          final props = feature['properties'];
          final coords = feature['geometry']['coordinates'];
          _geoJsonPlaces.add(
            SearchPlace(
              id: props['id']?.toString() ?? DateTime.now().toString(),
              name: props['name'] ?? 'معلم غير مسمى',
              address: props['name'] ?? '',
              type: props['type'] ?? 'marker',
              location: LatLng(coords[1], coords[0]),
              source: 'geojson',
            ),
          );
        }
      }
    } catch (_) {}
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _isLoading = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() => _isLoading = true);
    _debounce = Timer(const Duration(milliseconds: 300), () => _executeSearch(query));
  }

  Future<void> _executeSearch(String query) async {
    final int searchId = ++_lastSearchId;
    final cleanQuery = query.trim().toLowerCase();

    // 1. Instant Local Search
    final localMatches =
        [
          ..._geoJsonPlaces,
          ..._firestorePlaces,
        ].where((p) => p.name.toLowerCase().contains(cleanQuery)).take(15).toList();

    if (mounted && searchId == _lastSearchId) {
      setState(() {
        _searchResults = localMatches;
        _isSearching = true;
        if (localMatches.isNotEmpty) _isLoading = false;
      });
    }

    // 2. Async Google Search
    debugPrint(" Starting Google Search for: $cleanQuery");
    List<SearchPlace> googleMatches = [];
    try {
      googleMatches = await _searchGoogleHttp(cleanQuery);
      debugPrint(" Google Search returned ${googleMatches.length} results");
    } catch (e) {
      debugPrint(" Google Search Exception: $e");
    }

    if (searchId != _lastSearchId || !mounted) return;

    // 3. Merge & Deduplicate
    final Set<String> uniqueIds = {};
    final List<SearchPlace> merged = [];

    for (var p in [...localMatches, ...googleMatches]) {
      final key =
          "${p.name.toLowerCase()}_${p.location.latitude.toStringAsFixed(3)}_${p.location.longitude.toStringAsFixed(3)}";
      if (uniqueIds.add(key)) {
        merged.add(p);
      }
    }

    setState(() {
      _searchResults = merged.take(40).toList();
      _isLoading = false;
    });
  }

  Future<List<SearchPlace>> _searchGoogleHttp(String query) async {
    try {
      final results = await GoogleMapsService.instance.searchPlaces(
        query,
        near: widget.currentLocation,
        maxResults: 20,
      );

      return results
          .map(
            (r) => SearchPlace(
              id: r.id,
              name: r.name,
              address: r.address,
              type: 'google_result',
              location: r.location,
              source: 'google',
              placeCategory: r.category,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint(' Google search error: $e');
      return [];
    }
  }

  void _onPlaceSelected(SearchPlace place) {
    HapticFeedback.selectionClick();
    setState(() {
      _recentPlaces.removeWhere((p) => p.name == place.name);
      _recentPlaces.insert(0, place);
      if (_recentPlaces.length > 8) _recentPlaces.removeLast();
    });
    _persistLocalData();
    Navigator.pop(context, {
      'lat': place.location.latitude,
      'lng': place.location.longitude,
      'name': place.name,
      'address': place.address,
    });
  }

  void _toggleSave(SearchPlace place) {
    setState(() {
      final index = _savedPlaces.indexWhere((p) => p.name == place.name);
      if (index != -1) {
        _savedPlaces.removeAt(index);
      } else {
        _savedPlaces.add(
          SearchPlace(
            id: place.id,
            name: place.name,
            address: place.address,
            type: 'saved',
            location: place.location,
            source: 'user_saved',
          ),
        );
      }
    });
    _persistLocalData();
  }

  void _quickSearch(String category) {
    _controller.text = category;
    _focusNode.unfocus();
    _onSearchChanged(category);
  }

  // ==========================================================================
  // UI Construction
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurfaceColor,
      body: Stack(
        children: [
          // Background Gradient Element
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [kPrimaryColor.withValues(alpha: 0.2), Colors.transparent],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeController,
                    child: _isLoading ? _buildLoadingShimmer() : _buildContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
      decoration: BoxDecoration(color: kSurfaceColor.withValues(alpha: 0.9)),
      child: Column(
        children: [
          Row(
            children: [
              _buildBackButton(),
              const SizedBox(width: 12),
              Expanded(child: _buildGlassSearchField()),
            ],
          ),
          if (!_isSearching) ...[const SizedBox(height: 16), _buildQuickCategories()],
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return InkWell(
      onTap: () => Navigator.pop(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: kTextColor),
      ),
    );
  }

  Widget _buildGlassSearchField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onSearchChanged,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: kTextColor,
          fontSize: 16,
        ),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: "ابحث عن منطقة، مطعم، أو معلم...",
          hintStyle: TextStyle(
            color: kSubTextColor.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: kPrimaryColor),
          suffixIcon:
              _controller.text.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: kSubTextColor, size: 20),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _controller.clear();
                      _onSearchChanged('');
                    },
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildQuickCategories() {
    final categories = [
      {'icon': Icons.restaurant_rounded, 'label': 'مطاعم', 'query': 'مطعم'},
      {'icon': Icons.local_hospital_rounded, 'label': 'صيدليات', 'query': 'صيدلية'},
      {'icon': Icons.mosque_rounded, 'label': 'مساجد', 'query': 'مسجد'},
      {'icon': Icons.shopping_cart_rounded, 'label': 'تسوق', 'query': 'سوق'},
      {'icon': Icons.local_cafe_rounded, 'label': 'كافيهات', 'query': 'قهوة'},
    ];

    return SizedBox(
      height: 45,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return InkWell(
            onTap: () => _quickSearch(cat['query'] as String),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kPrimaryColor.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Icon(cat['icon'] as IconData, size: 18, color: kPrimaryColor),
                  const SizedBox(width: 6),
                  Text(
                    cat['label'] as String,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_controller.text.isEmpty) {
      return _buildDefaultView();
    }

    if (_isLoading && _searchResults.isEmpty) {
      return _buildLoadingShimmer();
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyState();
    }

    return _buildSearchResults();
  }

  Widget _buildDefaultView() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        if (widget.currentLocation != null) ...[
          const SizedBox(height: 10),
          _CurrentLocationTile(
            onTap: () {
              Navigator.pop(context, {
                'lat': widget.currentLocation!.latitude,
                'lng': widget.currentLocation!.longitude,
                'name': 'موقعي الحالي',
                'address': 'الموقع الحالي',
              });
            },
          ),
        ],

        if (_savedPlaces.isNotEmpty) ...[
          const _SectionHeader(title: "الأماكن المحفوظة", icon: Icons.bookmark_rounded),
          ..._savedPlaces.map(
            (p) => _PlaceTile(
              place: p,
              isSaved: true,
              onTap: () => _onPlaceSelected(p),
              onSaveToggle: () => _toggleSave(p),
            ),
          ),
        ],

        if (_recentPlaces.isNotEmpty) ...[
          _SectionHeader(
            title: "آخر عمليات البحث",
            icon: Icons.history_rounded,
            actionLabel: "مسح الكل",
            onAction: () {
              setState(() {
                _recentPlaces.clear();
                _persistLocalData();
              });
            },
          ),
          ..._recentPlaces.map(
            (p) => _PlaceTile(place: p, onTap: () => _onPlaceSelected(p), isHistory: true),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final place = _searchResults[index];
        return AnimatedBuilder(
          animation: _fadeController,
          builder: (context, child) {
            final double slide = 50.0 * (1.0 - _fadeController.value);
            return Transform.translate(
              offset: Offset(0, slide),
              child: Opacity(
                opacity: _fadeController.value,
                child: _PlaceTile(
                  place: place,
                  isResult: true,
                  isSaved: _savedPlaces.any((p) => p.name == place.name),
                  onTap: () => _onPlaceSelected(place),
                  onSaveToggle: () => _toggleSave(place),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder:
            (_, __) => Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 150,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kPrimaryColor.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_off_rounded, size: 60, color: kSubTextColor),
          ),
          const SizedBox(height: 16),
          const Text(
            "لم نجد نتائج مطابقة",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "حاول البحث عن اسم مكان آخر أو تحقق من الإملاء",
            style: TextStyle(fontSize: 14, color: kSubTextColor),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Helper Widgets (New Design)
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.icon, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: kPrimaryColor),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: kTextColor,
                ),
              ),
            ],
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CurrentLocationTile extends StatelessWidget {
  final VoidCallback onTap;
  const _CurrentLocationTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kBorderRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kPrimaryColor, kSecondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(kBorderRadius),
          boxShadow: [
            BoxShadow(
              color: kPrimaryColor.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.my_location, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "استخدم موقعي الحالي",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "تحديد الموقع تلقائياً عبر GPS",
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  final SearchPlace place;
  final bool isResult;
  final bool isSaved;
  final bool isHistory;
  final VoidCallback onTap;
  final VoidCallback? onSaveToggle;

  const _PlaceTile({
    required this.place,
    required this.onTap,
    this.isResult = false,
    this.isSaved = false,
    this.isHistory = false,
    this.onSaveToggle,
  });

  Color _getIconBgColor() {
    if (isSaved) return Colors.amber.withValues(alpha: 0.15);
    if (isHistory) return kSubTextColor.withValues(alpha: 0.08);
    if (place.source == 'google') return Colors.blue.withValues(alpha: 0.1);
    return kPrimaryColor.withValues(alpha: 0.1);
  }

  Color _getIconColor() {
    if (isSaved) return Colors.amber[700]!;
    if (isHistory) return kSubTextColor;
    if (place.source == 'google') return Colors.blue[600]!;
    return kPrimaryColor;
  }

  IconData _getIcon() {
    if (isSaved) return Icons.star_rounded;
    if (isHistory) return Icons.history_rounded;
    if (place.type == 'restaurant') return Icons.restaurant_rounded;
    if (place.type == 'hospital') return Icons.local_hospital_rounded;
    if (place.type == 'pharmacy') return Icons.local_pharmacy_rounded;
    if (place.type == 'store') return Icons.shopping_bag_rounded;
    return Icons.location_on_rounded;
  }

  String _getSourceLabel() {
    if (place.source == 'google') return 'Google';
    if (place.source == 'firestore') return 'تطبيق';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(kBorderRadius),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getIconBgColor(),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_getIcon(), color: _getIconColor(), size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                place.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: kTextColor,
                ),
              ),
            ),
            if (isResult && _getSourceLabel().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getSourceLabel(),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (place.address.isNotEmpty && place.address != place.name)
              Text(
                place.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: kSubTextColor.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
        trailing:
            isResult
                ? InkWell(
                  onTap: onSaveToggle,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_outline_rounded,
                      color: isSaved ? kPrimaryColor : Colors.grey[400],
                      size: 24,
                    ),
                  ),
                )
                : const Icon(Icons.north_west_rounded, size: 16, color: Colors.grey),
      ),
    );
  }
}
