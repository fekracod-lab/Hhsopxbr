import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/responsive/madar_responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/error/madar_crash_guard.dart';

/// نموذج كود الخصم والكوبون
class CouponItem {
  final String id;
  final String code;
  final String title;
  final String discountType; // 'percentage' أو 'fixed'
  final double discountValue;
  final double minOrderAmount;
  final DateTime? expiryDate;
  final int usageCount;
  final bool isActive;

  const CouponItem({
    required this.id,
    required this.code,
    required this.title,
    required this.discountType,
    required this.discountValue,
    this.minOrderAmount = 0.0,
    this.expiryDate,
    this.usageCount = 0,
    this.isActive = true,
  });

  factory CouponItem.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    DateTime? exp;
    if (d['expiryDate'] is Timestamp) {
      exp = (d['expiryDate'] as Timestamp).toDate();
    }
    return CouponItem(
      id: doc.id,
      code: (d['code'] ?? 'COUPON').toString().toUpperCase(),
      title: (d['title'] ?? 'عرض خاص').toString(),
      discountType: (d['discountType'] ?? 'percentage').toString(),
      discountValue: (d['discountValue'] ?? 10).toDouble(),
      minOrderAmount: (d['minOrderAmount'] ?? 0).toDouble(),
      expiryDate: exp,
      usageCount: (d['usageCount'] ?? 0) as int,
      isActive: d['isActive'] ?? true,
    );
  }
}

