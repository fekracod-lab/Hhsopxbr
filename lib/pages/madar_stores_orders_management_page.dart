import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import 'package:dalal_alqaim/core/stores/data/repositories/store_orders_repository.dart';

class MadarStoresOrdersManagementPage extends StatefulWidget {
  const MadarStoresOrdersManagementPage({super.key});

  @override
  State<MadarStoresOrdersManagementPage> createState() => _MadarStoresOrdersManagementPageState();
}

class _MadarStoresOrdersManagementPageState extends State<MadarStoresOrdersManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StoreOrdersRepository _storeOrdersRepo = StoreOrdersRepository();
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedStatusFilter = 'الكل';
  String _searchQuery = '';

  final List<String> _statusFilters = [
    'الكل',
    'pending',
    'accepted',
    'delivering',
    'completed',
    'cancelled',
  ];

  final Map<String, String> _statusLabels = {
    'الكل': 'الكل',
    'pending': 'بانتظار القبول',
    'accepted': 'تم القبول (التجهيز)',
    'delivering': 'جاري التوصيل',
    'completed': 'مكتمل',
    'cancelled': 'ملغي',
  };

  // Premium Palette
  static const Color _primaryColor = Color(0xFF00BFA5); // Teal matching the support page
  static const Color _bgLight = Color(0xFFF8FAFC);
  static const Color _bgDark = Color(0xFF0F172A);
  static const Color _cardLight = Colors.white;
  static const Color _cardDark = Color(0xFF1E293B);
  static const Color _txtLight = Color(0xFF1E293B);
  static const Color _txtDark = Color(0xFFF8FAFC);
  static const Color _subTxtLight = Color(0xFF64748B);
  static const Color _subTxtDark = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'delivering':
        return const Color(0xFF6C63FF);
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return '';
      }
      return DateFormat('yyyy-MM-dd hh:mm a').format(date);
    } catch (_) {
      return '';
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ── Helper: Extract Store ID from Document Path ──
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  String _extractStoreId(String path) {
    final segments = path.split('/');
    if (segments.length >= 2) {
      return segments[1]; // stores/{storeId}/madar_orders/{orderId}
    }
    return '';
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ── Update Order Status in both Store and User ──
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> _updateStatus(String storeId, String customerId, String orderId, String newStatus) async {
    try {
      await _storeOrdersRepo.updateStoreOrderStatus(
        storeId: storeId,
        customerId: customerId,
        orderId: orderId,
        newStatus: newStatus,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث حالة الطلب بنجاح', style: TextStyle())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التحديث: $e', style: const TextStyle())),
        );
      }
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ── Show Driver Assignment Bottom Sheet ──
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  void _showAssignDriverSheet(String storeId, String customerId, String orderId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          color: isDark ? _cardDark : Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'تعيين كابتن التوصيل للطلب',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                  color: isDark ? _txtDark : _txtLight,
                ),
              ),
              SizedBox(height: 12.h),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('drivers').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: _primaryColor));
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'ماكو كباتن حالياً توصيل مسجلين حالياً',
                          style: TextStyle(color: isDark ? _subTxtDark : _subTxtLight),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final dId = doc.id;
                        final dData = doc.data() as Map<String, dynamic>;
                        final dName = dData['name'] ?? dData['username'] ?? 'كابتن مدار';
                        final dPhone = dData['phone'] ?? '-';
                        final vehicle = dData['vehicleInfo'] ?? 'سيارة/دراجة';

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: _primaryColor,
                            child: Icon(Icons.delivery_dining, color: Colors.white),
                          ),
                          title: Text(
                            dName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                              color: isDark ? _txtDark : _txtLight,
                            ),
                          ),
                          subtitle: Text(
                            '$vehicle • الهاتف: $dPhone',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: isDark ? _subTxtDark : _subTxtLight,
                            ),
                          ),
                          onTap: () async {
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            Navigator.pop(ctx);
                            try {
                              final batch = _firestore.batch();
                              
                              final storeOrderRef = _firestore
                                  .collection('stores')
                                  .doc(storeId)
                                  .collection('madar_orders')
                                  .doc(orderId);

                              final userOrderRef = _firestore
                                  .collection('madar_orders')
                                  .doc(customerId)
                                  .collection('store_orders')
                                  .doc(orderId);

                              final updates = {
                                'driverId': dId,
                                'driverName': dName,
                                'driverPhone': dPhone,
                                'status': 'accepted',
                              };

                              batch.update(storeOrderRef, updates);
                              batch.update(userOrderRef, updates);
                              
                              await batch.commit();

                              scaffoldMessenger.showSnackBar(
                                SnackBar(content: Text('تم تعيين الكابتن $dName وتحديث الطلب بنجاح', style: const TextStyle())),
                              );
                            } catch (e) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(content: Text('فشل تعيين الكابتن: $e', style: const TextStyle())),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ── Show Real-time Google Maps Location Dialog ──
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  void _showTrackingDialog(
    String driverId,
    String driverName,
    double? customerLat,
    double? customerLng,
    String customerName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('drivers').doc(driverId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator(color: _primaryColor)),
                );
              }

              final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
              final double? dLat = data['latitude'] != null ? (data['latitude'] as num).toDouble() : null;
              final double? dLng = data['longitude'] != null ? (data['longitude'] as num).toDouble() : null;

              if (dLat == null || dLng == null) {
                return SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_off_rounded, size: 48, color: Colors.orange),
                        const SizedBox(height: 12),
                        Text(
                          'موقع الكابتن غير متوفر حالياً\n(قد تكون الخدمة غير مفعلة لدى الكابتن)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final driverLatLng = LatLng(dLat, dLng);
              final markers = <Marker>{
                Marker(
                  markerId: const MarkerId('driver'),
                  position: driverLatLng,
                  infoWindow: InfoWindow(title: 'موقع الكابتن: $driverName'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                ),
              };

              if (customerLat != null && customerLng != null) {
                markers.add(
                  Marker(
                    markerId: const MarkerId('customer'),
                    position: LatLng(customerLat, customerLng),
                    infoWindow: InfoWindow(title: 'موقع الزبون: $customerName'),
                  ),
                );
              }

              return ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  width: double.infinity,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        color: _primaryColor,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'تتبع موقع الدليفري مباشر',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: driverLatLng,
                            zoom: 14.5,
                          ),
                          markers: markers,
                          myLocationButtonEnabled: false,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(16.r),
                        color: Colors.white,
                        child: Row(
                          children: [
                            const Icon(Icons.person_pin_circle_rounded, color: _primaryColor),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                'كابتن التوصيل: $driverName\nالإحداثيات الحالية: (${dLat.toStringAsFixed(5)}, ${dLng.toStringAsFixed(5)})',
                                style: TextStyle(fontSize: 11.sp, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _bgDark : _bgLight;
    final cardBg = isDark ? _cardDark : _cardLight;
    final txtColor = isDark ? _txtDark : _txtLight;
    final subTxt = isDark ? _subTxtDark : _subTxtLight;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: cardBg,
          elevation: 2,
          iconTheme: IconThemeData(color: txtColor),
          title: Text(
            'إدارة طلبات متاجر مدار',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: txtColor,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: cardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                    title: Row(
                      children: [
                        Icon(Icons.logout_rounded, color: Colors.redAccent, size: 24.sp),
                        SizedBox(width: 10.w),
                        Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp, color: txtColor)),
                      ],
                    ),
                    content: Text('هل أنت تأكد من رغبتك في تسجيل الخروج؟', style: TextStyle(fontSize: 13.5.sp, color: subTxt)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13.sp)),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: Icon(Icons.logout_rounded, size: 16.sp, color: Colors.white),
                        label: Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
                  }
                }
              },
              tooltip: 'تسجيل الخروج',
              icon: Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22.sp),
            ),
            SizedBox(width: 8.w),
          ],
        ),
        body: Column(
          children: [
            // ── Search & Filter Panel ──
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              color: cardBg,
              child: Column(
                children: [
                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? _bgDark : Colors.grey[50],
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: txtColor, fontSize: 12.sp),
                      decoration: InputDecoration(
                        hintText: 'البحث برقم الطلب، اسم أو هاتف العميل...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, color: _primaryColor),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // Filter Choice Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _statusFilters.map((filter) {
                        final isSelected = _selectedStatusFilter == filter;
                        return Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: ChoiceChip(
                            label: Text(
                              _statusLabels[filter] ?? filter,
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: _primaryColor.withValues(alpha: 0.2),
                            backgroundColor: isDark ? _bgDark : Colors.grey[100],
                            labelStyle: TextStyle(
                              color: isSelected ? _primaryColor : subTxt,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              side: BorderSide(
                                color: isSelected ? _primaryColor.withValues(alpha: 0.5) : Colors.transparent,
                              ),
                            ),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _selectedStatusFilter = filter);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // ── Orders Stream Builder (Store Domain Isolated Query) ──
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _storeOrdersRepo.streamStoreOrders(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    final errorStr = snapshot.error.toString();
                    final isIndexError = errorStr.contains('FAILED_PRECONDITION') && errorStr.contains('index');
                    String? indexUrl;
                    final urlRegExp = RegExp(r'https://console\.firebase\.google\.com[^\s]*');
                    final match = urlRegExp.firstMatch(errorStr);
                    if (match != null) {
                      indexUrl = match.group(0);
                    }

                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48.sp),
                            SizedBox(height: 16.h),
                            Text(
                              'حدث خطأ في تحميل الطلبات',
                              style: TextStyle(color: txtColor, fontWeight: FontWeight.bold, fontSize: 16.sp),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              isIndexError
                                  ? 'يتطلب هذا الاستعلام تفعيل الفهرس (Index) في Firebase.\nيرجى الضغط على الزر أدناه لإنشائه.'
                                  : 'تفاصيل الخطأ: $errorStr',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                            ),
                            if (indexUrl != null) ...[
                              SizedBox(height: 16.h),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final uri = Uri.parse(indexUrl!);
                                  if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                                    // Success
                                  }
                                },
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('إنشاء الفهرس في Firebase', style: TextStyle()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: _primaryColor));
                  }

                  // 1. Get raw documents
                  var docs = snapshot.data?.docs ?? [];

                  // 2. Perform in-memory sorting (by createdAt descending)
                  docs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>? ?? {};
                    final bData = b.data() as Map<String, dynamic>? ?? {};
                    final Timestamp? aTime = aData['createdAt'] as Timestamp?;
                    final Timestamp? bTime = bData['createdAt'] as Timestamp?;
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime);
                  });

                  // 3. Apply search query
                  if (_searchQuery.isNotEmpty) {
                    docs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final oId = (data['orderId'] ?? doc.id).toString().toLowerCase();
                      final cName = (data['customerName'] ?? '').toString().toLowerCase();
                      final cPhone = (data['customerPhone'] ?? '').toString();
                      return oId.contains(_searchQuery) || cName.contains(_searchQuery) || cPhone.contains(_searchQuery);
                    }).toList();
                  }

                  // 4. Apply status filter
                  if (_selectedStatusFilter != 'الكل') {
                    docs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      return (data['status'] ?? 'pending') == _selectedStatusFilter;
                    }).toList();
                  }

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.storefront_rounded, size: 64.sp, color: Colors.grey.withValues(alpha: 0.2)),
                          SizedBox(height: 16.h),
                          Text(
                            'ماكو طلبات حالياً متطابقة حالياً',
                            style: TextStyle(color: subTxt, fontSize: 13.sp),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(16.r),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final orderId = data['orderId'] ?? doc.id;
                      final customerId = data['customerId'] ?? '';
                      final customerName = data['customerName'] ?? 'عميل غير معروف';
                      final customerPhone = data['customerPhone'] ?? '-';
                      final address = data['address'] ?? 'العنوان غير متوفر';
                      final double? cLat = data['latitude'] != null ? (data['latitude'] as num).toDouble() : null;
                      final double? cLng = data['longitude'] != null ? (data['longitude'] as num).toDouble() : null;
                      final total = (data['total'] as num? ?? 0.0).toDouble();
                      final status = data['status'] ?? 'pending';
                      final paymentStatus = data['paymentStatus'] ?? 'cash_on_delivery';
                      final timeStr = _formatDate(data['createdAt']);

                      // Driver info
                      final driverId = data['driverId'] as String?;
                      final driverName = data['driverName'] as String? ?? '';
                      final driverPhone = data['driverPhone'] as String? ?? '';

                      final storeId = _extractStoreId(doc.reference.path);

                      return Card(
                        color: cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                        elevation: 3,
                        margin: EdgeInsets.only(bottom: 16.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Card Header: Order ID & Status
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[50],
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'طلب #${orderId.toString().length > 8 ? orderId.toString().substring(0, 8).toUpperCase() : orderId}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.sp,
                                          color: txtColor,
                                        ),
                                      ),
                                      if (timeStr.isNotEmpty)
                                        Text(
                                          timeStr,
                                          style: TextStyle(fontSize: 9.sp, color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.25)),
                                    ),
                                    child: Text(
                                      _statusLabels[status] ?? status,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10.sp,
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Store Owner & Store Details Fetcher
                            FutureBuilder<DocumentSnapshot>(
                              future: _firestore.collection('stores').doc(storeId).get(),
                              builder: (context, storeSnap) {
                                if (storeSnap.connectionState == ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                                  );
                                }

                                final storeData = storeSnap.data?.data() as Map<String, dynamic>? ?? {};
                                final storeName = storeData['name'] ?? 'متجر غير معروف';
                                final storePhone = storeData['phone'] ?? '-';
                                final ownerId = storeData['ownerId'] ?? '';
                                final String storeRegId = storeData['regionId'] ?? '';
                                final String storeGovId = storeData['governorateId'] ?? '';

                                return Padding(
                                  padding: EdgeInsets.all(16.r),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Store Info & Owner Details Future
                                      Row(
                                        children: [
                                          const Icon(Icons.storefront, color: _primaryColor, size: 20),
                                          SizedBox(width: 8.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'المحل: $storeName',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: txtColor),
                                                ),
                                                Text(
                                                  'هاتف المحل: $storePhone',
                                                  style: TextStyle(fontSize: 11.sp, color: subTxt),
                                                ),
                                                if (ownerId.isNotEmpty)
                                                  FutureBuilder<DocumentSnapshot>(
                                                    future: _firestore.collection('users').doc(ownerId).get(),
                                                    builder: (context, ownerSnap) {
                                                      final oData = ownerSnap.data?.data() as Map<String, dynamic>? ?? {};
                                                      final ownerName = oData['name'] ?? oData['username'] ?? 'غير متوفر';
                                                      final ownerPhone = oData['phone'] ?? '-';
                                                      return Text(
                                                        'صاحب المحل: $ownerName ($ownerPhone)',
                                                        style: TextStyle(fontSize: 11.sp, color: subTxt),
                                                      );
                                                    },
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),

                                      // Customer & Region Info
                                      Row(
                                        children: [
                                          const Icon(Icons.person_outline_rounded, color: _primaryColor, size: 20),
                                          SizedBox(width: 8.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'الزبون: $customerName',
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: txtColor),
                                                ),
                                                Text(
                                                  'الهاتف: $customerPhone • العنوان: $address',
                                                  style: TextStyle(fontSize: 11.sp, color: subTxt),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),

                                      // Region Manager Details
                                      if (storeRegId.isNotEmpty || storeGovId.isNotEmpty)
                                        FutureBuilder<QuerySnapshot>(
                                          future: _firestore
                                              .collection('users')
                                              .where('role', isEqualTo: 'region_manager')
                                              .where('assignedRegionId', isEqualTo: storeRegId)
                                              .limit(1)
                                              .get(),
                                          builder: (context, managerSnap) {
                                            final mgrDocs = managerSnap.data?.docs ?? [];
                                            if (mgrDocs.isNotEmpty) {
                                              final mData = mgrDocs.first.data() as Map<String, dynamic>;
                                              final mName = mData['name'] ?? mData['username'] ?? 'مسؤول المنطقة';
                                              final mPhone = mData['phone'] ?? '-';
                                              return Padding(
                                                padding: EdgeInsets.only(bottom: 8.h),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 18),
                                                    SizedBox(width: 8.w),
                                                    Text(
                                                      'مسؤول المنطقة: $mName ($mPhone)',
                                                      style: TextStyle(fontSize: 11.sp, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }

                                            // Fallback to governorate manager
                                            return FutureBuilder<QuerySnapshot>(
                                              future: _firestore
                                                  .collection('users')
                                                  .where('role', isEqualTo: 'governorate_manager')
                                                  .where('assignedGovernorateId', isEqualTo: storeGovId)
                                                  .limit(1)
                                                  .get(),
                                              builder: (context, govMgrSnap) {
                                                final govDocs = govMgrSnap.data?.docs ?? [];
                                                if (govDocs.isNotEmpty) {
                                                  final gData = govDocs.first.data() as Map<String, dynamic>;
                                                  final gName = gData['name'] ?? gData['username'] ?? 'مسؤول المحافظة';
                                                  final gPhone = gData['phone'] ?? '-';
                                                  return Row(
                                                    children: [
                                                      const Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 18),
                                                      SizedBox(width: 8.w),
                                                      Text(
                                                        'مسؤول المحافظة: $gName ($gPhone)',
                                                        style: TextStyle(fontSize: 11.sp, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  );
                                                }
                                                return const SizedBox();
                                              },
                                            );
                                          },
                                        ),

                                      // Delivery Captain Assignment & Realtime Location
                                      if (driverId != null && driverId.isNotEmpty) ...[
                                        SizedBox(height: 8.h),
                                        Row(
                                          children: [
                                            const Icon(Icons.delivery_dining_rounded, color: Colors.purple, size: 20),
                                            SizedBox(width: 8.w),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'دليفري الطلب: $driverName',
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: txtColor),
                                                  ),
                                                  Text(
                                                    'هاتف الكابتن: $driverPhone',
                                                    style: TextStyle(fontSize: 10.sp, color: subTxt),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (status == 'accepted' || status == 'delivering')
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: _primaryColor,
                                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                                ),
                                                icon: const Icon(Icons.gps_fixed, color: Colors.white, size: 14),
                                                label: const Text(
                                                  'تحديد الموقع',
                                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                                onPressed: () => _showTrackingDialog(driverId, driverName, cLat, cLng, customerName),
                                              ),
                                          ],
                                        ),
                                      ],

                                      const Divider(height: 24),

                                      // Financials: Total & Payment status
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'الحساب الإجمالي: ${total.toStringAsFixed(0)} د.ع',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: _primaryColor),
                                          ),
                                          Text(
                                            paymentStatus == 'paid_wallet' ? 'دفع عبر المحفظة' : 'دفع عند الاستلام',
                                            style: TextStyle(fontSize: 11.sp, color: Colors.amber[800], fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),

                                      // Actions Panel
                                      SizedBox(height: 16.h),
                                      Row(
                                        children: [
                                          // Assign Driver Button
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: _primaryColor),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                              ),
                                              icon: const Icon(Icons.person_add_alt_1_rounded, color: _primaryColor, size: 18),
                                              label: Text(
                                                driverId == null ? 'تعيين كابتن' : 'تغيير الكابتن',
                                                style: TextStyle(color: _primaryColor, fontSize: 11.sp, fontWeight: FontWeight.bold),
                                              ),
                                              onPressed: () => _showAssignDriverSheet(storeId, customerId, orderId),
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          // Update Status Options
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blueAccent,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                                padding: EdgeInsets.symmetric(vertical: 10.h),
                                              ),
                                              icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 18),
                                              label: const Text(
                                                'تحديث الحالة',
                                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (c) => AlertDialog(
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                    title: const Text('تحديث حالة الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
                                                    content: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: _statusFilters.where((f) => f != 'الكل').map((st) {
                                                        return ListTile(
                                                          title: Text(
                                                            _statusLabels[st] ?? st,
                                                            style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(st)),
                                                          ),
                                                          onTap: () {
                                                            Navigator.pop(c);
                                                            _updateStatus(storeId, customerId, orderId, st);
                                                          },
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
