import 'package:flutter/material.dart';
import 'package:dalal_alqaim/services/food_order_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dalal_alqaim/services/driver_service.dart';

// --- Premium Palette (Consistent with Dashboard) ---
const Color kPrimary = Color(0xFF00BFA5);
const Color kAccent = Color(0xFF1DE9B6);
const Color kDarkBg = Color(0xFF07191A);
const Color kDarkSurface = Color(0xFF0F2323);
const Color kDarkCard = Color(0xFF113033);
const Color kTextWhite = Color(0xFFE0F2F1);
const Color kTextSub = Color(0xFF80CBC4);
const Color kSuccess = Color(0xFF00E676);
const Color kWarning = Color(0xFFFFD600);
const Color kDanger = Color(0xFFFF5252);

class FoodOrderDetailsPage extends StatefulWidget {
  final Map<String, dynamic> order;
  final String driverId;
  final Map<String, dynamic> driverData;

  const FoodOrderDetailsPage({
    super.key,
    required this.order,
    required this.driverId,
    required this.driverData,
  });

  @override
  State<FoodOrderDetailsPage> createState() => _FoodOrderDetailsPageState();
}

class _FoodOrderDetailsPageState extends State<FoodOrderDetailsPage> {
  final FoodOrderService _foodService = FoodOrderService();
  final DriverService _driverService = DriverService();

