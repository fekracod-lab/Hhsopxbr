import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/error/madar_crash_guard.dart';

/// نموذج منطقة التوصيل
class DeliveryZone {
  final String id;
  final String name;
  final double deliveryFee;
  final int estimatedMinutes;
  final double minOrder;
  final bool isFreeDelivery;
  final bool isActive;

  const DeliveryZone({
    required this.id,
    required this.name,
    required this.deliveryFee,
    this.estimatedMinutes = 30,
    this.minOrder = 0,
    this.isFreeDelivery = false,
    this.isActive = true,
  });

  factory DeliveryZone.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    return DeliveryZone(
      id: doc.id,
      name: d['name'] ?? 'منطقة',
      deliveryFee: (d['deliveryFee'] ?? d['fee'] ?? 2000).toDouble(),
      estimatedMinutes: (d['estimatedMinutes'] ?? 30) as int,
      minOrder: (d['minOrder'] ?? 0).toDouble(),
      isFreeDelivery: d['isFreeDelivery'] ?? false,
      isActive: d['isActive'] ?? true,
    );
  }
}

/// شاشة إدارة مناطق التوصيل وأجور النقل في نظام مطاعم مدار
class DeliveryZonesPage extends StatefulWidget {
  const DeliveryZonesPage({super.key});

  @override
  State<DeliveryZonesPage> createState() => _DeliveryZonesPageState();
}

class _DeliveryZonesPageState extends State<DeliveryZonesPage> {
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

