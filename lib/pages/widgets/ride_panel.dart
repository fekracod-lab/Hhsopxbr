import 'package:flutter/material.dart';
// للتأكد من توافق الأنواع إذا لزم الأمر

// ============================================================================
// لوحة الألوان الموحدة (Matching Search Screen)
// ============================================================================
const Color primaryColor = Color(0xFF26A69A);
const Color accentColor = Color(0xFF00796B);
const Color textColor = Color(0xFF333333);
const Color subTextColor = Color(0xFF757575);
const Color surfaceColor = Color(0xFFF8F9FA);

// استيراد الموديلات (تأكد من مطابقة المسارات في مشروعك)
// import 'package:dalal_alqaim/models/ride_type.dart';
// import 'package:dalal_alqaim/constants/ride_constants.dart';

class RidePanel extends StatelessWidget {
  final bool showRidePanel;
  final String pickupAddress;
  final String dropoffAddress;
  final double? tripDistanceKm;
  final int? tripDurationMin;
  final dynamic selectedRideType; // استبداله بـ RideType إذا كان متوفراً
  final List<dynamic>? rideTypes;
  final bool isCreatingRide;
  final bool isLoadingRoute;
  final Function(dynamic) onRideTypeSelected;
  final VoidCallback onOpenSearch;
  final VoidCallback onConfirmRide;

  const RidePanel({
    super.key,
    required this.showRidePanel,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.tripDistanceKm,
    required this.tripDurationMin,
    required this.selectedRideType,
    this.rideTypes,
    required this.isCreatingRide,
    required this.isLoadingRoute,
    required this.onRideTypeSelected,
    required this.onOpenSearch,
    required this.onConfirmRide,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
      child: showRidePanel ? _buildDraggableConfirmPanel(context) : _buildSearchPanel(context),
    );
  }

  // ==========================================================================
  // 1. لوحة البحث الأولية
  // ==========================================================================
  Widget _buildSearchPanel(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        key: const ValueKey('search_panel'),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 35),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.only(bottom: 20)),
            
            // موقع الانطلاق (عرض فقط)
            Row(
              children: [
                const Icon(Icons.my_location_rounded, color: primaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pickupAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: subTextColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            
            // زر البحث (إلى أين؟)
            InkWell(
              onTap: onOpenSearch,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1), // Teal tint
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, color: primaryColor),
                    SizedBox(width: 12),
                    Text(
                      "إلى أين تريد الذهاب؟",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: accentColor),
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

  // ==========================================================================
  // 2. لوحة تأكيد الرحلة (Draggable)
  // ==========================================================================
  Widget _buildDraggableConfirmPanel(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              key: const ValueKey('confirm_panel'),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, -10)),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 15),
                  
                  // مسار الرحلة (From -> To)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildRoutePreview(),
                  ),
                  
                  const Divider(height: 30, thickness: 0.5),

                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _buildTripStats(),
                        const SizedBox(height: 20),
                        const Text("اختر نوع السيارة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        const SizedBox(height: 12),
                        _buildRideTypesList(),
                        const SizedBox(height: 100), // مساحة للزر الثابت
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        _buildFixedConfirmButton(),
      ],
    );
  }

  Widget _buildRoutePreview() {
    return Row(
      children: [
        Column(
          children: [
            const Icon(Icons.circle, size: 10, color: primaryColor),
            Container(width: 2, height: 25, color: Colors.grey[200]),
            const Icon(Icons.location_on, size: 18, color: Colors.redAccent),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: subTextColor)),
              const SizedBox(height: 15),
              Text(dropoffAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
        ),
        IconButton(onPressed: onOpenSearch, icon: const Icon(Icons.edit_location_alt_rounded, color: primaryColor, size: 20)),
      ],
    );
  }

  Widget _buildTripStats() {
    if (tripDistanceKm == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.route_outlined, "${tripDistanceKm!.toStringAsFixed(1)} كم", "المسافة"),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          _buildStatItem(Icons.access_time_rounded, "$tripDurationMin دقيقة", "الوقت المتوقع"),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: primaryColor),
            const SizedBox(width: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
          ],
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: subTextColor)),
      ],
    );
  }

  Widget _buildRideTypesList() {
    final list = rideTypes ?? []; // افترض وجود قائمة افتراضية إذا كانت null
    return Column(
      children: list.map((type) {
        final isSelected = selectedRideType.id == type.id;
        // حساب السعر (تقريب لأقرب 250 دينار عراقي)
        double rawPrice = type.baseFare + ((tripDistanceKm ?? 0) * type.pricePerKm);
        double price = (rawPrice / 250).round() * 250.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => onRideTypeSelected(type),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade200, width: isSelected ? 2 : 1),
                boxShadow: isSelected ? [BoxShadow(color: primaryColor.withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 8))] : [],
              ),
              child: Row(
                children: [
                  _buildRideIcon(type.id, isSelected),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        Text(type.desc, style: const TextStyle(fontSize: 11, color: subTextColor)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("${price.toInt()} د.ع", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isSelected ? primaryColor : textColor)),
                      if (isSelected) const Text("أفضل سعر", style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRideIcon(String id, bool isSelected) {
    IconData iconData;
    switch (id) {
      case 'saver': iconData = Icons.directions_car_filled_rounded; break;
      case 'comfort': iconData = Icons.local_taxi_rounded; break;
      case 'family': iconData = Icons.airport_shuttle_rounded; break;
      default: iconData = Icons.directions_car_rounded;
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: isSelected ? primaryColor.withValues(alpha: 0.1) : Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Icon(iconData, color: isSelected ? primaryColor : subTextColor, size: 28),
    );
  }

  Widget _buildFixedConfirmButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withValues(alpha: 0), Colors.white]),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton(
          onPressed: (isCreatingRide || isLoadingRoute) ? null : onConfirmRide,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 8,
            shadowColor: primaryColor.withValues(alpha: 0.4),
          ),
          child: isCreatingRide 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("تأكيد طلب ${selectedRideType.title}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
        ),
      ),
    );
  }
}
