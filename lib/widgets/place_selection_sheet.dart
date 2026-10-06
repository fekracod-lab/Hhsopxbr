import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/parcel_delivery_controller.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import '../models/place_data.dart';

class PlaceSelectionSheet extends StatefulWidget {
  const PlaceSelectionSheet({super.key});

  @override
  State<PlaceSelectionSheet> createState() => _PlaceSelectionSheetState();
}

class _PlaceSelectionSheetState extends State<PlaceSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ParcelDeliveryController>();
    final places = controller.state.filteredNearbyPlaces;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: app_colors.darkBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildDragHandle(),
          _buildHeader(),
          const SizedBox(height: 16),
          _buildSearchBar(controller),
          const SizedBox(height: 16),
          _buildMapSelectionOption(context, controller),
          const SizedBox(height: 8),
          const Divider(color: app_colors.darkBorder),
          const SizedBox(height: 8),
          Expanded(
            child:
                places.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                      itemCount: places.length,
                      separatorBuilder:
                          (_, __) => Divider(color: app_colors.darkBorder.withValues(alpha: 0.5)),
                      itemBuilder:
                          (context, index) => _buildPlaceItem(context, controller, places[index]),
                    ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: app_colors.darkSubText.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return const Text(
      'اختر وجهة التسليم',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: app_colors.darkText,
      ),
    );
  }

  Widget _buildSearchBar(ParcelDeliveryController controller) {
    return TextField(
      controller: _searchController,
      onChanged: (value) => controller.updateSearch(value),
      decoration: InputDecoration(
        hintText: 'ابحث عن مكان...',
        prefixIcon: const Icon(Icons.search, color: app_colors.darkSubText),
        filled: true,
        fillColor: app_colors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon:
            _searchController.text.isNotEmpty
                ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    controller.updateSearch('');
                  },
                )
                : null,
      ),
    );
  }

  Widget _buildMapSelectionOption(BuildContext context, ParcelDeliveryController controller) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: app_colors.primaryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.map_outlined, color: app_colors.primaryColor, size: 22),
      ),
      title: const Text(
        'تحديد الوجهة عبر الخريطة',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: app_colors.primaryColor,
        ),
      ),
      subtitle: const Text(
        'قم بتحريك الدبوس على الخريطة لتحديد الموقع بدقة',
        style: TextStyle(fontSize: 11, color: app_colors.darkSubText),
      ),
      trailing: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: app_colors.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.arrow_forward_ios, size: 12, color: app_colors.primaryColor),
      ),
      onTap: () {
        // Close PlaceSelectionSheet
        Navigator.pop(context);
        // Close ParcelRequestFormSheet
        Navigator.pop(context);
        // Enter map selection mode
        controller.toggleMapSelectionMode(true);
      },
    );
  }

  Widget _buildPlaceItem(
    BuildContext context,
    ParcelDeliveryController controller,
    PlaceData place,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: app_colors.primaryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.location_on, color: app_colors.primaryColor, size: 20),
      ),
      title: Text(
        place.name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: app_colors.darkText,
        ),
      ),
      subtitle: Text(
        place.address,
        style: const TextStyle(fontSize: 12, color: app_colors.darkSubText),
      ),
      onTap: () {
        controller.setDropoff(place.position, place.name);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: app_colors.darkSubText.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'لم يتم العثور على نتائج',
            style: TextStyle(color: app_colors.darkSubText),
          ),
        ],
      ),
    );
  }
}
