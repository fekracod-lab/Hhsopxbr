import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_location_service.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class LocationSelectorWidget extends StatefulWidget {
  const LocationSelectorWidget({super.key});

  @override
  State<LocationSelectorWidget> createState() => _LocationSelectorWidgetState();
}

class _LocationSelectorWidgetState extends State<LocationSelectorWidget>
    with SingleTickerProviderStateMixin {
  // --- State ---
  String? tempGovId;
  String? tempGovName;
  String? tempRegId;
  String? tempRegName;

  bool isLoadingGovs = true;
  bool isLoadingRegions = false;
  bool isDetecting = false;
  bool _showRegions = false;

  List<Map<String, dynamic>> _allGovs = [];
  List<Map<String, dynamic>> _filteredGovs = [];
  List<Map<String, dynamic>> regions = [];
  List<Map<String, dynamic>> filteredRegions = [];
  Map<String, int> _usageCounts = {};

  final TextEditingController _govSearchController = TextEditingController();
  final TextEditingController _regionSearchController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    final current = AppLocationService().currentLocation;
    tempGovId = current.governorateId;
    tempGovName = current.governorateName;
    tempRegId = current.regionId;
    tempRegName = current.regionName;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _animController.forward();

    _loadGovernorates();

    if (tempGovId != null) {
      _showRegions = true;
      _fetchRegions(tempGovId!);
    }

    AppLocationService().addListener(_onLocationChanged);
    _govSearchController.addListener(_filterGovernorates);
    _regionSearchController.addListener(_filterRegions);
  }

  @override
  void dispose() {
    AppLocationService().removeListener(_onLocationChanged);
    _govSearchController.dispose();
    _regionSearchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onLocationChanged() {
    if (!mounted) return;
    final current = AppLocationService().currentLocation;
    setState(() {
      tempGovId = current.governorateId;
      tempGovName = current.governorateName;
      tempRegId = current.regionId;
      tempRegName = current.regionName;
      if (tempGovId != null) {
        _showRegions = true;
      }
    });
    if (tempGovId != null) _fetchRegions(tempGovId!);
  }

  // ──────────────────────────────────────────────
  // DATA LOADING
  // ──────────────────────────────────────────────

  Future<void> _loadGovernorates() async {
    if (!mounted) return;
    setState(() => isLoadingGovs = true);

    try {
      // Load usage counts first for smart sorting
      _usageCounts = await AppLocationService().getUsageCounts();

      final snap = await FirebaseFirestore.instance
          .collection('governorates')
          .where('isActive', isEqualTo: true)
          .get();

      final govs = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'بدون اسم',
          ...data,
        };
      }).toList();

      // Smart sort: usage frequency first, then alphabetical
      _smartSortGovernorates(govs);

      if (!mounted) return;
      setState(() {
        _allGovs = govs;
        _filteredGovs = govs;
        isLoadingGovs = false;
      });
    } catch (e) {
      debugPrint(' Error loading governorates: $e');
      if (mounted) setState(() => isLoadingGovs = false);
    }
  }

  void _smartSortGovernorates(List<Map<String, dynamic>> govs) {
    govs.sort((a, b) {
      final countA = _usageCounts[a['id']] ?? 0;
      final countB = _usageCounts[b['id']] ?? 0;

      // المحافظات الأكثر استخداماً أولاً
      if (countA != countB) return countB.compareTo(countA);

      // ثم الترتيب الأبجدي
      return (a['name'] ?? '').compareTo(b['name'] ?? '');
    });
  }

  void _filterGovernorates() {
    final query = _govSearchController.text.trim();

    if (query.isEmpty) {
      setState(() => _filteredGovs = _allGovs);
      return;
    }

    // Fuzzy search with scoring
    final scored = <MapEntry<Map<String, dynamic>, double>>[];
    for (final gov in _allGovs) {
      final name = gov['name']?.toString() ?? '';
      final score = AppLocationService.fuzzyMatchScore(query, name);
      if (score > 0.3) {
        scored.add(MapEntry(gov, score));
      }
    }

    // Sort by match score (best first)
    scored.sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _filteredGovs = scored.map((e) => e.key).toList();
    });
  }

  Future<void> _fetchRegions(String govId) async {
    if (!mounted) return;
    setState(() {
      isLoadingRegions = true;
      regions = [];
      filteredRegions = [];
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('governorates')
          .doc(govId)
          .collection('regions')
          .where('isActive', isEqualTo: true)
          .get();
      final docs = snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      docs.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      if (!mounted) return;
      setState(() {
        regions = docs;
        filteredRegions = docs;
        isLoadingRegions = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoadingRegions = false);
    }
  }

  void _filterRegions() {
    final query = _regionSearchController.text.trim();

    if (query.isEmpty) {
      setState(() => filteredRegions = regions);
      return;
    }

    // Fuzzy search with scoring
    final scored = <MapEntry<Map<String, dynamic>, double>>[];
    for (final region in regions) {
      final name = region['name']?.toString() ?? '';
      final score = AppLocationService.fuzzyMatchScore(query, name);
      if (score > 0.3) {
        scored.add(MapEntry(region, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      filteredRegions = scored.map((e) => e.key).toList();
    });
  }

  // ──────────────────────────────────────────────
  // ACTIONS
  // ──────────────────────────────────────────────

  Future<void> _detectLocation() async {
    if (!mounted) return;
    setState(() => isDetecting = true);
    HapticFeedback.mediumImpact();
    try {
      await AppLocationService().autoDetectLocation(context, true);
      if (mounted) {
        final loc = AppLocationService().currentLocation;
        if (loc.governorateId != null) {
          // GPS detected — auto-confirm and close
          HapticFeedback.heavyImpact();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تم تحديد موقعك: ${loc.displayName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                backgroundColor: app_colors.primaryColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 3),
              ),
            );
            Navigator.pop(context);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'عذراً، لم نتمكن من تحديد المحافظة. اختر يدوياً.',
                style: TextStyle(),
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e', style: const TextStyle()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isDetecting = false);
    }
  }

  void _selectGovernorate(String id, String name) {
    HapticFeedback.selectionClick();
    setState(() {
      tempGovId = id;
      tempGovName = name;
      tempRegId = null;
      tempRegName = null;
      _showRegions = true;
    });
    _regionSearchController.clear();
    _fetchRegions(id);
  }

  void _selectAllIraq() {
    HapticFeedback.selectionClick();
    setState(() {
      tempGovId = null;
      tempGovName = null;
      tempRegId = null;
      tempRegName = null;
      _showRegions = false;
      regions = [];
      filteredRegions = [];
    });
  }

  void _goBackToGovernorates() {
    HapticFeedback.selectionClick();
    setState(() {
      _showRegions = false;
      _regionSearchController.clear();
    });
  }

  void _confirm() {
    HapticFeedback.mediumImpact();
    AppLocationService().setLocation(
      governorateId: tempGovId,
      governorateName: tempGovName,
      regionId: tempRegId,
      regionName: tempRegName,
    );
    Navigator.pop(context);
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final primary = app_colors.primaryColor;

    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        height: size.height * 0.75,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151A1A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            _buildHeader(theme, isDark, primary),
            const SizedBox(height: 10),

            // GPS Button
            _buildGpsButton(isDark, primary),
            const SizedBox(height: 14),

            // Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutQuart,
                switchOutCurve: Curves.easeInQuart,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _showRegions
                    ? _buildRegionsStep(theme, isDark, primary)
                    : _buildGovernoratesStep(theme, isDark, primary),
              ),
            ),

            // Confirm Button
            _buildConfirmButton(primary, isDark),
          ],
        ),
      ),
    );
  }

  // ── HEADER ──
  Widget _buildHeader(ThemeData theme, bool isDark, Color primary) {
    final currentGovId = AppLocationService().currentLocation.governorateId;
    final hasCurrentLocation = currentGovId != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primary.withValues(alpha: 0.18),
                  primary.withValues(alpha: 0.06),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _showRegions ? Icons.map_rounded : Icons.location_on_rounded,
              color: primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _showRegions ? 'اختر المنطقة' : 'اختر المحافظة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (_showRegions && tempGovName != null)
                  Row(
                    children: [
                      Icon(Icons.location_city_rounded, size: 12, color: primary),
                      const SizedBox(width: 4),
                      Text(
                        tempGovName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else if (!_showRegions && hasCurrentLocation)
                  Row(
                    children: [
                      Icon(Icons.my_location_rounded, size: 11, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'الحالي: ${AppLocationService().currentLocation.displayName}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (_showRegions)
            IconButton(
              onPressed: _goBackToGovernorates,
              style: IconButton.styleFrom(
                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            )
          else
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: theme.hintColor, size: 20),
            ),
        ],
      ),
    );
  }

  // ── GPS BUTTON ──
  Widget _buildGpsButton(bool isDark, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDetecting ? null : _detectLocation,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primary.withValues(alpha: isDark ? 0.15 : 0.08),
                  primary.withValues(alpha: isDark ? 0.08 : 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.7)]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: isDetecting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.my_location_rounded, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDetecting ? 'جارِ تحديد الموقع...' : 'تحديد موقعي تلقائياً',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'يتم تحديد محافظتك ومنطقتك بدقة عالية',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── STEP 1: GOVERNORATES GRID ──
  Widget _buildGovernoratesStep(ThemeData theme, bool isDark, Color primary) {
    return Padding(
      key: const ValueKey('governorates_step'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Search field for governorates
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
            ),
            child: TextField(
              controller: _govSearchController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ابحث عن محافظتك...',
                hintStyle: TextStyle(fontSize: 13, color: theme.hintColor),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: primary),
                suffixIcon: _govSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _govSearchController.clear();
                          setState(() => _filteredGovs = _allGovs);
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Govs grid
          Expanded(
            child: isLoadingGovs
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: primary),
                        const SizedBox(height: 12),
                        Text(
                          'جارِ تحميل المحافظات...',
                          style: TextStyle(fontSize: 13, color: theme.hintColor),
                        ),
                      ],
                    ),
                  )
                : _filteredGovs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 40, color: theme.hintColor.withValues(alpha: 0.3)),
                            const SizedBox(height: 8),
                            Text(
                              'لا توجد محافظة تطابق بحثك',
                              style: TextStyle(fontSize: 13, color: theme.hintColor),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.05,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _filteredGovs.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildGovCard(
                              icon: Icons.public_rounded,
                              label: 'كل العراق',
                              isSelected: tempGovId == null,
                              onTap: _selectAllIraq,
                              color: const Color(0xFF607D8B),
                              isDark: isDark,
                              usageCount: 0,
                              isCurrent: AppLocationService().currentLocation.isAllIraq && tempGovId == null,
                            );
                          }

                          final gov = _filteredGovs[index - 1];
                          final govId = gov['id'] as String;
                          final govName = gov['name'] as String;
                          final isSelected = tempGovId == govId;
                          final isCurrent = AppLocationService().currentLocation.governorateId == govId;
                          final usageCount = _usageCounts[govId] ?? 0;

                          final colors = [
                            primary,
                            const Color(0xFF7E57C2),
                            const Color(0xFFF9A825),
                            const Color(0xFFFF7043),
                            const Color(0xFF26A69A),
                            const Color(0xFFEC407A),
                            const Color(0xFF42A5F5),
                            const Color(0xFF8D6E63),
                          ];
                          final cardColor = colors[(index - 1) % colors.length];

                          return _buildGovCard(
                            icon: Icons.location_city_rounded,
                            label: govName,
                            isSelected: isSelected,
                            onTap: () => _selectGovernorate(govId, govName),
                            color: cardColor,
                            isDark: isDark,
                            usageCount: usageCount,
                            isCurrent: isCurrent,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildGovCard({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
    required bool isDark,
    required int usageCount,
    required bool isCurrent,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutQuart,
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? color : isCurrent ? Colors.green.withValues(alpha: 0.5) : (isDark ? Colors.white12 : Colors.grey.shade200),
            width: isSelected ? 2 : isCurrent ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            // Current location badge
            if (isCurrent && !isSelected)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 8),
                ),
              ),
            // Usage badge
            if (usageCount > 2 && !isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '',
                    style: TextStyle(fontSize: 8, color: Colors.amber.shade100),
                  ),
                ),
              ),
            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: isSelected ? Colors.white : color, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP 2: REGIONS LIST ──
  Widget _buildRegionsStep(ThemeData theme, bool isDark, Color primary) {
    return Padding(
      key: const ValueKey('regions_step'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Search field
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
            ),
            child: TextField(
              controller: _regionSearchController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ابحث عن منطقتك...',
                hintStyle: TextStyle(fontSize: 13, color: theme.hintColor),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: primary),
                suffixIcon: _regionSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _regionSearchController.clear();
                          setState(() => filteredRegions = regions);
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Region count badge
          if (!isLoadingRegions && regions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${filteredRegions.length} منطقة',
                      style: TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // "All regions" chip
          _buildRegionTile(
            name: 'كل المناطق في $tempGovName',
            isSelected: tempRegId == null,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                tempRegId = null;
                tempRegName = null;
              });
            },
            icon: Icons.layers_rounded,
            theme: theme,
            isDark: isDark,
            primary: primary,
          ),
          const SizedBox(height: 8),

          // Regions list
          Expanded(
            child: isLoadingRegions
                ? Center(child: CircularProgressIndicator(color: primary))
                : filteredRegions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_off_rounded,
                              size: 40,
                              color: theme.hintColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'لا توجد مناطق تطابق بحثك',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredRegions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final region = filteredRegions[index];
                          final regionId = region['id'] as String?;
                          final isSelected = tempRegId == regionId;
                          final isCurrent = AppLocationService().currentLocation.regionId == regionId;
                          return _buildRegionTile(
                            name: region['name'] ?? '',
                            isSelected: isSelected,
                            isCurrent: isCurrent,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                tempRegId = isSelected ? null : region['id'];
                                tempRegName = isSelected ? null : region['name'];
                              });
                            },
                            theme: theme,
                            isDark: isDark,
                            primary: primary,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionTile({
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDark,
    required Color primary,
    IconData? icon,
    bool isCurrent = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? primary.withValues(alpha: isDark ? 0.2 : 0.08)
                : isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? primary.withValues(alpha: 0.4)
                  : isCurrent
                      ? Colors.green.withValues(alpha: 0.4)
                      : isDark
                          ? Colors.white10
                          : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: primary),
                const SizedBox(width: 10),
              ],
              if (isCurrent && !isSelected) ...[
                Icon(Icons.my_location_rounded, size: 14, color: Colors.green.shade600),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                    color: isSelected
                        ? primary
                        : isDark
                            ? Colors.white70
                            : Colors.black87,
                  ),
                ),
              ),
              if (isCurrent && !isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'موقعك',
                    style: TextStyle(fontSize: 9, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isSelected
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('checked'),
                        color: primary,
                        size: 22,
                      )
                    : Icon(
                        Icons.circle_outlined,
                        key: const ValueKey('unchecked'),
                        color: theme.hintColor.withValues(alpha: 0.3),
                        size: 20,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CONFIRM BUTTON ──
  Widget _buildConfirmButton(Color primary, bool isDark) {
    final hasSelection = tempGovId != null || tempGovName == null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A1A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: hasSelection ? _confirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: primary.withValues(alpha: 0.3),
            elevation: 4,
            shadowColor: primary.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_rounded, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  tempGovId == null
                      ? 'عرض كل العراق'
                      : 'تأكيد — ${tempGovName ??''}${tempRegName != null ? ' / $tempRegName' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
