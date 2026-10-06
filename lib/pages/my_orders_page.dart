import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import 'package:url_launcher/url_launcher.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF8F9FA),
        body: Stack(
          children: [
            // Background Decoration
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                ),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  expandedHeight: 120.h,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  centerTitle: true,
                  backgroundColor: isDark 
                      ? const Color(0xFF0F1115).withValues(alpha: innerBoxIsScrolled ? 0.9 : 0)
                      : const Color(0xFFF8F9FA).withValues(alpha: innerBoxIsScrolled ? 0.9 : 0),
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'مشاويري وطلباتي',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 18.sp,
                      ),
                    ),
                    centerTitle: true,
                  ),
                  actions: [
                    Container(
                      margin: EdgeInsets.only(left: 16.w, top: 8.h, bottom: 8.h),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.picture_as_pdf_rounded, size: 20.sp, color: AppTheme.primaryColor),
                        onPressed: () => _generateAndPrintPdf(user?.uid, isDark),
                        tooltip: 'تصدير تقرير PDF',
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                    child: _buildSummaryDashboard(user?.uid, isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                    child: Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1D26) : Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        labelColor: AppTheme.primaryColor,
                        unselectedLabelColor: Colors.grey,
                        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                        tabs: const [
                          Tab(text: 'طلبات المطاعم'),
                          Tab(text: 'المتاجر والبراندات'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              body: user == null
                  ? _buildLoginRequired(isDark)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOrdersList('orders', isDark, user.uid),
                        _buildOrdersList('store_orders', isDark, user.uid),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(String collection, bool isDark, String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('madar_orders')
          .doc(uid)
          .collection(collection)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('صار خلل بالتحميل: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }

        final orders = snapshot.data?.docs ?? [];
        if (orders.isEmpty) return _buildEmptyState(isDark, collection == 'orders' ? 'المطاعم' : 'المتاجر');

        return AnimationLimiter(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 100.h),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: _buildPremiumOrderCard(orders[index], isDark, collection == 'store_orders'),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoginRequired(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_person_rounded, size: 80.sp, color: Colors.grey.withValues(alpha: 0.3)),
          SizedBox(height: 24.h),
          Text('سجل دخولك أولاً يا غالي', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
          SizedBox(height: 8.h),
          Text('لازم تسجل دخول حتى تكدر تشوف وتتابع طلباتك السابقة', style: TextStyle(fontSize: 13.sp, color: Colors.grey)),
          SizedBox(height: 32.h),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 15.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            ),
            child: const Text('رجوع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String target) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_basket_rounded, size: 90.sp, color: Colors.grey.withValues(alpha: 0.15)),
          SizedBox(height: 20.h),
          Text('ماكو أي طلبات سابقة هسة', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
          SizedBox(height: 8.h),
          Text('تكدر تطلب هسة من $target وتوصلك للباب بسرعة', style: TextStyle(fontSize: 13.sp, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPremiumOrderCard(DocumentSnapshot doc, bool isDark, bool isStore) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'pending';
    final total = (data['total'] ?? 0.0).toDouble();
    final createdAt = data['createdAt'] as Timestamp?;
    final dateStr = createdAt != null ? DateFormat('dd MMM, HH:mm').format(createdAt.toDate()) : '';
    final title = isStore ? (data['storeName'] ?? 'متجر غير معروف') : 'طلب مطعم #${doc.id.substring(0, 5)}';

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D26) : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          leading: Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: (isStore ? Colors.orange : Colors.teal).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(
              isStore ? Icons.storefront_rounded : Icons.restaurant_rounded,
              color: isStore ? Colors.orange : Colors.teal,
              size: 24.sp,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded, size: 12.sp, color: Colors.grey),
                SizedBox(width: 4.w),
                Text(dateStr, style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                SizedBox(width: 12.w),
                Text(
                  '${NumberFormat('#,###').format(total)} د.ع',
                  style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12.sp),
                ),
              ],
            ),
          ),
          trailing: _buildStatusBadge(status),
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24.r),
                  bottomRight: Radius.circular(24.r),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  SizedBox(height: 10.h),
                  if (isStore)
                    _buildStoreOrderDetails(doc.id, data['storeId'], data['items'] as List<dynamic>?, isDark)
                  else
                    _buildRestaurantOrderDetails(data['items'] as List<dynamic>? ?? [], isDark),
                  _buildDriverInfoCard(data, isDark),
                  SizedBox(height: 15.h),
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _printSingleOrder(doc, isDark),
                            icon: Icon(Icons.print_rounded, size: 14.sp),
                            label: Text('طباعة الفاتورة', style: TextStyle(fontSize: 11.sp)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                              foregroundColor: AppTheme.primaryColor,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                            ),
                          ),
                          if (status == 'pending') ...[
                            SizedBox(width: 8.w),
                            TextButton.icon(
                              onPressed: () => _confirmCancelOrder(doc, isStore),
                              icon: Icon(Icons.close_rounded, size: 16.sp, color: Colors.redAccent),
                              label: Text('إلغاء الطلب', style: TextStyle(fontSize: 11.sp, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 12.w),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('رقم الطلب:', style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
                          Text(doc.id, style: TextStyle(fontSize: 11.sp, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printSingleOrder(DocumentSnapshot doc, bool isDark) async {
    final data = doc.data() as Map<String, dynamic>;
    final isStore = doc.reference.path.contains('store_orders');
    final title = isStore ? (data['storeName'] ?? 'متجر') : 'فاتورة طلب مطعم';
    final total = (data['total'] ?? 0).toDouble();
    final items = data['items'] as List<dynamic>? ?? [];

    try {
      final pdf = pw.Document();
      final fontData = await rootBundle.load("Cairo-Regular.ttf");
      final ttf = pw.Font.ttf(fontData);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          theme: pw.ThemeData.withFont(base: ttf),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text('فاتورة تطبيق مدار', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal700))),
                pw.Divider(),
                pw.Text('الجهة: $title', style: pw.TextStyle(fontSize: 14)),
                pw.Text('رقم الطلب: ${doc.id}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.Text('التاريخ: ${DateFormat('yyyy/MM/dd HH:mm').format((data['createdAt'] as Timestamp).toDate())}', style: pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 20),
                pw.Text('المنتجات:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.TableHelper.fromTextArray(
                  context: context,
                  data: <List<String>>[
                    ['المنتج', 'الكمية', 'السعر'],
                    ...items.map((item) => [
                      item['name'] ?? '',
                      '${item['quantity'] ?? 1}',
                      '${(item['price'] ?? 0).toStringAsFixed(0)} د.ع',
                    ]),
                  ],
                ),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الإجمالي:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${NumberFormat('#,###').format(total)} د.ع', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Center(child: pw.Text('شكراً لاستخدامكم تطبيق مدار', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600))),
              ],
            );
          },
        ),
      );
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الطباعة: $e')));
    }
  }

  Future<void> _confirmCancelOrder(DocumentSnapshot doc, bool isStore) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إلغاء الطلب', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('متأكد تريد تلغي هذا الطلب عيوني؟', textAlign: TextAlign.right),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('نعم، الغي الطلب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _handleCancelOrder(doc, isStore);
    }
  }

  Future<void> _handleCancelOrder(DocumentSnapshot doc, bool isStore) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final data = doc.data() as Map<String, dynamic>;
    final batch = FirebaseFirestore.instance.batch();
    
    try {
      // 1. Update user's history
      final userHistoryRef = FirebaseFirestore.instance
          .collection('madar_orders')
          .doc(uid)
          .collection(isStore ? 'store_orders' : 'orders')
          .doc(doc.id);
      batch.update(userHistoryRef, {'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});

      if (isStore) {
        final storeId = data['storeId'];
        if (storeId != null) {
          // 2. Update store's collection
          final storeOrderRef = FirebaseFirestore.instance
              .collection('stores')
              .doc(storeId)
              .collection('madar_orders')
              .doc(doc.id);
          batch.update(storeOrderRef, {'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});
          
          // 3. Handle Refunds for Stores (Points & Wallet via Security Protocol)
          final pointsUsed = (data['pointsUsed'] as num? ?? 0).toInt();
          final total = (data['total'] as num? ?? 0.0).toDouble();
          final paymentStatus = data['paymentStatus'] ?? '';
          
          if (pointsUsed > 0 || (paymentStatus == 'paid_wallet' && total > 0)) {
            final refundDocRef = FirebaseFirestore.instance.collection('refund_requests').doc();
            batch.set(refundDocRef, {
              'id': refundDocRef.id,
              'orderId': doc.id,
              'orderSource': 'store',
              'userId': uid,
              'amount': paymentStatus == 'paid_wallet' ? total : 0.0,
              'points': pointsUsed,
              'reason': 'إلغاء الطلب من قبل العميل',
              'status': 'pending',
              'idempotencyKey': 'ref-store-${doc.id}',
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } else {
        // Restaurant Order
        final rid = data['restaurantId'] ?? data['restaurantDocId'];
        // 2. Update global orders
        final globalOrderRef = FirebaseFirestore.instance.collection('orders').doc(doc.id);
        batch.update(globalOrderRef, {'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});

        if (rid != null) {
          // 3. Update restaurant mirror
          final restaurantOrderRef = FirebaseFirestore.instance
              .collection('restaurants')
              .doc(rid)
              .collection('orders')
              .doc(doc.id);
          batch.update(restaurantOrderRef, {'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});
        }
      }

      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إلغاء الطلب بنجاح', style: TextStyle())));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل إلغاء الطلب: $e')));
    }
  }

  Widget _buildRestaurantOrderDetails(List<dynamic> items, bool isDark) {
    return Column(
      children: items.map((item) => Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(4.r),
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Text('${item['quantity']}', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            ),
            SizedBox(width: 12.w),
            Expanded(child: Text(item['name'] ?? '', style: TextStyle(fontSize: 13.sp, color: isDark ? Colors.white70 : Colors.black87))),
            Text('${(item['price'] ?? 0).toStringAsFixed(0)} د.ع', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildStoreOrderDetails(String orderId, String? storeId, List<dynamic>? localItems, bool isDark) {
    if (localItems != null && localItems.isNotEmpty) {
      return Column(
        children: localItems.map((item) => Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Row(
            children: [
              if (item['imageUrl'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: Image.network(item['imageUrl'], width: 40.r, height: 40.r, fit: BoxFit.cover),
                ),
              SizedBox(width: 12.w),
              Expanded(child: Text(item['name'] ?? '', style: TextStyle(fontSize: 13.sp, color: isDark ? Colors.white70 : Colors.black87))),
              Text('${(item['price'] ?? 0).toStringAsFixed(0)} د.ع', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),
            ],
          ),
        )).toList(),
      );
    }

    if (storeId == null) return const SizedBox();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('stores').doc(storeId).collection('madar_orders').doc(orderId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final orderData = snapshot.data!.data() as Map<String, dynamic>?;
        if (orderData == null) return const Text('ما قدرنا نحمل التفاصيل');
        
        final items = orderData['items'] as List? ?? [];
        return Column(
          children: items.map((item) => Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Row(
              children: [
                if (item['imageUrl'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Image.network(item['imageUrl'], width: 40.r, height: 40.r, fit: BoxFit.cover),
                  ),
                SizedBox(width: 12.w),
                Expanded(child: Text(item['name'] ?? '', style: TextStyle(fontSize: 13.sp, color: isDark ? Colors.white70 : Colors.black87))),
                Text('${(item['price'] ?? 0).toStringAsFixed(0)} د.ع', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600)),
              ],
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildSummaryDashboard(String? uid, bool isDark) {
    if (uid == null) return const SizedBox();
    return StreamBuilder<List<QuerySnapshot>>(
      stream: _combineLatestStreams(
        FirebaseFirestore.instance.collection('madar_orders').doc(uid).collection('orders').snapshots(),
        FirebaseFirestore.instance.collection('madar_orders').doc(uid).collection('store_orders').snapshots(),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final allDocs = [...snapshot.data![0].docs, ...snapshot.data![1].docs];
        
        double totalSpent = 0;
        int completed = 0;
        int cancelled = 0;

        for (var doc in allDocs) {
          final data = doc.data() as Map<String, dynamic>;
          totalSpent += (data['total'] ?? 0).toDouble();
          final status = data['status'] ?? 'pending';
          if (status == 'completed') completed++;
          if (status == 'cancelled') cancelled++;
        }

        return Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D26) : Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem('إجمالي الصرف', '${NumberFormat('#,###').format(totalSpent)} د.ع', Icons.account_balance_wallet_rounded, Colors.teal),
                  _buildStatItem('كل الطلبات', '${allDocs.length}', Icons.receipt_long_rounded, Colors.blue),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem('مكتملة', '$completed', Icons.check_circle_rounded, Colors.green),
                  _buildStatItem('ملغية', '$cancelled', Icons.cancel_rounded, Colors.red),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Stream<List<QuerySnapshot>> _combineLatestStreams(
    Stream<QuerySnapshot> streamA,
    Stream<QuerySnapshot> streamB,
  ) {
    late StreamController<List<QuerySnapshot>> controller;
    QuerySnapshot? lastA;
    QuerySnapshot? lastB;
    bool hasA = false;
    bool hasB = false;

    controller = StreamController<List<QuerySnapshot>>(
      onListen: () {
        final subA = streamA.listen((a) {
          lastA = a;
          hasA = true;
          if (hasB) controller.add([lastA!, lastB!]);
        }, onError: (e) => controller.addError(e));
        
        final subB = streamB.listen((b) {
          lastB = b;
          hasB = true;
          if (hasA) controller.add([lastA!, lastB!]);
        }, onError: (e) => controller.addError(e));

        controller.onCancel = () {
          subA.cancel();
          subB.cancel();
        };
      },
    );

    return controller.stream;
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20.sp),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10.sp, color: Colors.grey)),
                Text(value, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    switch (status) {
      case 'pending': color = Colors.orange; text = 'قيد الانتظار'; break;
      case 'accepted': color = Colors.blue; text = 'مقبول'; break;
      case 'ready': color = Colors.purple; text = 'جاهز للتوصيل'; break;
      case 'delivering': color = Colors.indigo; text = 'بالطريق'; break;
      case 'picked_up': color = Colors.teal; text = 'واصل لعندك'; break;
      case 'completed': 
      case 'delivered': color = Colors.green; text = 'مكتمل بالسلامة'; break;
      case 'cancelled': color = Colors.red; text = 'ملغي'; break;
      default: color = Colors.grey; text = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10.sp, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDriverInfoCard(Map<String, dynamic> data, bool isDark) {
    final driverName = data['driverName']?.toString() ?? '';
    final driverPhone = data['driverPhone']?.toString() ?? '';
    final driverCar = data['driverCar']?.toString() ?? '';
    final driverImage = data['driverImage']?.toString() ?? '';
    final driverRating = (data['driverRating'] ?? 5.0).toDouble();

    if (driverName.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(top: 15.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242731) : Colors.teal.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.teal.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'مندوب التوصيل المعيّن',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              CircleAvatar(
                radius: 24.r,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                backgroundImage: driverImage.isNotEmpty ? NetworkImage(driverImage) : null,
                child: driverImage.isEmpty ? Icon(Icons.person, color: AppTheme.primaryColor, size: 24.sp) : null,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (driverCar.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        driverCar,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isDark ? Colors.grey : Colors.black54,
                        ),
                      ),
                    ],
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: Colors.amber, size: 14.sp),
                        SizedBox(width: 4.w),
                        Text(
                          driverRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (driverPhone.isNotEmpty)
                IconButton(
                  onPressed: () async {
                    final url = Uri.parse('tel:$driverPhone');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  icon: Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 20.sp),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.all(10.r),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndPrintPdf(String? uid, bool isDark) async {
    if (uid == null) return;

    // Show loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري تجهيز التقرير...', style: TextStyle())),
    );

    try {
      final pdf = pw.Document();
      final fontData = await rootBundle.load("Cairo-Regular.ttf");
      final ttf = pw.Font.ttf(fontData);

      // Fetch all orders from madar_orders collection
      final restaurantOrders = await FirebaseFirestore.instance.collection('madar_orders').doc(uid).collection('orders').orderBy('createdAt', descending: true).get();
      final storeOrders = await FirebaseFirestore.instance.collection('madar_orders').doc(uid).collection('store_orders').orderBy('createdAt', descending: true).get();

      final allOrders = [...restaurantOrders.docs, ...storeOrders.docs];
      allOrders.sort((a, b) {
        final dateA = a.data()['createdAt'] as Timestamp?;
        final dateB = b.data()['createdAt'] as Timestamp?;
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });

      // Calculate Statistics
      double totalSpent = 0;
      int completedOrders = 0;
      int cancelledOrders = 0;
      for (var doc in allOrders) {
        final data = doc.data();
        totalSpent += (data['total'] ?? 0).toDouble();
        final status = data['status'] ?? 'pending';
        if (status == 'completed') completedOrders++;
        if (status == 'cancelled') cancelledOrders++;
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: ttf),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('تقرير طلبات تطبيق مدار', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: ttf, color: PdfColors.teal800)),
                    pw.Text(DateFormat('yyyy/MM/dd').format(DateTime.now()), style: pw.TextStyle(fontSize: 12, font: ttf)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Statistics Summary Cards
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildPdfStatItem('إجمالي الإنفاق', '${NumberFormat('#,###').format(totalSpent)} د.ع', ttf),
                    _buildPdfStatItem('الطلبات', '${allOrders.length}', ttf),
                    _buildPdfStatItem('المكتملة', '$completedOrders', ttf),
                    _buildPdfStatItem('الملغية', '$cancelledOrders', ttf),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                cellAlignment: pw.Alignment.centerRight,
                data: <List<String>>[
                  <String>['#', 'التاريخ', 'النوع', 'الجهة', 'المبلغ', 'الحالة'],
                  ...allOrders.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final doc = entry.value;
                    final data = doc.data();
                    final isStore = doc.reference.path.contains('store_orders');
                    final createdAt = data['createdAt'] as Timestamp?;
                    final date = createdAt != null ? DateFormat('MM/dd HH:mm').format(createdAt.toDate()) : '-';
                    final title = isStore ? (data['storeName'] ?? 'متجر') : 'مطعم';
                    final total = (data['total'] ?? 0).toStringAsFixed(0);
                    final statusRaw = data['status'] ?? 'pending';
                    String statusText = '';
                    switch (statusRaw) {
                      case 'pending': statusText = 'انتظار'; break;
                      case 'accepted': statusText = 'مقبول'; break;
                      case 'delivering': statusText = 'توصيل'; break;
                      case 'completed': statusText = 'مكتمل'; break;
                      case 'cancelled': statusText = 'ملغي'; break;
                      default: statusText = statusRaw;
                    }
                    return [
                      '$index',
                      date,
                      isStore ? 'متجر' : 'مطعم',
                      title,
                      '$total د.ع',
                      statusText,
                    ];
                  }),
                ],
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 20),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('تم استخراج هذا التقرير عبر تطبيق مدار', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey, font: ttf)),
                    pw.Text('نهاية التقرير', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey, font: ttf)),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في إنشاء ملف PDF: $e', style: const TextStyle())),
      );
    }
  }

  pw.Widget _buildPdfStatItem(String label, String value, pw.Font font) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, font: font)),
        pw.SizedBox(height: 5),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: font)),
      ],
    );
  }
}
