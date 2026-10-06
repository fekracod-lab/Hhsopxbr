import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:ui';

class UserPointsPage extends StatefulWidget {
  const UserPointsPage({super.key});

  @override
  State<UserPointsPage> createState() => _UserPointsPageState();
}

class _UserPointsPageState extends State<UserPointsPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 50 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 50 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // Background Gradient Blob
          Positioned(
            top: -100.h,
            right: -50.w,
            child: Container(
              width: 300.r,
              height: 300.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildModernAppBar(isDark),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 20.h),
                      _buildMainBalanceCard(isDark, user?.uid),
                      SizedBox(height: 24.h),
                      _buildQuickStats(isDark, user?.uid),
                      SizedBox(height: 32.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'سجل العمليات الأخير',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                            ),
                          ),
                          Text(
                            'عرض الكل',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),
              _buildPointsHistoryList(isDark, user?.uid),
              SliverToBoxAdapter(child: SizedBox(height: 100.h)),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomCTA(isDark),
    );
  }

  Widget _buildModernAppBar(bool isDark) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 100.h,
      backgroundColor: _isScrolled 
          ? (isDark ? const Color(0xFF12121A) : Colors.white)
          : Colors.transparent,
      elevation: _isScrolled ? 2 : 0,
      centerTitle: true,
      title: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _isScrolled ? 1 : 0,
        child: const Text(
          'نقاطي',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      leading: IconButton(
        icon: Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: _isScrolled ? Colors.transparent : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded, size: 18.sp),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.help_outline_rounded, size: 22.sp),
          onPressed: () => _showPointsHelpSheet(context, isDark),
        ),
      ],
    );
  }

  Widget _buildMainBalanceCard(bool isDark, String? uid) {
    if (uid == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildShimmerBalance();
        
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final points = data['points'] ?? 0;

        return Container(
          width: double.infinity,
          height: 180.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E293B),
                isDark ? const Color(0xFF0F172A) : const Color(0xFF334155),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                right: -20,
                top: -20,
                child: Icon(Icons.stars_rounded, size: 150, color: Colors.white.withValues(alpha: 0.05)),
              ),
              
              Padding(
                padding: EdgeInsets.all(24.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        SizedBox(width: 4.w),
                        SizedBox(width: 12.w),
                        Text(
                          'رصيد النقاط المتاح',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.white60,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$points',
                          style: TextStyle(
                            fontSize: 42.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 12.h, right: 8.w),
                          child: Text(
                            'نقطة مكافأة',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildQuickStats(bool isDark, String? uid) {
    if (uid == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('madar_orders')
          .where('customerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        int totalTransactions = 0;
        int totalRedeemed = 0;

        if (snapshot.hasData) {
          totalTransactions = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalRedeemed += (data['pointsUsed'] as num? ?? 0).toInt();
          }
        }

        return Row(
          children: [
            Expanded(
              child: _buildStatItem(
                isDark,
                'العمليات',
                snapshot.hasData ? '$totalTransactions' : '...',
                Icons.swap_horiz_rounded,
                Colors.blue,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _buildStatItem(
                isDark,
                'تم استرداده',
                snapshot.hasData ? NumberFormat('#,###').format(totalRedeemed) : '...',
                Icons.card_giftcard_rounded,
                Colors.purple,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(bool isDark, String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D26) : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16.sp,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointsHistoryList(bool isDark, String? uid) {
    if (uid == null) return const SliverToBoxAdapter(child: SizedBox());

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('madar_orders')
          .where('customerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _buildErrorState();
        if (!snapshot.hasData) return _buildShimmerList();

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return _buildEmptyState(isDark);

        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final points = (data['pointsEarned'] as num? ?? 0).toInt();
                final storeName = data['storeName'] ?? 'متجر غير معروف';
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                final dateStr = createdAt != null ? DateFormat('dd MMM yyyy').format(createdAt) : '';

                if (points == 0) return const SizedBox.shrink();

                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 400),
                  child: FadeInAnimation(
                    child: SlideAnimation(
                      verticalOffset: 20,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1D26) : Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48.r,
                              height: 48.r,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.add_shopping_cart_rounded, color: AppTheme.primaryColor, size: 20.sp),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    storeName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                '+$points',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: docs.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomCTA(bool isDark) {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12121A) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 20, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () => _showRedeemPointsSheet(context, isDark),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 56.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            elevation: 8,
            shadowColor: AppTheme.primaryColor.withValues(alpha: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.redeem_rounded, size: 20.sp),
              SizedBox(width: 12.w),
              Text(
                'استبدال النقاط بمكافآت',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPointsHelpSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1D26) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stars_rounded, color: AppTheme.primaryColor, size: 28.sp),
                SizedBox(width: 8.w),
                Text(
                  'نظام مكافآت مدار 🌟',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Text(
              '• تجمع نقطة واحدة لكل 1,000 د.ع تصرفها على أي رحلة تكسي أو طلب طعام أو مشتريات من المتاجر.\n• النقاط لا تنتهي صلاحيتها وتتراكم تلقائياً في محفظتك.\n• تكدر تستبدل نقاطك بكوبونات خصم مباشرة على مشاويرك وطلباتك القادمة.',
              style: TextStyle(fontSize: 14.sp, height: 1.6),
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('فهمت، عاشت إيدكم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRedeemPointsSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1D26) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard_rounded, color: AppTheme.primaryColor, size: 28.sp),
                SizedBox(width: 8.w),
                Text(
                  'المكافآت المتاحة للاستبدال',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_taxi_rounded, color: Colors.amber),
              ),
              title: const Text('خصم 2,000 د.ع على مشوار تكسي', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('يتطلب 50 نقطة'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تفعيل خصم التكسي بنجاح على مشوارك القادم 🚕'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('استبدال', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.restaurant_rounded, color: Colors.green),
              ),
              title: const Text('خصم 5,000 د.ع على طلب مطاعم', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('يتطلب 100 نقطة'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تفعيل كوبون خصم المطاعم بنجاح 🍔'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('استبدال', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBalance() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.withValues(alpha: 0.2),
      highlightColor: Colors.grey.withValues(alpha: 0.1),
      child: Container(
        width: double.infinity,
        height: 180.h,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32.r)),
      ),
    );
  }

  Widget _buildShimmerList() {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Shimmer.fromColors(
            baseColor: Colors.grey.withValues(alpha: 0.1),
            highlightColor: Colors.grey.withValues(alpha: 0.05),
            child: Container(
              height: 80.h,
              margin: EdgeInsets.only(bottom: 12.h),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r)),
            ),
          ),
          childCount: 5,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(40.r),
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded, size: 48.sp, color: Colors.red.withValues(alpha: 0.5)),
              SizedBox(height: 16.h),
              const Text(
                'يتطلب هذا البحث تفعيل الفهرس في Firebase\nيرجى مراجعة الرابط المرسل مسبقاً',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64.sp, color: Colors.grey.withValues(alpha: 0.2)),
            SizedBox(height: 16.h),
            Text(
              'لا توجد حركات نقاط حالياً',
              style: TextStyle(color: Colors.grey.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}
