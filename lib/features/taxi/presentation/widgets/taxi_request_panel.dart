import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dalal_alqaim/pages/search_screen.dart';
import 'package:dalal_alqaim/features/taxi/presentation/controller/taxi_controller.dart';
import 'package:dalal_alqaim/features/taxi/presentation/controller/taxi_ui_state.dart';
import 'package:shimmer/shimmer.dart';
import 'package:dalal_alqaim/trip_screen.dart';
import 'package:dalal_alqaim/models/ride_type.dart';
import 'package:dalal_alqaim/models/route_option.dart';

// ============================================================================
// تصميم مبسط وأنيق (Minimalist Theme)
// ============================================================================
const Color kPrimaryColor = Color(0xFF26A69A);
const Color kSurfaceColor = Colors.white;
const Color kBackgroundColor = Color(0xFFF2F4F6);
const double kPanelRadius = 24.0;
const double kCompactPadding = 16.0;

class TaxiRequestPanel extends StatelessWidget {
  const TaxiRequestPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<TaxiController, TaxiViewStatus>(
      selector: (_, controller) => controller.state.status,
      builder: (context, status, child) {
        final bool isCalculating = status == TaxiViewStatus.calculating;
        final bool isReadyOrRequesting =
            status == TaxiViewStatus.ready || status == TaxiViewStatus.requesting;

        return Container(
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(kPanelRadius)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _DragHandle(),
              const _ErrorMessageBanner(),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    kCompactPadding,
                    0,
                    kCompactPadding,
                    kCompactPadding + 10,
                  ),
                  child: Column(
                    children: [
                      if (isCalculating)
                        const _CompactSkeletonLoader()
                      else ...[
                        const _CompactLocationSection(),
                        const SizedBox(height: 12),
                        if (isReadyOrRequesting) ...[
                          const _RideSelectionSection(),
                          const SizedBox(height: 12),
                          const _TimeSelectionRow(),
                        ] else
                          const _QuickActionsRow(),
                        const SizedBox(height: 16),
                        const _MainActionButton(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// قسم الموقع (تصميم بريميوم مع خط زمني)
// -----------------------------------------------------------------------------
class _CompactLocationSection extends StatelessWidget {
  const _CompactLocationSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── خط الزمني (Timeline Rail) ──
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                _buildDot(kPrimaryColor),
                ..._buildDashes(5),
                _buildDot(const Color(0xFFEF5350)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── محتوى المواقع ──
          Expanded(
            child: Column(
              children: [
                // نقطة الانطلاق
                Selector<TaxiController, String>(
                  selector: (_, c) => c.state.pickupAddress,
                  builder:
                      (_, address, __) => _LocationTile(
                        label: 'مكان الصعدة',
                        address: address,
                        icon: Icons.my_location_rounded,
                        accentColor: kPrimaryColor,
                        isReadOnly: true,
                      ),
                ),
                // فاصل مع سهم
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                kPrimaryColor.withValues(alpha: 0.15),
                                Colors.redAccent.withValues(alpha: 0.15),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      Expanded(child: Container(height: 1, color: Colors.grey.shade100)),
                    ],
                  ),
                ),
                // نقطة الوصول
                Selector<TaxiController, String>(
                  selector: (_, c) => c.state.dropoffAddress,
                  builder:
                      (context, address, __) => _LocationTile(
                        label: 'مكان النزلة',
                        address: address.isEmpty ? 'وين رايح عيوني؟' : address,
                        icon: Icons.location_on_rounded,
                        accentColor: const Color(0xFFEF5350),
                        isPlaceholder: address.isEmpty,
                        onTap: () => _openSearch(context, context.read<TaxiController>()),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, spreadRadius: 1)],
      ),
      child: Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        ),
      ),
    );
  }

  List<Widget> _buildDashes(int count) {
    return List.generate(
      count,
      (i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Container(
          width: 2,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final String label;
  final String address;
  final IconData icon;
  final Color accentColor;
  final bool isReadOnly;
  final bool isPlaceholder;
  final VoidCallback? onTap;

  const _LocationTile({
    required this.label,
    required this.address,
    required this.icon,
    required this.accentColor,
    this.isReadOnly = false,
    this.isPlaceholder = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: accentColor.withValues(alpha: 0.08),
        highlightColor: accentColor.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withValues(alpha: 0.12),
                      accentColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: accentColor.withValues(alpha: 0.8),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                        fontSize: 12.5,
                        fontWeight: isPlaceholder ? FontWeight.normal : FontWeight.w600,
                        color: isPlaceholder ? Colors.grey.shade400 : const Color(0xFF2D2D2D),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isReadOnly)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.search_rounded, size: 14, color: accentColor),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// الإجراءات السريعة (Chips)
// -----------------------------------------------------------------------------
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final controller = context.read<TaxiController>();
    return Row(
      children: [
        Expanded(
          child: Selector<TaxiController, String?>(
            selector: (_, c) => c.state.homeAddress,
            builder:
                (_, address, __) => _CompactChip(
                  icon: Icons.home_filled,
                  label: "البيت",
                  hasValue: address != null && address.isNotEmpty,
                  onTap: () => controller.useQuickAction(true),
                  onLongPress: () => _openSearch(context, controller, isHome: true),
                ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Selector<TaxiController, String?>(
            selector: (_, c) => c.state.workAddress,
            builder:
                (_, address, __) => _CompactChip(
                  icon: Icons.work_rounded,
                  label: "الدوام",
                  hasValue: address != null && address.isNotEmpty,
                  onTap: () => controller.useQuickAction(false),
                  onLongPress: () => _openSearch(context, controller, isWork: true),
                ),
          ),
        ),
      ],
    );
  }
}

class _CompactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasValue;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CompactChip({
    required this.icon,
    required this.label,
    required this.hasValue,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: hasValue ? onTap : onLongPress,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: hasValue ? kPrimaryColor : Colors.grey),
            const SizedBox(width: 6),
            Text(
              hasValue ? label : "ضيف $label",
              style: TextStyle(
                fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: hasValue ? const Color(0xFF333333) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// اختيار نوع الرحلة (Premium Horizontal Cards)
// -----------------------------------------------------------------------------

const Map<String, List<Color>> _rideTypeGradients = {
  'saver': [Color(0xFF00BFA5), Color(0xFF00796B)],
  'comfort': [Color(0xFF448AFF), Color(0xFF2962FF)],
  'family': [Color(0xFFFF9100), Color(0xFFFF6D00)],
};

class _RideSelectionSection extends StatelessWidget {
  const _RideSelectionSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _RouteSelectionRow(),
        const SizedBox(height: 14),
        const _PassengerCountSelector(),
        const _CompactTripStats(),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'اختار نوع السيارة اللي تناسبك',
                style: TextStyle(
                  fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 135,
          child: Selector<TaxiController, List<dynamic>>(
            selector: (_, c) => c.state.rideTypes,
            builder: (context, rideTypes, child) {
              final list = rideTypes.isNotEmpty ? rideTypes : RideTypes.list;
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) => _RideTypeCard(type: list[index], index: index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RouteSelectionRow extends StatelessWidget {
  const _RouteSelectionRow();

  @override
  Widget build(BuildContext context) {
    return Selector<TaxiController, List<RouteOption>>(
      selector: (_, c) => c.state.routeAlternatives,
      builder: (context, alternatives, child) {
        if (alternatives.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'اختار الدرب اللي يعجبك',
                    style: TextStyle(
                      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: alternatives.map((route) => _RouteOptionCard(route: route)).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RouteOptionCard extends StatelessWidget {
  final RouteOption route;
  const _RouteOptionCard({required this.route});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<TaxiController>();
    return Selector<TaxiController, RouteOption?>(
      selector: (_, c) => c.state.selectedRoute,
      builder: (context, selectedRoute, child) {
        final isSelected = selectedRoute == route;
        final color = _getTagColor(route.tag);

        return GestureDetector(
          onTap: () => controller.selectRoute(route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(left: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade200,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getTagIcon(route.tag), size: 16, color: color),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getRouteLabel(route),
                      style: TextStyle(
                        fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? color : const Color(0xFF333333),
                      ),
                    ),
                    Text(
                      "${route.distanceKm.toStringAsFixed(1)} كم • ${route.durationMin} د",
                      style: TextStyle(
                        fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getRouteLabel(RouteOption r) {
    switch (r.tag) {
      case 'fastest_cheapest':
        return 'أسرع وأوفر درب';
      case 'fastest':
        return 'الدرب الأسرع';
      case 'cheapest':
        return 'الدرب الأوفر';
      case 'shortest':
        return 'أقصر طريق';
      default:
        return r.label.isNotEmpty ? r.label : 'طريق ثاني';
    }
  }

  Color _getTagColor(String tag) {
    switch (tag) {
      case 'fastest':
      case 'fastest_cheapest':
        return const Color(0xFF2E7D32);
      case 'cheapest':
        return const Color(0xFF1976D2);
      case 'shortest':
        return const Color(0xFFF9A825);
      default:
        return kPrimaryColor;
    }
  }

  IconData _getTagIcon(String tag) {
    switch (tag) {
      case 'fastest':
      case 'fastest_cheapest':
        return Icons.flash_on_rounded;
      case 'cheapest':
        return Icons.sell_rounded;
      case 'shortest':
        return Icons.straighten_rounded;
      default:
        return Icons.route_rounded;
    }
  }
}

class _PassengerCountSelector extends StatelessWidget {
  const _PassengerCountSelector();

  @override
  Widget build(BuildContext context) {
    final controller = context.read<TaxiController>();
    return Selector<TaxiController, List<dynamic>>(
      selector: (_, c) => [c.state.distanceKm, c.state.passengerCount],
      builder: (context, data, _) {
        final distanceKm = data[0] as double? ?? 0;
        final selectedCount = data[1] as int;

        if (distanceKm < 30) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'نظام النفرات أو سيارة كاملة للبعيد',
                    style: TextStyle(
                      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CountChip(
                    label: 'السيارة كلها إلك',
                    count: 0,
                    isSelected: selectedCount == 0,
                    onTap: () => controller.setPassengerCount(0),
                  ),
                  const SizedBox(width: 8),
                  for (int i = 1; i <= 4; i++) ...[
                    _CountChip(
                      label: '$i نفرات ',
                      count: i,
                      isSelected: selectedCount == i,
                      onTap: () => controller.setPassengerCount(i),
                    ),
                    if (i < 4) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CountChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? kPrimaryColor : Colors.grey.shade300, width: 1.5),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: kPrimaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }
}

class _CompactTripStats extends StatelessWidget {
  const _CompactTripStats();

  @override
  Widget build(BuildContext context) {
    return Consumer<TaxiController>(
      builder: (_, controller, __) {
        final state = controller.state;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatBadge(
              icon: Icons.route_rounded,
              text: "${state.distanceKm?.toStringAsFixed(1) ?? 0} كم",
            ),
            const SizedBox(width: 12),
            _StatBadge(icon: Icons.access_time_rounded, text: "${state.durationMin ?? 0} دقيقة تقريباً "),
          ],
        );
      },
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StatBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: kPrimaryColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF444444),
            ),
          ),
        ],
      ),
    );
  }
}

class _RideTypeCard extends StatelessWidget {
  final dynamic type;
  final int index;
  const _RideTypeCard({required this.type, required this.index});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<TaxiController>();

    return Selector<TaxiController, List<dynamic>>(
      selector:
          (_, c) => [
            c.state.selectedRideType,
            c.state.distanceKm,
            c.state.durationMin,
            c.state.passengerCount,
          ],
      builder: (context, data, _) {
        final selectedType = data[0];
        final isSelected = selectedType?.id == type.id;
        final price = controller.calculatePriceForType(type).toInt();
        final String typeId = type.id ?? 'saver';
        final gradientColors = _rideTypeGradients[typeId] ?? [kPrimaryColor, kPrimaryColor];

        return GestureDetector(
          onTap: () => controller.selectRideType(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: 120,
            margin: EdgeInsets.only(left: index < 2 ? 10 : 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient:
                  isSelected
                      ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      )
                      : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: gradientColors[0].withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                      : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: _buildRideTypeImage(type, isSelected),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Colors.white.withValues(alpha: 0.2) 
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 11,
                            color: isSelected ? Colors.white : Colors.grey[600],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${type.capacity ?? 4}',
                            style: TextStyle(
                              fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getIraqiRideTitle(type),
                      style: TextStyle(
                        fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF2D3436),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$price د.ع",
                          style: TextStyle(
                            fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isSelected 
                                ? Colors.white.withValues(alpha: 0.95) 
                                : gradientColors[1],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.white,
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getIraqiRideTitle(dynamic type) {
    final id = type.id?.toString() ?? '';
    if (id == 'saver') return 'اقتصادية';
    if (id == 'comfort' || id == 'premium') return 'بريميوم';
    if (id == 'family') return 'عائلية';
    return type.title?.toString() ?? 'تكسي';
  }

  Widget _buildRideTypeImage(dynamic type, bool isSelected) {
    String? path;
    try {
      path = type.imageUrl;
      if (path == null || path.isEmpty) {
        path = type.image;
      }
    } catch (_) {}

    if (path == null || path.isEmpty) {
      path = 'assets/cars/standard.png';
    }

    return Image.asset(
      path,
      width: 80,
      height: 50,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.directions_car, 
          size: 24, 
          color: isSelected ? Colors.white : Colors.grey,
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// الزر الرئيسي
// -----------------------------------------------------------------------------
class _MainActionButton extends StatelessWidget {
  const _MainActionButton();

  @override
  Widget build(BuildContext context) {
    return Selector<TaxiController, TaxiUiState>(
      selector: (_, c) => c.state,
      builder: (context, state, _) {
        final controller = context.read<TaxiController>();
        final bool isDropoffSelected = state.dropoffAddress.isNotEmpty;
        final bool isReady = state.status == TaxiViewStatus.ready;
        final bool isLoading = state.status == TaxiViewStatus.requesting;

        String label = "اختار وين رايح عيوني";
        VoidCallback? onTap;

        if (state.isSavingHome) {
          label = "احفظ البيت";
          onTap = isDropoffSelected ? () => controller.confirmDropoff() : null;
        } else if (state.isSavingWork) {
          label = "احفظ الدوام";
          onTap = isDropoffSelected ? () => controller.confirmDropoff() : null;
        } else if (state.status == TaxiViewStatus.idle ||
            state.status == TaxiViewStatus.selectingDropoff) {
          label = "ثبّت المكان واطلب التكسي";
          onTap = isDropoffSelected ? () => controller.confirmDropoff() : null;
        } else if (isReady) {
          label = "اطلب التكسي هسة";
          onTap = () async {
            final rideId = await controller.submitRideRequest();
            if (rideId != null && context.mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => TripScreen(rideId: rideId)),
              );
            }
          };
        }

        return SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child:
                isLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                    : Text(
                      label,
                      style: TextStyle(
                        fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// اختيار وقت الرحلة (مجدول / الآن)
// -----------------------------------------------------------------------------
class _TimeSelectionRow extends StatelessWidget {
  const _TimeSelectionRow();

  @override
  Widget build(BuildContext context) {
    return Selector<TaxiController, DateTime?>(
      selector: (_, c) => c.state.scheduledTime,
      builder: (context, scheduledTime, _) {
        final controller = context.read<TaxiController>();
        final isNow = scheduledTime == null;

        return Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => controller.setScheduledTime(null),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isNow ? kPrimaryColor.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isNow ? kPrimaryColor : Colors.grey.shade300, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt_rounded, size: 18, color: isNow ? kPrimaryColor : Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'هسة',
                        style: TextStyle(
                          fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isNow ? kPrimaryColor : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  final date = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 7)),
                  );
                  if (date != null && context.mounted) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (!context.mounted) return;
                    if (time != null) {
                      final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      if (selected.isAfter(now)) {
                        controller.setScheduledTime(selected);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'اختار وقت قادم عيوني',
                              style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily),
                            ),
                          ),
                        );
                      }
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: !isNow ? kPrimaryColor.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: !isNow ? kPrimaryColor : Colors.grey.shade300, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 18, color: !isNow ? kPrimaryColor : Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        !isNow 
                          ? '${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}'
                          : 'احجز لوقت ثاني',
                        style: TextStyle(
                          fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: !isNow ? kPrimaryColor : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// مكونات مساعدة
// -----------------------------------------------------------------------------

class _DragHandle extends StatelessWidget {
  const _DragHandle();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ErrorMessageBanner extends StatelessWidget {
  const _ErrorMessageBanner();
  @override
  Widget build(BuildContext context) {
    return Selector<TaxiController, String?>(
      selector: (_, c) => c.state.errorMessage,
      builder: (_, msg, __) {
        if (msg == null) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: Colors.red.shade50,
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 8),
          child: Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.red.shade800,
              fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
            ),
          ),
        );
      },
    );
  }
}

class _CompactSkeletonLoader extends StatelessWidget {
  const _CompactSkeletonLoader();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[200]!,
      highlightColor: Colors.grey[50]!,
      child: Container(
        height: 120,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

void _openSearch(
  BuildContext context,
  TaxiController controller, {
  bool isHome = false,
  bool isWork = false,
}) async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const SearchScreen()),
  );
  if (result != null && result is Map) {
    final lat = result['lat'];
    final lng = result['lng'];
    final address = result['address'];
    if (lat != null && lng != null) {
      final location = LatLng(lat, lng);
      final addrStr = address?.toString() ?? 'مكان مختار';
      if (isHome) {
        controller.saveQuickLocation(true, location, addrStr);
      } else if (isWork) {
        controller.saveQuickLocation(false, location, addrStr);
      } else {
        controller.setDropoff(location, addrStr);
      }
    }
  }
}
