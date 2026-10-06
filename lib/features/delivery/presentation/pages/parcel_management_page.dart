import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dalal_alqaim/models/parcel_delivery_request.dart';
import 'package:dalal_alqaim/services/parcel_delivery_service.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/core/app_globals.dart';

class ParcelManagementPage extends StatefulWidget {
  final String? driverId;
  const ParcelManagementPage({super.key, this.driverId});

  @override
  State<ParcelManagementPage> createState() => _ParcelManagementPageState();
}

class _ParcelManagementPageState extends State<ParcelManagementPage> {
  final ParcelDeliveryService _parcelService = ParcelDeliveryService();
  final ImagePicker _picker = ImagePicker();
  final Map<String, String> _deliveryPhotos = {};
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: isDark ? app_colors.darkBackground : app_colors.logisticsSurface,
          body: Stack(
            children: [
              _buildBackgroundGradient(isDark),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopHeader(context, isDark),
                    Expanded(
                      child: StreamBuilder<List<ParcelDeliveryRequest>>(
                        stream:
                            widget.driverId != null
                                ? _parcelService.getDriverActiveOrders(widget.driverId!)
                                : _parcelService.getAllRequestsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(color: app_colors.logisticsPrimary),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'خطأ: ${snapshot.error}',
                                style: const TextStyle(),
                              ),
                            );
                          }
                          final requests = snapshot.data ?? [];
                          if (requests.isEmpty) {
                            return _buildEmptyState();
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: requests.length,
                            itemBuilder: (context, index) {
                              final request = requests[index];
                              return _buildPremiumRequestCard(request, isDark);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackgroundGradient(bool isDark) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? [app_colors.darkSurface, app_colors.darkBackground]
                  : [
                    app_colors.logisticsPrimary.withValues(alpha: 0.1),
                    app_colors.logisticsSurface,
                  ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? app_colors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: isDark ? Colors.white : app_colors.logisticsAccent,
              ),
            ),
          ),
          Column(
            children: [
              Text(
                'إدارة التوصيل',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : app_colors.logisticsAccent,
                ),
              ),
              Container(
                height: 3,
                width: 30,
                decoration: BoxDecoration(
                  color: app_colors.logisticsPrimary,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? app_colors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Icon(
              Icons.filter_list_rounded,
              size: 20,
              color: isDark ? Colors.white : app_colors.logisticsAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            'ماكو طلبات حالياً جارية',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumRequestCard(ParcelDeliveryRequest request, bool isDark) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (request.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'قيد الانتظار';
        statusIcon = Icons.timer_outlined;
        break;
      case 'accepted':
        statusColor = Colors.blue;
        statusText = 'تم القبول';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'picked_up':
        statusColor = app_colors.logisticsPrimary;
        statusText = 'تم الاستلام';
        statusIcon = Icons.archive_outlined;
        break;
      case 'on_the_way':
        statusColor = Colors.orange;
        statusText = 'في الطريق';
        statusIcon = Icons.local_shipping_outlined;
        break;
      case 'arrived_at_pickup':
        statusColor = Colors.teal;
        statusText = 'وصلت للاستلام';
        statusIcon = Icons.location_on;
        break;
      case 'delivered':
        statusColor = Colors.green;
        statusText = 'تم التوصيل';
        statusIcon = Icons.done_all_rounded;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'ملغي';
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = Colors.grey;
        statusText = request.status;
        statusIcon = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? app_colors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          title: Text(
            request.userName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : app_colors.logisticsAccent,
            ),
          ),
          subtitle: Text(
            '#${request.id.substring(request.id.length - 6).toUpperCase()}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  const Divider(height: 30),
                  _buildDetailRow(Icons.location_on_outlined, 'من:', request.pickupAddress, isDark),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.flag_outlined, 'إلى:', request.dropoffAddress, isDark),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.inventory_2_outlined,
                    'الوصف:',
                    request.itemDescription,
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.person_outline,
                    'المستلم:',
                    '${request.recipientName} (${request.recipientPhone})',
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.directions_car_filled_outlined,
                    'المركبة:',
                    request.vehicleType,
                    isDark,
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSmallAction(
                          Icons.phone_forwarded_rounded,
                          'اتصال بالمرسل',
                          Colors.blue,
                          () => _launchCaller(request.userPhone),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSmallAction(
                          Icons.perm_phone_msg_rounded,
                          'اتصال بالمستلم',
                          Colors.purple,
                          () => _launchCaller(request.recipientPhone),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildSmallAction(
                    Icons.map_rounded,
                    'ملاحة إلى الموقع',
                    Colors.orange,
                    () => _launchNavigation(request.dropoffLat, request.dropoffLng),
                  ),
                  const SizedBox(height: 25),
                  _buildManagementActions(request, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallAction(IconData icon, String text, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchCaller(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _launchNavigation(double lat, double lng) async {
    final url = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      }
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: app_colors.logisticsPrimary),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.grey[600],
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white : app_colors.logisticsAccent,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildManagementActions(ParcelDeliveryRequest request, bool isDark) {
    if (request.status == 'delivered' || request.status == 'cancelled') {
      return const SizedBox.shrink();
    }

    String nextActionText = '';
    Color actionColor = app_colors.logisticsPrimary;
    String targetStatus = '';

    if (request.status == 'pending') {
      nextActionText = 'قبول الطلب';
      targetStatus = 'accepted';
      actionColor = Colors.blue;
    } else if (request.status == 'accepted') {
      nextActionText = 'لقد وصلت لمكان الاستلام';
      targetStatus = 'arrived_at_pickup';
      actionColor = Colors.teal;
    } else if (request.status == 'arrived_at_pickup') {
      nextActionText = 'تأكيد الاستلام من المرسل';
      targetStatus = 'picked_up';
      actionColor = app_colors.logisticsPrimary;
    } else if (request.status == 'picked_up') {
      nextActionText = 'بدء التحرك للتسليم';
      targetStatus = 'on_the_way';
      actionColor = Colors.orange;
    } else if (request.status == 'on_the_way') {
      nextActionText = 'تأكيد التسليم للعميل';
      targetStatus = 'delivered';
      actionColor = Colors.green;
    }

    if (request.status == 'on_the_way') {
      final photoUrl = _deliveryPhotos[request.id];
      if (photoUrl == null) {
        return _isUploading
            ? const Center(child: CircularProgressIndicator(color: app_colors.logisticsPrimary))
            : _buildSmallAction(
              Icons.camera_alt_outlined,
              'التقاط صورة لإثبات التسليم (مطلوب)',
              Colors.blueGrey,
              () => _pickAndUploadDeliveryPhoto(request.id),
            );
      } else {
        nextActionText = 'تأكيد التسليم النهائي';
        targetStatus = 'delivered';
        actionColor = Colors.green;
      }
    }

    return Column(
      children: [
        if (request.status == 'on_the_way' && _deliveryPhotos.containsKey(request.id))
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                _deliveryPhotos[request.id]!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        _buildSlideAction(nextActionText, actionColor, () {
          final Map<String, dynamic> extraData = {};
          if (targetStatus == 'delivered' && _deliveryPhotos.containsKey(request.id)) {
            extraData['deliveryPhotoUrl'] = _deliveryPhotos[request.id];
          }
          _parcelService.updateStatus(request.id, targetStatus, extraData: extraData);
        }),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => _parcelService.updateStatus(request.id, 'cancelled'),
          child: const Text(
            'إلغاء الطلب',
            style: TextStyle(color: Colors.red, fontSize: 13),
          ),
        ),
        if (request.status == 'on_the_way') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم إرسال إشارة استغاثة (SOS) للمشرفين'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              icon: const Icon(Icons.sos, color: Colors.white, size: 18),
              label: const Text(
                'طوارئ (SOS)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickAndUploadDeliveryPhoto(String requestId) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (photo == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await photo.readAsBytes();
      final url = await CloudinaryService.uploadBytes(bytes, 'parcel_$requestId.jpg');
      if (url != null) {
        setState(() {
          _deliveryPhotos[requestId] = url;
        });
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Widget _buildSlideAction(String text, Color color, VoidCallback onComplete) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.startToEnd,
            onDismissed: (_) => onComplete(),
            child: Container(
              margin: const EdgeInsets.all(4),
              width: 47,
              height: 47,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)],
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