  CollectionReference _zonesRef() {
    final id = _activeId.isNotEmpty ? _activeId : _uid;
    return FirebaseFirestore.instance
        .collection('merchant_zones')
        .doc(id)
        .collection('zones');
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
            stream: (_activeId.isEmpty && _uid.isEmpty) ? null : _zonesRef().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final zones = (snapshot.data?.docs ?? [])
                  .map((d) => DeliveryZone.fromFirestore(d))
                  .toList();

              final filtered = zones.where((z) {
                return _searchQuery.isEmpty || z.name.contains(_searchQuery);
              }).toList();

              final totalZones = zones.length;
              final activeZones = zones.where((z) => z.isActive).length;
              final avgFee = zones.isNotEmpty ? (zones.map((z) => z.deliveryFee).reduce((a, b) => a + b) / zones.length) : 2500.0;

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
                              'إدارة مناطق التوصيل والأجور',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'تحديد الأحياء والمناطق المغطاة بالتوصيل في القائم، وتحديد أجور الكابتن والوقت المتوقع',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => _showZoneDialog(context, null),
                          icon: const Icon(Icons.add_location_alt_rounded, size: 20),
                          label: Text(
                            'إضافة منطقة جديدة',
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

                    if (zones.isEmpty)
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
                                child: Icon(Icons.two_wheeler_rounded, size: 56, color: c.primary),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد مناطق توصيل مخصصة حالياً',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'يمكنك إضافة أحياء ومناطق القائم وتحديد أجور الكابتن، أو استيراد الأحياء الأساسية بنقرة واحدة',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.textMuted),
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 12,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _importDefaultZones,
                                    icon: const Icon(Icons.download_rounded, size: 18),
                                    label: Text('استيراد أحياء القائم الأساسية', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: c.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _showZoneDialog(context, null),
                                    icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                                    label: Text('إضافة منطقة يدوياً', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: c.textPrimary,
                                      side: BorderSide(color: c.border),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
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
                            title: 'إجمالي المناطق',
                            value: '$totalZones منطقة',
                            icon: Icons.map_rounded,
                            color: const Color(0xFF3B82F6),
                            bg: const Color(0xFFEFF6FF),
                          ),
                        const SizedBox(width: 14),
                        _buildStatCard(
                          title: 'المناطق المغطاة حالياً',
                          value: '$activeZones نشطة',
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF10B981),
                          bg: const Color(0xFFECFDF5),
                        ),
                        const SizedBox(width: 14),
                        _buildStatCard(
                          title: 'متوسط أجور التوصيل',
                          value: '${NumberFormat('#,###').format(avgFee)} د.ع',
                          icon: Icons.two_wheeler_rounded,
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
                                hintText: 'ابحث عن منطقة أو حي سكني...',
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

                    // 4. شبكة بطاقات المناطق
                    if (filtered.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            children: [
                              Icon(Icons.location_off_rounded, size: 60, color: c.textDisabled),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد مناطق تطابق البحث',
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
                              childAspectRatio: 1.65,
                            ),
                            itemBuilder: (context, idx) {
                              final zone = filtered[idx];
                              return _buildZoneCard(context, zone);
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

  Widget _buildZoneCard(BuildContext context, DeliveryZone zone) {
    final c = context.posColors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: zone.isActive ? c.border : c.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_rounded, color: Color(0xFF3B82F6), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zone.name,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: zone.isActive ? c.textPrimary : c.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'وقت الوصول التقديري: ${zone.estimatedMinutes} دقيقة',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 18, color: c.textMuted),
                onPressed: () => _showZoneDialog(context, zone),
              ),
            ],
          ),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: zone.deliveryFee == 0
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFFF5B22).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  zone.deliveryFee == 0 ? 'توصيل مجاني 🛵' : '${NumberFormat('#,###').format(zone.deliveryFee)} د.ع',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: zone.deliveryFee == 0 ? const Color(0xFF10B981) : const Color(0xFFFF5B22),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (zone.minOrder > 0)
                Text(
                  'أدنى طلب: ${NumberFormat('#,###').format(zone.minOrder)} د.ع',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                ),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: zone.isActive
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFF6B7280).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  zone.isActive ? 'متاح للطلب' : 'معطل مؤقتاً',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: zone.isActive ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                  ),
                ),
              ),
              Row(
                children: [
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: zone.isActive,
                      activeTrackColor: c.primary,
                      onChanged: (_) => _toggleStatus(zone),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                    onPressed: () => _confirmDelete(context, zone),
                  ),
                ],
              ),
            ],
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

  void _showZoneDialog(BuildContext context, DeliveryZone? existing) {
    final c = context.posColors;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final feeCtrl = TextEditingController(text: existing != null ? '${existing.deliveryFee.toInt()}' : '2000');
    final timeCtrl = TextEditingController(text: existing != null ? '${existing.estimatedMinutes}' : '30');
    final minCtrl = TextEditingController(text: existing != null ? '${existing.minOrder.toInt()}' : '0');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            existing == null ? 'إضافة منطقة توصيل جديدة' : 'تعديل منطقة التوصيل',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اسم الحي أو المنطقة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'مثال: حي السكك، الكرابلة، العبيدي...',
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('أجرة التوصيل (د.ع)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: feeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0 للمجاني، أو 2000، 3000...',
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('الوقت التقديري للوصول (بالدقائق)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: timeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'مثال: 25 أو 35 أو 45 دقيقة',
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
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final payload = {
                  'restaurantId': _activeId,
                  'name': name,
                  'deliveryFee': double.tryParse(feeCtrl.text.trim()) ?? 2000.0,
                  'estimatedMinutes': int.tryParse(timeCtrl.text.trim()) ?? 30,
                  'minOrder': double.tryParse(minCtrl.text.trim()) ?? 0.0,
                  'isActive': existing?.isActive ?? true,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (_activeId.isNotEmpty) {
                  if (existing == null) {
                    payload['createdAt'] = FieldValue.serverTimestamp();
                    await _zonesRef().add(payload);
                  } else {
                    await _zonesRef().doc(existing.id).set(payload, SetOptions(merge: true));
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('حفظ المنطقة', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importDefaultZones() async {
    final id = _activeId.isNotEmpty ? _activeId : _uid;
    if (id.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final defaults = _getDefaultAlQaimZones();
      for (final z in defaults) {
        final docRef = _zonesRef().doc();
        batch.set(docRef, {
          'restaurantId': id,
          'name': z.name,
          'deliveryFee': z.deliveryFee,
          'estimatedMinutes': z.estimatedMinutes,
          'minOrder': z.minOrder,
          'isFreeDelivery': z.isFreeDelivery,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم استيراد أحياء ومناطق القائم بنجاح'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الاستيراد: $e')),
        );
      }
    }
  }

  void _toggleStatus(DeliveryZone zone) async {
    if (_activeId.isEmpty) return;
    try {
      await _zonesRef().doc(zone.id).set({
        'isActive': !zone.isActive,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _confirmDelete(BuildContext context, DeliveryZone zone) {
    final c = context.posColors;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          title: Text('حذف المنطقة؟', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من حذف منطقة "${zone.name}"؟', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_activeId.isNotEmpty) {
                  await _zonesRef().doc(zone.id).delete();
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

  List<DeliveryZone> _getDefaultAlQaimZones() {
    return const [
      DeliveryZone(id: 'z1', name: 'حي القائم والمركز', deliveryFee: 2000, estimatedMinutes: 20),
      DeliveryZone(id: 'z2', name: 'حي السكك والحي الصناعي', deliveryFee: 2500, estimatedMinutes: 30),
      DeliveryZone(id: 'z3', name: 'مجمع الفوسفات السكني', deliveryFee: 3000, estimatedMinutes: 35),
      DeliveryZone(id: 'z4', name: 'ناحية الكرابلة', deliveryFee: 3000, estimatedMinutes: 30),
      DeliveryZone(id: 'z5', name: 'حصيبة والقرى المجاورة', deliveryFee: 3500, estimatedMinutes: 40),
      DeliveryZone(id: 'z6', name: 'ناحية العبيدي', deliveryFee: 4000, estimatedMinutes: 45),
    ];
  }
}
