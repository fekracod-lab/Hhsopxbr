import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/responsive/madar_responsive.dart';
import '../../../../core/error/madar_crash_guard.dart';

/// نموذج بيانات المورد
class SupplierItem {
  final String id;
  final String companyName;
  final String contactPerson;
  final String phone;
  final String supplyType;
  final double balanceDue; // الرصيد المستحق (الديون)
  final String address;
  final String notes;

  const SupplierItem({
    required this.id,
    required this.companyName,
    required this.contactPerson,
    required this.phone,
    required this.supplyType,
    this.balanceDue = 0.0,
    this.address = '',
    this.notes = '',
  });

  factory SupplierItem.fromFirestore(DocumentSnapshot doc) {
    try {
      final d = (doc.data() as Map<String, dynamic>?) ?? {};
      double parseAmount(dynamic val) {
        if (val is num) return val.toDouble();
        if (val is String) {
          final clean = val.replaceAll(',', '').replaceAll('د.ع', '').trim();
          return double.tryParse(clean) ?? 0.0;
        }
        return 0.0;
      }

      return SupplierItem(
        id: doc.id,
        companyName: (d['companyName'] ?? d['name'] ?? 'مورد').toString(),
        contactPerson: (d['contactPerson'] ?? '').toString(),
        phone: (d['phone'] ?? '—').toString(),
        supplyType: (d['supplyType'] ?? 'لحوم ودواجن').toString(),
        balanceDue: parseAmount(d['balanceDue'] ?? d['balance']),
        address: (d['address'] ?? '').toString(),
        notes: (d['notes'] ?? '').toString(),
      );
    } catch (_) {
      return SupplierItem(
        id: doc.id,
        companyName: 'مورد مسجل',
        contactPerson: '',
        phone: '—',
        supplyType: 'عام',
      );
    }
  }
}