  bool _isProcessing = false;
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.order['status'] ?? 'pending';
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isProcessing = true);
    try {
      if (newStatus == 'accepted') {
        // Special handling for acceptance to ensure checks
        final success = await _foodService.acceptOrder(
          widget.order['id'],
          widget.driverId,
          widget.driverData,
        );
        if (success) {
          setState(() => _status = 'accepted');
          _showSnack('تم قبول الطلب بنجاح', kSuccess);
        } else {
          _showSnack('تعذر قبول الطلب', kDanger);
        }
      } else {
        await _foodService.updateOrderStatus(widget.order['id'], newStatus);
        setState(() => _status = newStatus);

        // If delivered, we might want to update driver availability logic if needed,
        // but DriverService's _hasActiveTasks handles the global state.
        // However, we should ensure the driver is set to available if this was their last task.
        if (newStatus == 'delivered') {
          await _driverService.checkAndSetAvailable(widget.driverId);
          _showSnack('تم توصيل الطلب بنجاح!', kSuccess);
          if (mounted) Navigator.pop(context); // Exit after completion
        } else {
          _showSnack('تم تحديث الحالة', kSuccess);
        }
      }
    } catch (e) {
      _showSnack('حدث خطأ: $e', kDanger);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle()),
        backgroundColor: color.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  void _launchMaps(double? lat, double? lng) async {
    if (lat == null || lng == null || (lat == 0 && lng == 0)) {
      _showSnack('الموقع غير متاح', kWarning);
      return;
    }
    final url = Uri.parse('google.navigation:q=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      final webUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      await launchUrl(webUrl);
    }
  }

  void _launchCaller(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order['items'] as List? ?? [];
    final deliveryFee = (widget.order['deliveryFee'] as num?)?.toDouble() ?? 0.0;
    final totalAmount = (widget.order['totalAmount'] as num?)?.toDouble() ?? 0.0;

    // Restaurant Location
    final restLat = (widget.order['restaurantLat'] as num?)?.toDouble();
    final restLng = (widget.order['restaurantLng'] as num?)?.toDouble();

    // Customer Location
    final custLat =
        (widget.order['dropoffLat'] as num?)
            ?.toDouble(); // Assuming structure, logic might need adjustment if fields differ
    final custLng = (widget.order['dropoffLng'] as num?)?.toDouble();

    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        title: const Text(
          'تفاصيل الطلب',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kDarkSurface,
        foregroundColor: kTextWhite,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOrderStepIndicator(_status),
                const SizedBox(height: 20),

                // Restaurant Info Card
                _buildSectionCard(
                  title: 'المطعم',
                  icon: Icons.store_rounded,
                  color: kPrimary, // Changed from kAccent for better visibility
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.storefront,
                        'اسم المطعم',
                        widget.order['restaurantName'] ?? 'مطعم',
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        Icons.location_on,
                        'العنوان',
                        widget.order['restaurantAddress'] ?? 'غير محدد',
                        action: IconButton(
                          icon: const Icon(Icons.directions, color: kPrimary),
                          onPressed: () => _launchMaps(restLat, restLng),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        Icons.phone,
                        'رقم الهاتف',
                        widget.order['restaurantPhone'] ?? '',
                        action: IconButton(
                          icon: const Icon(Icons.phone, color: kSuccess),
                          onPressed: () => _launchCaller(widget.order['restaurantPhone']),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Customer Info Card
                _buildSectionCard(
                  title: 'الزبون',
                  icon: Icons.person_pin,
                  color: Colors.blueAccent,
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.person, 'الاسم', widget.order['customerName'] ?? 'زبون'),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        Icons.location_on,
                        'العنوان',
                        widget.order['address'] ?? 'غير محدد', // Standard field check
                        action: IconButton(
                          icon: const Icon(Icons.directions, color: Colors.blueAccent),
                          onPressed:
                              () => _launchMaps(custLat, custLng), // Fallback or explicit field
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        Icons.phone,
                        'رقم الهاتف',
                        widget.order['customerPhone'] ?? '',
                        action: IconButton(
                          icon: const Icon(Icons.phone, color: kSuccess),
                          onPressed: () => _launchCaller(widget.order['customerPhone']),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Order Items
                _buildSectionCard(
                  title: 'قائمة الطلبات',
                  icon: Icons.receipt_long,
                  color: kWarning,
                  child: Column(
                    children: [
                      ...items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: kDarkBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${item['quantity']}x',
                                  style: const TextStyle(
                                    color: kPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item['name'] ?? 'منتج',
                                  style: const TextStyle(color: kTextWhite),
                                ),
                              ),
                              Text(
                                '${item['price']} د.ع',
                                style: const TextStyle(color: kTextSub),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(color: Colors.white12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'أجرة التوصيل',
                            style: TextStyle(color: kTextSub),
                          ),
                          Text(
                            '$deliveryFee د.ع',
                            style: const TextStyle(color: kTextWhite, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الإجمالي',
                            style: TextStyle(
                              color: kSuccess,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$totalAmount د.ع',
                            style: const TextStyle(
                              color: kSuccess,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Actions
                if (_status == 'ready' || _status == 'pending')
                  _buildActionButton('قبول الطلب', kPrimary, () => _updateStatus('accepted')),

                if (_status == 'accepted')
                  _buildActionButton(
                    'استلام الطلب من المطعم',
                    kAccent,
                    () => _updateStatus('delivering'),
                  ),

                if (_status == 'delivering')
                  _buildActionButton(
                    'تم التسليم للزبون',
                    kSuccess,
                    () => _updateStatus('delivered'),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: kPrimary)),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Widget? action}) {
    return Row(
      children: [
        Icon(icon, color: kTextSub, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: kTextSub.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(color: kTextWhite, fontSize: 14),
              ),
            ],
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildOrderStepIndicator(String status) {
    final steps = ['ready', 'accepted', 'delivering', 'delivered'];
    final labels = ['جاهز', 'مقبول', 'جاري التوصيل', 'تم'];

    // Map status 'pending' to 'ready' for visualization if needed, or handle separately
    String displayStatus = status == 'pending' ? 'ready' : status;
    int currentIndex = steps.indexOf(displayStatus);
    if (currentIndex == -1) currentIndex = 0; // Default or handled elsewhere

    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index <= currentIndex;
        final isLast = index == steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isActive ? kPrimary : kDarkCard,
                    child:
                        isActive
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : Text(
                              '${index + 1}',
                              style: const TextStyle(color: kTextSub, fontSize: 10),
                            ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[index],
                    style: TextStyle(
                      color: isActive ? kPrimary : kTextSub,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isActive ? kPrimary : kDarkCard,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
