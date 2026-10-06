import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dalal_alqaim/models/delegate_request.dart';
import 'package:dalal_alqaim/services/delegate_service.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';

class DelegateOrderDetailsPage extends StatefulWidget {
  final DelegateRequest request;
  final Map<String, dynamic> driverData;

  const DelegateOrderDetailsPage({super.key, required this.request, required this.driverData});

  @override
  State<DelegateOrderDetailsPage> createState() => _DelegateOrderDetailsPageState();
}

class _DelegateOrderDetailsPageState extends State<DelegateOrderDetailsPage> {
  final DelegateService _delegateService = DelegateService();
  bool _isProcessing = false;
  GoogleMapController? _mapController;
  final ImagePicker _picker = ImagePicker();
  String? _deliveryPhotoUrl;

  // Colors - Optimized for Dark Mode
  static const kPrimary = Color(0xFF26A69A);
  static const kAccent = Color(0xFF00796B);
  static const kDarkBg = Color(0xFF071415);
  static const kSuccess = Color(0xFF00C853);
  static const kSurface = Color(0xFF0A1F20);

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _acceptOrder() async {
    setState(() => _isProcessing = true);
    try {
      final success = await _delegateService.acceptRequest(
        requestId: widget.request.id,
        driverId: widget.driverData['uid'] ?? '',
        driverData: widget.driverData,
      );

      if (success) {
        if (mounted) {
          _showSnackBar('تم قبول الطلب بنجاح!');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      _showSnackBar('خطأ في قبول الطلب: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isProcessing = true);
    try {
      await _delegateService.updateStatus(widget.request.id, status);
      if (mounted) {
        _showSnackBar('تم تحديث الحالة بنجاح');
      }
    } catch (e) {
      _showSnackBar('خطأ في تحديث الحالة: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickAndUploadDeliveryPhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (photo == null) return;

    setState(() => _isProcessing = true);
    try {
      final bytes = await photo.readAsBytes();
      final url = await CloudinaryService.uploadBytes(bytes, 'delegate_${widget.request.id}.jpg');
      if (url != null) {
        setState(() => _deliveryPhotoUrl = url);
        _showSnackBar('تم رفع صورة الإثبات بنجاح');
      } else {
        throw Exception('فشل رفع الصورة');
      }
    } catch (e) {
      _showSnackBar('فشل رفع الصورة: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle()),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.request.status == 'pending';
    final customerLatLng = LatLng(widget.request.pickupLat, widget.request.pickupLng);

    return Scaffold(
      backgroundColor: kDarkBg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(customerLatLng),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStatusStepIndicator(),
                    const SizedBox(height: 30),
                    _buildInfoSection(),
                    const SizedBox(height: 20),
                    _buildCustomerSection(),
                    const SizedBox(height: 40),
                    if (isPending) _buildAcceptSection() else _buildActiveActions(),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator(color: kPrimary)),
            ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(LatLng latLng) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: kDarkBg,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: latLng, zoom: 15),
              onMapCreated: (controller) => _mapController = controller,
              markers: {
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: latLng,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                ),
              },
              zoomControlsEnabled: false,
              myLocationEnabled: false,
              mapToolbarEnabled: false,
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black45, Colors.transparent, kDarkBg],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                backgroundColor: kPrimary,
                heroTag: 'nav_fab',
                onPressed: () => _launchMap(latLng.latitude, latLng.longitude),
                label: const Text(
                  'الملاحة',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                icon: const Icon(Icons.navigation_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStepIndicator() {
    final status = widget.request.status;
    final List<Map<String, String>> steps = [
      {'key': 'accepted', 'label': 'مقبول'},
      {'key': 'arrived_at_pickup', 'label': 'وصل'},
      {'key': 'picked_up', 'label': 'بدء'},
      {'key': 'on_the_way', 'label': 'جاري'},
      {'key': 'completed', 'label': 'تم'},
    ];

    int currentIndex = steps.indexWhere((s) => s['key'] == status);
    if (status == 'pending') currentIndex = -1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isDone = index <= currentIndex && status != 'pending';
          final color = isDone ? kPrimary : Colors.white24;

          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow:
                            isDone
                                ? [BoxShadow(color: kPrimary.withValues(alpha: 0.4), blurRadius: 4)]
                                : [],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[index]['label']!,
                      style: TextStyle(color: color, fontSize: 9),
                    ),
                  ],
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 1.5,
                      margin: const EdgeInsets.only(bottom: 12),
                      color: index < currentIndex ? kPrimary : Colors.white10,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            Icons.assignment_outlined,
            'المهمة المطلوبة',
            widget.request.taskDescription,
            Colors.amber,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white10, height: 1),
          ),
          _buildInfoRow(
            Icons.timer_outlined,
            'المدة المتوقعة',
            '${widget.request.durationHours} ساعة',
            Colors.blue,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.white10, height: 1),
          ),
          _buildInfoRow(
            Icons.location_on_outlined,
            'العنوان',
            widget.request.pickupAddress,
            Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: kPrimary.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: kPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.request.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.request.userPhone,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => launchUrl(Uri.parse('tel:${widget.request.userPhone}')),
            icon: const Icon(Icons.phone_rounded, color: kSuccess),
            style: IconButton.styleFrom(backgroundColor: kSuccess.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(15)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'السعر المقدر:',
                style: TextStyle(color: Colors.white),
              ),
              Text(
                '${widget.request.price.toInt()} د.ع',
                style: const TextStyle(color: kPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildActionBtn('قبول المهمة والبدء', Icons.check_circle, kPrimary, _acceptOrder),
      ],
    );
  }

  Widget _buildActiveActions() {
    final status = widget.request.status;
    if (status == 'accepted') {
      return _buildActionBtn(
        'وصلت لمكان التنفيذ',
        Icons.location_on,
        kAccent,
        () => _updateStatus('arrived_at_pickup'),
      );
    }
    if (status == 'arrived_at_pickup') {
      return _buildActionBtn(
        'بدء تنفيذ المهمة',
        Icons.play_circle_fill,
        kSuccess,
        () => _updateStatus('picked_up'),
      );
    }
    if (status == 'picked_up') {
      return _buildActionBtn(
        'جاري العمل على المهمة',
        Icons.hourglass_bottom,
        Colors.orange,
        () => _updateStatus('on_the_way'),
      );
    }
    if (status == 'on_the_way') {
      return Column(
        children: [
          if (_deliveryPhotoUrl == null)
            _buildActionBtn(
              'التقاط صورة لإنجاز المهمة',
              Icons.camera_alt,
              Colors.blueGrey,
              _pickAndUploadDeliveryPhoto,
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                _deliveryPhotoUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            _buildActionBtn(
              'إكمال المهمة نهائياً',
              Icons.done_all,
              kSuccess,
              () => _updateStatus('completed'),
            ),
          ],
          const SizedBox(height: 20),
          _buildActionBtn(
            'طوارئ (SOS)',
            Icons.sos,
            Colors.redAccent,
            () => _showSnackBar('تم إرسال بلاغ طوارئ'),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildActionBtn(String text, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  Future<void> _launchMap(double lat, double lng) async {
    final url = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
