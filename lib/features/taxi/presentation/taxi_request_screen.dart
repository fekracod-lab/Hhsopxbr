import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:dalal_alqaim/features/taxi/presentation/controller/taxi_controller.dart';
import 'package:dalal_alqaim/features/taxi/presentation/widgets/taxi_map_view.dart';
import 'package:dalal_alqaim/features/taxi/presentation/widgets/taxi_request_panel.dart';
import 'package:dalal_alqaim/pages/search_screen.dart';
import 'package:dalal_alqaim/features/trip/data/datasources/google_directions_datasource.dart';
import 'package:dalal_alqaim/features/trip/data/datasources/trip_remote_datasource.dart';
import 'package:dalal_alqaim/features/trip/data/repositories/trip_repository_impl.dart';

class TaxiRequestScreen extends StatelessWidget {
  final LatLng? initialLocation;
  const TaxiRequestScreen({super.key, this.initialLocation});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (_) => TaxiController(
            repository: TripRepositoryImpl(TripRemoteDataSource(), GoogleDirectionsDataSource()),
            initialLocation: initialLocation,
          ),
      child: const _TaxiRequestContent(),
    );
  }
}

class _TaxiRequestContent extends StatefulWidget {
  const _TaxiRequestContent();

  @override
  State<_TaxiRequestContent> createState() => _TaxiRequestContentState();
}

class _TaxiRequestContentState extends State<_TaxiRequestContent> {
  GoogleMapController? _mapController;
  bool _hasCenteredInitially = false;
  TaxiController? _controller;
  bool _hasRequestedPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = Provider.of<TaxiController>(context, listen: false);
      if (!_hasRequestedPermission && controller.state.pickupLocation == null) {
        _hasRequestedPermission = true;
        controller.checkPermissionsAndLocate(context);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = Provider.of<TaxiController>(context, listen: false);
    if (_controller != newController) {
      _controller?.removeListener(_onControllerUpdate);
      _controller = newController;
      _controller?.addListener(_onControllerUpdate);
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final state = _controller?.state;
    if (state == null) return;

    if (!_hasCenteredInitially && state.pickupLocation != null) {
      _hasCenteredInitially = true;
      try {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(state.pickupLocation!, 16.5));
      } catch (e) {
        debugPrint(' animateCamera error: $e');
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _openSearch() async {
    final controller = Provider.of<TaxiController>(context, listen: false);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(currentLocation: controller.state.pickupLocation),
      ),
    );

    if (result != null && result is Map) {
      final lat = result['lat'];
      final lng = result['lng'];
      final address = result['address'];
      if (lat != null && lng != null) {
        final location = LatLng(lat, lng);
        controller.setDropoff(location, address?.toString() ?? 'مكان مختار');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            TaxiMapView(
              onMapCreated: (mapController) => setState(() => _mapController = mapController),
              onSearchTap: _openSearch,
            ),
            const Align(alignment: Alignment.bottomCenter, child: TaxiRequestPanel()),
          ],
        ),
      ),
    );
  }
}