/// شاشة إدارة الموردين والشركات في نظام مطاعم مدار
class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
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

  CollectionReference _suppliersRef() {
    final id = _activeId.isNotEmpty ? _activeId : _uid;
    return FirebaseFirestore.instance
        .collection('merchant_suppliers')
        .doc(id)
        .collection('suppliers');
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
            stream: (_activeId.isEmpty && _uid.isEmpty) ? null : _suppliersRef().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final list = (snapshot.data?.docs ?? [])
                  .map((d) => SupplierItem.fromFirestore(d))
                  .toList();

              final filtered = list.where((s) {
                return _searchQuery.isEmpty ||
                    s.companyName.contains(_searchQuery) ||
                    s.contactPerson.contains(_searchQuery) ||
                    s.phone.contains(_searchQuery) ||
                    s.supplyType.contains(_searchQuery);
              }).toList();

              final totalSuppliers = list.length;
              final totalDue = list.fold(0.0, (acc, s) => acc + s.balanceDue);
              final activeCount = list.where((s) => s.balanceDue > 0).length;

              return SingleChildScrollView(
                padding: EdgeInsets.all(MadarResponsive.contentPadding(context)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. الترويسة
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 650;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'سجل الموردين والشركات المعتمدة',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'إدارة جهات توريد اللحوم، الخضار، مواد التعبئة والتغليف، ومتابعة الأرصدة والديون المستحقة',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12.5,
                                  color: c.textMuted,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddSupplierDialog(context),
                                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                                  label: Text(
                                    'إضافة مورد جديد',
                                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: c.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'سجل الموردين والشركات المعتمدة',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'إدارة جهات توريد اللحوم، الخضار، مواد التعبئة والتغليف، ومتابعة الأرصدة والديون المستحقة',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 13,
                                    color: c.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () => _showAddSupplierDialog(context),
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                              label: Text(
                                'إضافة مورد جديد',
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
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    if (list.isEmpty)
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
                                child: Icon(Icons.local_shipping_outlined, size: 56, color: c.primary),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا يوجد موردون مسجلون حالياً',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'قم بإضافة الموردين والشركات المعتمدة لمتابعة المشتريات والأرصدة المستحقة',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.textMuted),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => _showAddSupplierDialog(context),
                                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                                label: Text('إضافة أول مورد', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          if (w < 700) {
                            return Column(
                              children: [
                                _buildStatCard(
                                  title: 'إجمالي الموردين',
                                  value: '$totalSuppliers مورد',
                                  icon: Icons.local_shipping_rounded,
                                  color: const Color(0xFF3B82F6),
                                  bg: const Color(0xFFEFF6FF),
                                ),
                                const SizedBox(height: 10),
                                _buildStatCard(
                                  title: 'موردين بحسابات آجلة',
                                  value: '$activeCount مورد',
                                  icon: Icons.account_balance_rounded,
                                  color: const Color(0xFFF59E0B),
                                  bg: const Color(0xFFFFFBEB),
                                ),
                                const SizedBox(height: 10),
                                _buildStatCard(
                                  title: 'إجمالي الديون المستحقة للموردين',
                                  value: '${NumberFormat('#,###').format(totalDue)} د.ع',
                                  icon: Icons.money_off_rounded,
                                  color: const Color(0xFFEF4444),
                                  bg: const Color(0xFFFEF2F2),
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  title: 'إجمالي الموردين',
                                  value: '$totalSuppliers مورد',
                                  icon: Icons.local_shipping_rounded,
                                  color: const Color(0xFF3B82F6),
                                  bg: const Color(0xFFEFF6FF),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'موردين بحسابات آجلة',
                                  value: '$activeCount مورد',
                                  icon: Icons.account_balance_rounded,
                                  color: const Color(0xFFF59E0B),
                                  bg: const Color(0xFFFFFBEB),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'إجمالي الديون المستحقة للموردين',
                                  value: '${NumberFormat('#,###').format(totalDue)} د.ع',
                                  icon: Icons.money_off_rounded,
                                  color: const Color(0xFFEF4444),
                                  bg: const Color(0xFFFEF2F2),
                                ),
                              ),
                            ],
                          );
                        },
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
                                hintText: 'ابحث باسم الشركة، المندوب، رقم الهاتف، أو نوع المواد...',
                                hintStyle: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 12.5),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 4. جدول الموردين
                    if (filtered.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            children: [
                              Icon(Icons.local_shipping_outlined, size: 60, color: c.textDisabled),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد بيانات موردين تطابق البحث',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 15, fontWeight: FontWeight.bold, color: c.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: LayoutBuilder(
                            builder: (context, tableConstraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: tableConstraints.maxWidth > 800 ? tableConstraints.maxWidth : 800,
                                  ),
                                  child: Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(2.8),
                                      1: FlexColumnWidth(2.0),
                                      2: FlexColumnWidth(1.8),
                                      3: FlexColumnWidth(2.0),
                                      4: FlexColumnWidth(2.0),
                                      5: FixedColumnWidth(120),
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: c.background,
                                          border: Border(bottom: BorderSide(color: c.border)),
                                        ),
                                        children: [
                                          _buildHeaderCell('الشركة والمورد'),
                                          _buildHeaderCell('الشخص المسؤول'),
                                          _buildHeaderCell('رقم الهاتف'),
                                          _buildHeaderCell('نوع التوريد'),
                                          _buildHeaderCell('الرصيد المستحق (د.ع)'),
                                          _buildHeaderCell('إجراءات'),
                                        ],
                                      ),

                                      ...filtered.map((supp) {
                                        return TableRow(
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5))),
                                          ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 34,
                                                    height: 34,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: const Icon(Icons.business_rounded, color: Color(0xFF3B82F6), size: 18),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          supp.companyName,
                                                          style: GoogleFonts.ibmPlexSansArabic(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 13,
                                                            color: c.textPrimary,
                                                          ),
                                                        ),
                                                        if (supp.address.isNotEmpty)
                                                          Text(
                                                            supp.address,
                                                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                              child: Text(
                                                supp.contactPerson.isNotEmpty ? supp.contactPerson : '—',
                                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: c.textPrimary),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                              child: Text(supp.phone, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textPrimary)),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: c.background,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: c.border),
                                                ),
                                                child: Text(
                                                  supp.supplyType,
                                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textPrimary),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                              child: Text(
                                                supp.balanceDue > 0 ? '${NumberFormat('#,###').format(supp.balanceDue)} د.ع' : 'خالص (0 د.ع)',
                                                style: GoogleFonts.ibmPlexSansArabic(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12.5,
                                                  color: supp.balanceDue > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.payment_rounded, size: 18, color: c.primary),
                                                    tooltip: 'تسجيل سند دفع',
                                                    onPressed: () => _recordPaymentDialog(context, supp),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                                    tooltip: 'حذف',
                                                    onPressed: () => _confirmDelete(context, supp),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
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

  Widget _buildHeaderCell(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        title,
        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF8B95A5)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.ibmPlexSansArabic(fontSize: 18, fontWeight: FontWeight.w900, color: c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSupplierDialog(BuildContext context) {
    final c = context.posColors;
    final nameCtrl = TextEditingController();
    final personCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'لحوم ودواجن');
    final balanceCtrl = TextEditingController(text: '0');
    final addrCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('إضافة مورد جديد', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MadarResponsive.dialogWidth(context, maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اسم الشركة / المورد', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'شركة الفرات، أسواق النور...',
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('اسم المندوب المسؤول', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: personCtrl,
                              decoration: InputDecoration(
                                hintText: 'مثال: أبو عمر...',
                                filled: true,
                                fillColor: c.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('رقم الهاتف', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: '0770xxxxxxx',
                                filled: true,
                                fillColor: c.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Text('نوع المواد الموردة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: typeCtrl,
                    decoration: InputDecoration(
                      hintText: 'لحوم، خضار، مواد تعبئة، بهارات...',
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('الرصيد الافتتاحي المستحق للمورد (إن وُجد)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: balanceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0 أو المبلغ الآجل',
                      filled: true,
                      fillColor: c.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('العنوان والموقع', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: addrCtrl,
                    decoration: InputDecoration(
                      hintText: 'القائم، سوق الجملة...',
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
                final comp = nameCtrl.text.trim();
                if (comp.isEmpty) return;

                final payload = {
                  'restaurantId': _activeId,
                  'companyName': comp,
                  'contactPerson': personCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'supplyType': typeCtrl.text.trim().isEmpty ? 'لحوم ودواجن' : typeCtrl.text.trim(),
                  'balanceDue': double.tryParse(balanceCtrl.text.trim()) ?? 0.0,
                  'address': addrCtrl.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                };

                if (_activeId.isNotEmpty) {
                  await _suppliersRef().add(payload);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('حفظ المورد', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _recordPaymentDialog(BuildContext context, SupplierItem supp) {
    final c = context.posColors;
    final payCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('تسجيل دفعة سداد للمورد: ${supp.companyName}', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 15)),
          content: SizedBox(
            width: MadarResponsive.dialogWidth(context, maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الرصيد المستحق حالياً: ${NumberFormat('#,###').format(supp.balanceDue)} د.ع', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: const Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('المبلغ المسدد (د.ع)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: payCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'أدخل المبلغ المسدد للمورد...',
                    filled: true,
                    fillColor: c.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final paid = double.tryParse(payCtrl.text.trim()) ?? 0.0;
                if (paid <= 0) return;
                final newBal = (supp.balanceDue - paid) < 0 ? 0.0 : (supp.balanceDue - paid);

                if (_activeId.isNotEmpty) {
                  await _suppliersRef().doc(supp.id).set({
                    'balanceDue': newBal,
                  }, SetOptions(merge: true));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              child: Text('تأكيد السند', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, SupplierItem supp) {
    final c = context.posColors;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          title: Text('حذف المورد؟', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MadarResponsive.dialogWidth(context, maxWidth: 380),
            child: Text('هل أنت متأكد من حذف بيانات المورد "${supp.companyName}"؟', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_activeId.isNotEmpty) {
                  await _suppliersRef().doc(supp.id).delete();
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
