import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:dalal_alqaim/controllers/parcel_delivery_controller.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/widgets/parcel_map_widget.dart';
import 'package:dalal_alqaim/widgets/active_shipments_strip.dart';
import 'package:dalal_alqaim/widgets/parcel_request_form_sheet.dart';
import 'package:dalal_alqaim/widgets/place_card.dart';
import 'package:dalal_alqaim/widgets/loading_shimmer.dart';
import 'package:dalal_alqaim/widgets/error_retry_widget.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/parcel_tracking_page.dart';

class ParcelDeliveryRequestPage extends StatelessWidget {
  const ParcelDeliveryRequestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ParcelDeliveryController()..init(context),
      child: const ParcelDeliveryRequestView(),
    );
  }
}

class ParcelDeliveryRequestView extends StatefulWidget {
  const ParcelDeliveryRequestView({super.key});

  @override
  State<ParcelDeliveryRequestView> createState() => _ParcelDeliveryRequestViewState();
}

class _ParcelDeliveryRequestViewState extends State<ParcelDeliveryRequestView> {
  GoogleMapController? _mapController;
  final ScrollController _scrollController = ScrollController();
  bool _isFabVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final scrollOffset = _scrollController.offset;
    final isVisible = scrollOffset < 100;
    if (_isFabVisible != isVisible) {
      setState(() {
        _isFabVisible = isVisible;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ParcelDeliveryController>(
      builder: (context, controller, child) {
        final isSelectionMode = controller.state.isMapSelectionMode;
        return Scaffold(
          backgroundColor: app_colors.darkBackground,
          body: _buildBody(),
          floatingActionButton: isSelectionMode ? null : _buildFloatingActionButton(),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  Widget _buildBody() {
    return Consumer<ParcelDeliveryController>(
      builder: (context, controller, child) {
        if (controller.state.errorMessage != null && controller.state.nearbyPlaces.isEmpty) {
          return ErrorRetryWidget(
            error: controller.state.errorMessage!,
            onRetry: () => controller.init(context),
          );
        }

        return CustomScrollView(
          controller: _scrollController,
          physics:
              controller.state.isMapSelectionMode
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(context, controller),
            if (!controller.state.isMapSelectionMode) _buildSliverShipments(),
            if (!controller.state.isMapSelectionMode) _buildMainContent(context),
          ],
        );
      },
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context, ParcelDeliveryController controller) {
    final isSelectionMode = controller.state.isMapSelectionMode;
    return SliverAppBar(
      expandedHeight: isSelectionMode ? MediaQuery.of(context).size.height : 280,
      pinned: true,
      elevation: 0,
      backgroundColor: app_colors.darkSurface,
      leading: isSelectionMode ? _buildMapSelectionBackButton(controller) : _buildBackButton(),
      flexibleSpace: _buildFlexibleSpace(controller),
      title: Text(
        isSelectionMode ? 'حدد وجهة التوصيل' : 'توصيل الطرود',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: app_colors.darkText,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildMapSelectionBackButton(ParcelDeliveryController controller) {
    return IconButton(
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: app_colors.darkSurface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.close, color: app_colors.darkText, size: 20),
      ),
      onPressed: () => controller.toggleMapSelectionMode(false),
    );
  }

  Widget _buildSliverShipments() {
    return SliverToBoxAdapter(
      child: Container(
        color: app_colors.darkBackground,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'شحناتك الحالية',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: app_colors.darkText,
                ),
              ),
              const SizedBox(height: 12),
              ActiveShipmentsStrip(
                onTrackPressed: (shipmentId) => _navigateToTracking(context, shipmentId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: app_colors.darkSurface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.arrow_back_ios_new, color: app_colors.darkText, size: 18),
      ),
      onPressed: () => Navigator.pop(context),
    );
  }

  Widget _buildFlexibleSpace(ParcelDeliveryController controller) {
    final isSelectionMode = controller.state.isMapSelectionMode;
    return FlexibleSpaceBar(
      background: Stack(
        children: [
          ParcelMapWidget(
            mapController: _mapController,
            onLocationSelected: (loc) {
              controller.setDropoff(loc, "موقع محدد على الخريطة");
              _showRequestForm(context);
            },
          ),
          if (!isSelectionMode)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    app_colors.darkBackground.withValues(alpha: 0.95),
                    Colors.transparent,
                    Colors.transparent,
                    app_colors.darkBackground.withValues(alpha: 0.3),
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          Positioned(
            top: isSelectionMode ? 100 : 70,
            left: 20,
            right: 20,
            child: isSelectionMode ? _buildMapAddressCard(controller) : _buildSearchBar(),
          ),
          if (isSelectionMode)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: _buildConfirmLocationButton(controller),
            ),
        ],
      ),
    );
  }

  Widget _buildMapAddressCard(ParcelDeliveryController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: app_colors.darkCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: app_colors.primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              controller.state.dropoffName,
              style: const TextStyle(fontSize: 13, color: app_colors.darkText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (controller.state.isGeocoding)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(app_colors.primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmLocationButton(ParcelDeliveryController controller) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: app_colors.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      onPressed: () {
        controller.confirmLocation();
        _showRequestForm(context);
      },
      child: const Text(
        'تأكيد الموقع',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Consumer<ParcelDeliveryController>(
      builder: (context, controller, child) {
        return Container(
          decoration: BoxDecoration(
            color: app_colors.darkCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            onChanged: (v) => controller.updateSearch(v),
            style: const TextStyle(color: app_colors.darkText, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ابحث عن وجهة أو مكان مشهور...',
              hintStyle: const TextStyle(color: app_colors.darkSubText, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: app_colors.primaryColor),
              suffixIcon: IconButton(
                icon: const Icon(Icons.map_outlined, color: app_colors.primaryColor),
                tooltip: 'تحديد من الخريطة',
                onPressed: () => controller.toggleMapSelectionMode(true),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        );
      },
    );
  }

  SliverList _buildMainContent(BuildContext context) {
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                title: 'أماكن مشهورة بالقرب منك',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 15),
              _buildPlacesGrid(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 22, color: app_colors.primaryColor),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: app_colors.darkText,
          ),
        ),
      ],
    );
  }

  Widget _buildPlacesGrid() {
    return Consumer<ParcelDeliveryController>(
      builder: (context, controller, child) {
        if (controller.state.isLoadingPlaces) {
          return const PlacesLoadingShimmer();
        }

        if (controller.state.nearbyPlaces.isEmpty) {
          return _buildEmptyPlacesState();
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: controller.state.filteredNearbyPlaces.take(6).length,
          itemBuilder: (context, index) {
            final place = controller.state.filteredNearbyPlaces[index];
            final distance =
                controller.state.pickupLocation != null
                    ? Geolocator.distanceBetween(
                      controller.state.pickupLocation!.latitude,
                      controller.state.pickupLocation!.longitude,
                      place.position.latitude,
                      place.position.longitude,
                    )
                    : null;

            return PlaceCard(
              place: place,
              distance:
                  distance != null
                      ? (distance < 1000
                          ? '$distance م'
                          : '${(distance / 1000).toStringAsFixed(1)} كم')
                      : null,
              onTap: () {
                controller.setDropoff(place.position, place.name);
                _mapController?.animateCamera(CameraUpdate.newLatLng(place.position));
                _showRequestForm(context);
              },
              isSelected: controller.state.dropoffLocation == place.position,
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyPlacesState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: app_colors.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.location_off, size: 48, color: app_colors.darkSubText),
          SizedBox(height: 12),
          Text(
            'ماكو أماكن حالياً قريبة',
            style: TextStyle(color: app_colors.darkSubText),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return AnimatedOpacity(
      opacity: _isFabVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: FloatingActionButton.extended(
        onPressed: () => _showRequestForm(context),
        backgroundColor: app_colors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add, size: 22),
        label: const Text(
          'طلب توصيل جديد',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  void _showRequestForm(BuildContext context) {
    final controller = context.read<ParcelDeliveryController>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => ChangeNotifierProvider.value(
            value: controller,
            child: const ParcelRequestFormSheet(),
          ),
    );
  }

  void _navigateToTracking(BuildContext context, String shipmentId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ParcelTrackingPage(requestId: shipmentId)),
    );
  }
}