/// شاشة إدارة العروض والكوبونات في منظومة مطاعم مدار
class CouponsPage extends StatefulWidget {
  const CouponsPage({super.key});

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _activeId = '';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _resolveRestaurantId();
  }

  Future<void> _resolveRestaurantId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    setState(() => _activeId = uid);
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        final rid = data?['restaurantId'] as String?;
        if (rid != null && rid.isNotEmpty && rid != uid) {
          setState(() => _activeId = rid);
        }
      }
    } catch (_) {}
  }

  CollectionReference _couponsRef() {
    final id = _activeId.isNotEmpty ? _activeId : _uid;
    return FirebaseFirestore.instance
        .collection('merchant_coupons')
        .doc(id)
        .collection('coupons');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeCrashBoundary(
          child: StreamBuilder<QuerySnapshot>(
            stream: (_activeId.isEmpty && _uid.isEmpty) ? null : _couponsRef().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final coupons = (snapshot.data?.docs ?? [])
                  .map((d) => CouponItem.fromFirestore(d))
                  .toList();

              final filtered = coupons.where((cp) {
                return _searchQuery.isEmpty ||
                    cp.code.contains(_searchQuery.toUpperCase()) ||
                    cp.title.contains(_searchQuery);
              }).toList();

              final totalCount = coupons.length;
              final activeCount = coupons.where((cp) => cp.isActive).length;
              final totalUsage = coupons.fold(0, (s, cp) => s + cp.usageCount);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. الترويسة
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'العروض والكوبونات وأكواد الخصم',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'إدارة حملات التخفيض، ونسب الخصم المئوية والمبالغ الثابتة المطبقة في الكاشير والتطبيق',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => _showAddCouponDialog(context),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: Text(
                            'إنشاء كود خصم جديد',
                            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    if (coupons.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: c.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.local_offer_outlined, size: 56, color: c.primary),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد عروض أو كوبونات خصم مسجلة',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'قم بإنشاء أكواد خصم ترويجية لجذب الزبائن وزيادة مبيعات مطعمك',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.textMuted),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => _showAddCouponDialog(context),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text('إنشاء أول كود خصم', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: c.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      // 2. بطاقات الإحصائيات
                      Row(
                        children: [
                          _buildStatCard(
                            title: 'إجمالي الكوبونات',
                            value: '$totalCount',
                            icon: Icons.confirmation_number_rounded,
                            color: const Color(0xFF8B5CF6),
                            bg: const Color(0xFFFAF5FF),
                          ),
                        const SizedBox(width: 14),
                        _buildStatCard(
                          title: 'الكوبونات السارية',
                          value: '$activeCount',
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF10B981),
                          bg: const Color(0xFFECFDF5),
                        ),
                        const SizedBox(width: 14),
                        _buildStatCard(
                          title: 'مرات استخدام الأكواد',
                          value: '$totalUsage عملية',
                          icon: Icons.local_fire_department_rounded,
                          color: const Color(0xFFFF5B22),
                          bg: const Color(0xFFFFF7ED),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 3. شريط البحث
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: c.textMuted, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setState(() => _searchQuery = v.trim()),
                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'ابحث برمز الكوبون أو عنوان العرض...',
                                hintStyle: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 4. شبكة بطاقات الكوبونات
                    if (filtered.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            children: [
                              Icon(Icons.confirmation_number_outlined, size: 60, color: c.textDisabled),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد كوبونات تطابق البحث',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 15, fontWeight: FontWeight.bold, color: c.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth >= 1100 ? 3 : (constraints.maxWidth >= 700 ? 2 : 1);
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 1.6,
                            ),
                            itemBuilder: (context, idx) {
                              final cp = filtered[idx];
                              return _buildCouponCard(context, cp);
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCouponCard(BuildContext context, CouponItem cp) {
    final c = context.posColors;
    final isPercent = cp.discountType == 'percentage';

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cp.isActive ? c.border : c.border.withValues(alpha: 0.5)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5B22).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.confirmation_number_rounded, color: Color(0xFFFF5B22), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: c.border),
                            ),
                            child: Text(
                              cp.code,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: c.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cp.title,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: cp.isActive ? c.textPrimary : c.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPercent ? 'خصم ${cp.discountValue.toInt()}%' : 'خصم ${NumberFormat('#,###').format(cp.discountValue)} د.ع',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (cp.minOrderAmount > 0)
                      Text(
                        'حد أدنى: ${NumberFormat('#,###').format(cp.minOrderAmount)} د.ع',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                      ),
                  ],
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'استُخدم ${cp.usageCount} مرة',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
                    ),
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.75,
                          child: Switch(
                            value: cp.isActive,
                            activeTrackColor: c.primary,
                            onChanged: (_) => _toggleStatus(cp),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                          onPressed: () => _confirmDelete(context, cp),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    final c = context.posColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 20, fontWeight: FontWeight.w900, color: c.textPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCouponDialog(BuildContext context) {
    final c = context.posColors;
    final codeCtrl = TextEditingController();
    final titleCtrl = TextEditingController();
    final valCtrl = TextEditingController(text: '10');
    final minCtrl = TextEditingController(text: '0');
    String discountType = 'percentage'; // 'percentage' أو 'fixed'

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('إنشاء كود خصم جديد', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: MadarResponsive.dialogWidth(context, maxWidth: 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('رمز الكوبون (الرمز الإنجليزي)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'مثال: MADAR15 أو VIP5000',
                          filled: true,
                          fillColor: c.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('عنوان العرض / المناسبة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          hintText: 'مثال: خصم الافتتاح، عرض نهاية الأسبوع...',
                          filled: true,
                          fillColor: c.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('نوع الخصم', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => discountType = 'percentage'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: discountType == 'percentage' ? c.primary.withValues(alpha: 0.12) : c.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: discountType == 'percentage' ? c.primary : c.border,
                                    width: discountType == 'percentage' ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      discountType == 'percentage' ? Icons.radio_button_checked : Icons.radio_button_off,
                                      size: 16,
                                      color: discountType == 'percentage' ? c.primary : c.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text('نسبة مئوية (%)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: discountType == 'percentage' ? FontWeight.bold : FontWeight.normal)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => discountType = 'fixed'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: discountType == 'fixed' ? c.primary.withValues(alpha: 0.12) : c.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: discountType == 'fixed' ? c.primary : c.border,
                                    width: discountType == 'fixed' ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      discountType == 'fixed' ? Icons.radio_button_checked : Icons.radio_button_off,
                                      size: 16,
                                      color: discountType == 'fixed' ? c.primary : c.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text('مبلغ ثابت (د.ع)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: discountType == 'fixed' ? FontWeight.bold : FontWeight.normal)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Text(discountType == 'percentage' ? 'نسبة الخصم (%)' : 'قيمة الخصم (د.ع)',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: valCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: discountType == 'percentage' ? 'مثال: 10 أو 15 أو 20' : 'مثال: 3000 أو 5000',
                          filled: true,
                          fillColor: c.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('الحد الأدنى لقيمة الطلب (د.ع)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: minCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '0 بدون حد أدنى، أو 15000...',
                          filled: true,
                          fillColor: c.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final code = codeCtrl.text.trim().toUpperCase();
                    if (code.isEmpty) return;

                    final payload = {
                      'restaurantId': _activeId,
                      'code': code,
                      'title': titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : 'عرض ترويجي',
                      'discountType': discountType,
                      'discountValue': double.tryParse(valCtrl.text.trim()) ?? 10.0,
                      'minOrderAmount': double.tryParse(minCtrl.text.trim()) ?? 0.0,
                      'usageCount': 0,
                      'isActive': true,
                      'createdAt': FieldValue.serverTimestamp(),
                    };

                    if (_activeId.isNotEmpty) {
                      await _couponsRef().add(payload);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('تفعيل الكود', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _toggleStatus(CouponItem cp) async {
    if (_activeId.isEmpty) return;
    try {
      await _couponsRef().doc(cp.id).set({
        'isActive': !cp.isActive,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _confirmDelete(BuildContext context, CouponItem cp) {
    final c = context.posColors;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          title: Text('حذف الكوبون؟', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من حذف كود الخصم "${cp.code}"؟', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_activeId.isNotEmpty) {
                  await _couponsRef().doc(cp.id).delete();
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              child: Text('حذف', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
