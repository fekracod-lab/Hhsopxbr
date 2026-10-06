import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';

class MadarPointsPage extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic> storeData;

  const MadarPointsPage({
    super.key,
    required this.storeId,
    required this.storeData,
  });

  @override
  State<MadarPointsPage> createState() => _MadarPointsPageState();
}

class _MadarPointsPageState extends State<MadarPointsPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1219) : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummarySection(isDark),
                  SizedBox(height: 24.h),
                  _buildSettingsSection(isDark),
                  SizedBox(height: 24.h),
                  _buildRecentTransactionsHeader(isDark),
                ],
              ),
            ),
          ),
          _buildTransactionsList(isDark),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 180.h,
      pinned: true,
      stretch: true,
      backgroundColor: isDark ? const Color(0xFF1A1D26) : AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'نقاط مدار',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18.sp,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.8),
                    const Color(0xFF6C63FF),
                  ],
                ),
              ),
            ),
            Positioned(
              right: -50.w,
              top: -20.h,
              child: Icon(
                Icons.stars_rounded,
                size: 200.sp,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildSummarySection(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .collection('madar_orders')
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        int totalPointsAwarded = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalPointsAwarded += (data['pointsEarned'] as num? ?? 0).toInt();
          }
        }

        return Container(
          padding: EdgeInsets.all(24.r),
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
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.stars_rounded, color: Colors.amber, size: 30.sp),
                  ),
                  SizedBox(width: 16.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إجمالي النقاط الممنوحة',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '$totalPointsAwarded نقطة',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Divider(color: Colors.grey.withValues(alpha: 0.1)),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat('الطلبات المكتملة', '${snapshot.data?.docs.length ?? 0}', Icons.check_circle_outline_rounded, Colors.green),
                  _buildMiniStat('قيد المعالجة', '...', Icons.hourglass_empty_rounded, Colors.orange),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18.sp),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إعدادات النقاط',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D26) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.settings_suggest_rounded, color: AppTheme.primaryColor, size: 22.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نظام المكافآت الحالي',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'نقطة واحدة لكل 1000 د.ع من قيمة الطلب',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showEditPointsRuleDialog(context, isDark),
                child: Text(
                  'تعديل',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactionsHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'آخر العمليات',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          'عرض الكل',
          style: TextStyle(
            fontSize: 12.sp,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeId)
          .collection('madar_orders')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Text(
                'ماكو عمليات حالياً',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;
              final points = (data['pointsEarned'] as num? ?? 0).toInt();
              final customer = data['customerName'] ?? 'زبون';
              final status = data['status'] ?? 'pending';
              final time = (data['createdAt'] as Timestamp?)?.toDate();

              if (points == 0) return const SizedBox.shrink();

              return Container(
                margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1D26) : Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44.r, height: 44.r,
                      decoration: BoxDecoration(
                        color: status == 'completed' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        status == 'completed' ? Icons.add_circle_outline_rounded : Icons.history_rounded,
                        color: status == 'completed' ? Colors.green : Colors.orange,
                        size: 24.sp,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                            ),
                          ),
                          Text(
                            status == 'completed' ? 'تم منح نقاط للطلب' : 'طلب قيد المعالجة',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+$points',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.green,
                          ),
                        ),
                        if (time != null)
                          Text(
                            '${time.day}/${time.month}',
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
            childCount: orders.length,
          ),
        );
      },
    );
  }

  void _showEditPointsRuleDialog(BuildContext context, bool isDark) {
    int selectedPointsPerThousand = 1;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1D26) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: const Text(
            'تعديل نسبة النقاط والمكافآت',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'حدد عدد النقاط الممنوحة للزبون مقابل كل 1,000 د.ع من قيمة الطلب:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [1, 2, 3, 5].map((rate) {
                  final isSelected = selectedPointsPerThousand == rate;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text('$rate نقطة'),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                      onSelected: (selected) {
                        if (selected) {
                          setModalState(() {
                            selectedPointsPerThousand = rate;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('stores')
                      .doc(widget.storeId)
                      .set({
                    'rewardPointsPer1000Iqd': selectedPointsPerThousand,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                } catch (_) {}
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تحديث نظام المكافآت إلى $selectedPointsPerThousand نقطة لكل 1,000 د.ع بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text(
                'حفظ التعديل',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
