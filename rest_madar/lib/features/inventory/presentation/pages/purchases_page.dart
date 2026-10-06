import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/responsive/madar_responsive.dart';
import '../../../../core/error/madar_crash_guard.dart';

/// نموذج فاتورة المشتريات
class PurchaseInvoice {
  final String id;
  final String invoiceNumber;
  final String supplierName;
  final DateTime date;
  final double totalAmount;
  final String paymentStatus; // 'paid' أو 'credit'
  final String itemsSummary;
  final String notes;

  const PurchaseInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.supplierName,
    required this.date,
    required this.totalAmount,
    required this.paymentStatus,
    this.itemsSummary = '',
    this.notes = '',
  });

  factory PurchaseInvoice.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    DateTime dt = DateTime.now();
    if (d['date'] is Timestamp) {
      dt = (d['date'] as Timestamp).toDate();
    } else if (d['date'] is String) {
      dt = DateTime.tryParse(d['date'] as String) ?? DateTime.now();
    } else if (d['date'] is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(d['date'] as int);
    }

    double parseAmount(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) {
        final clean = val.replaceAll(',', '').replaceAll('د.ع', '').trim();
        return double.tryParse(clean) ?? 0.0;
      }
      return 0.0;
    }

    final fallbackInv = doc.id.length >= 6 ? doc.id.substring(0, 6).toUpperCase() : doc.id.toUpperCase();

    return PurchaseInvoice(
      id: doc.id,
      invoiceNumber: (d['invoiceNumber'] ?? fallbackInv).toString(),
      supplierName: (d['supplierName'] ?? 'مورد عام').toString(),
      date: dt,
      totalAmount: parseAmount(d['totalAmount'] ?? d['total']),
      paymentStatus: (d['paymentStatus'] ?? 'paid').toString(),
      itemsSummary: (d['itemsSummary'] ?? '').toString(),
      notes: (d['notes'] ?? '').toString(),
    );
  }
}

/// شاشة إدارة المشتريات وفواتير المواد في نظام مطاعم مدار
class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _effectiveRestaurantId = '';
  String _searchQuery = '';
  String _statusFilter = 'الكل'; // 'الكل', 'paid', 'credit'

  @override
  void initState() {
    super.initState();
    _resolveRestaurantId();
  }

  Future<void> _resolveRestaurantId() async {
    if (_uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        final rId = (data?['restaurantId'] ?? data?['storeId'] ?? data?['branchId'] ?? data?['merchantId'])?.toString().trim() ?? '';
        if (rId.isNotEmpty && rId != _effectiveRestaurantId) {
          setState(() {
            _effectiveRestaurantId = rId;
          });
        }
      }
    } catch (_) {}
  }

  String get _activeId => _effectiveRestaurantId.isNotEmpty ? _effectiveRestaurantId : _uid;

  CollectionReference _purchasesRef() {
    return FirebaseFirestore.instance
        .collection('merchant_purchases')
        .doc(_activeId)
        .collection('purchases');
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
            stream: _activeId.isEmpty ? null : _purchasesRef().orderBy('date', descending: true).snapshots(),
            builder: (context, snapshot) {
              List<PurchaseInvoice> list = [];

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                list = snapshot.data!.docs.map((d) => PurchaseInvoice.fromFirestore(d)).toList();
              }

              final filtered = list.where((p) {
                final matchStatus = _statusFilter == 'الكل' || p.paymentStatus == _statusFilter;
                final matchSearch = _searchQuery.isEmpty ||
                    p.invoiceNumber.contains(_searchQuery.toUpperCase()) ||
                    p.supplierName.contains(_searchQuery) ||
                    p.itemsSummary.contains(_searchQuery);
                return matchStatus && matchSearch;
              }).toList();

              final totalPurchases = list.fold(0.0, (s, p) => s + p.totalAmount);
              final paidTotal = list.where((p) => p.paymentStatus == 'paid').fold(0.0, (s, p) => s + p.totalAmount);
              final creditTotal = totalPurchases - paidTotal;

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
                                'فواتير المشتريات والتوريد',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'توثيق شحنات المواد الغذائية والتغليف المستلمة من الشركات والموردين وحالات السداد',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12.5,
                                  color: c.textMuted,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddInvoiceDialog(context),
                                  icon: const Icon(Icons.receipt_long_rounded, size: 20),
                                  label: Text(
                                    'تسجيل فاتورة شراء',
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
                                  'فواتير المشتريات والتوريد',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'توثيق شحنات المواد الغذائية والتغليف المستلمة من الشركات والموردين وحالات السداد',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 13,
                                    color: c.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () => _showAddInvoiceDialog(context),
                              icon: const Icon(Icons.receipt_long_rounded, size: 20),
                              label: Text(
                                'تسجيل فاتورة شراء',
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
                                child: Icon(Icons.shopping_cart_outlined, size: 56, color: c.primary),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد فواتير مشتريات مسجلة',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'ابدأ بتسجيل فواتير الشراء الواردة من الموردين لمتابعة الحسابات والذمم بدقة',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.textMuted),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => _showAddInvoiceDialog(context),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text('تسجيل أول فاتورة شراء', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
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
                                  title: 'إجمالي المشتريات المسجلة',
                                  value: '${NumberFormat('#,###').format(totalPurchases)} د.ع',
                                  icon: Icons.shopping_bag_rounded,
                                  color: const Color(0xFF3B82F6),
                                  bg: const Color(0xFFEFF6FF),
                                ),
                                const SizedBox(height: 10),
                                _buildStatCard(
                                  title: 'مشتريات مسددة نقداً',
                                  value: '${NumberFormat('#,###').format(paidTotal)} د.ع',
                                  icon: Icons.check_circle_rounded,
                                  color: const Color(0xFF10B981),
                                  bg: const Color(0xFFECFDF5),
                                ),
                                const SizedBox(height: 10),
                                _buildStatCard(
                                  title: 'ذمم وآجل مستحق للموردين',
                                  value: '${NumberFormat('#,###').format(creditTotal)} د.ع',
                                  icon: Icons.hourglass_top_rounded,
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
                                  title: 'إجمالي المشتريات المسجلة',
                                  value: '${NumberFormat('#,###').format(totalPurchases)} د.ع',
                                  icon: Icons.shopping_bag_rounded,
                                  color: const Color(0xFF3B82F6),
                                  bg: const Color(0xFFEFF6FF),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'مشتريات مسددة نقداً',
                                  value: '${NumberFormat('#,###').format(paidTotal)} د.ع',
                                  icon: Icons.check_circle_rounded,
                                  color: const Color(0xFF10B981),
                                  bg: const Color(0xFFECFDF5),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'ذمم وآجل مستحق للموردين',
                                  value: '${NumberFormat('#,###').format(creditTotal)} د.ع',
                                  icon: Icons.hourglass_top_rounded,
                                  color: const Color(0xFFEF4444),
                                  bg: const Color(0xFFFEF2F2),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // 3. شريط الفلترة والبحث
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: c.card,
                                borderRadius: BorderRadius.circular(10),
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
                                        hintText: 'ابحث برقم الفاتورة أو اسم المورد...',
                                        hintStyle: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 12.5),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'الكل', label: Text('الكل')),
                              ButtonSegment(value: 'paid', label: Text('مدفوع نقداً')),
                              ButtonSegment(value: 'credit', label: Text('آجل / ذمم')),
                            ],
                            selected: {_statusFilter},
                            onSelectionChanged: (set) => setState(() => _statusFilter = set.first),
                          ),
                        ],
                      ),

                    const SizedBox(height: 18),

                    // 4. جدول الفواتير
                    if (filtered.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_outlined, size: 60, color: c.textDisabled),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد فواتير تطابق البحث',
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
                                      0: FlexColumnWidth(2.0),
                                      1: FlexColumnWidth(2.5),
                                      2: FlexColumnWidth(3.0),
                                      3: FlexColumnWidth(1.8),
                                      4: FlexColumnWidth(1.8),
                                      5: FlexColumnWidth(1.6),
                                      6: FixedColumnWidth(80),
                                    },
                                    children: [
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: c.background,
                                          border: Border(bottom: BorderSide(color: c.border)),
                                        ),
                                        children: [
                                          _buildHeaderCell('رقم الفاتورة'),
                                          _buildHeaderCell('المورد / الشركة'),
                                          _buildHeaderCell('بيان المواد المشتراة'),
                                          _buildHeaderCell('تاريخ الشراء'),
                                          _buildHeaderCell('المبلغ الإجمالي'),
                                          _buildHeaderCell('حالة السداد'),
                                          _buildHeaderCell('إجراءات'),
                                        ],
                                      ),

                                      ...filtered.map((inv) {
                                        return TableRow(
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5))),
                                          ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                              child: Text(
                                                '#${inv.invoiceNumber}',
                                                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13, color: c.primary),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                              child: Text(inv.supplierName, style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12.5, color: c.textPrimary)),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                              child: Text(inv.itemsSummary, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                              child: Text(DateFormat('yyyy/MM/dd').format(inv.date), style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted)),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                              child: Text(
                                                '${NumberFormat('#,###').format(inv.totalAmount)} د.ع',
                                                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w800, fontSize: 12.5, color: c.textPrimary),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: inv.paymentStatus == 'paid'
                                                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  inv.paymentStatus == 'paid' ? 'مسدد بالكامل' : 'آجل مستحق',
                                                  style: GoogleFonts.ibmPlexSansArabic(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: inv.paymentStatus == 'paid' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                              child: IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                                tooltip: 'حذف',
                                                onPressed: () => _confirmDelete(context, inv),
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

  void _showAddInvoiceDialog(BuildContext context) {
    final c = context.posColors;
    final numCtrl = TextEditingController(text: 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final suppCtrl = TextEditingController();
    final itemsCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    String paymentStatus = 'paid';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('تسجيل فاتورة شراء جديدة', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: MadarResponsive.dialogWidth(context, maxWidth: 440),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('رقم الفاتورة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: numCtrl,
                                  decoration: InputDecoration(
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
                                Text('اسم المورد / الشركة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: suppCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'شركة الفرات، أسواق النور...',
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

                      Text('بيان المواد المشتراة وتفاصيلها', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: itemsCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'مثال: 50 كغم لحم غنم، 20 علبة جبن موزاريلا، 10 كرتون أكياس...',
                          filled: true,
                          fillColor: c.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('المبلغ الإجمالي للفاتورة (د.ع)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: totalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'مثال: 250000 أو 500000...',
                          filled: true,
                          fillColor: c.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('طريقة السداد', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => paymentStatus = 'paid'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: paymentStatus == 'paid'
                                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                      : c.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: paymentStatus == 'paid' ? const Color(0xFF10B981) : c.border,
                                    width: paymentStatus == 'paid' ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: paymentStatus == 'paid' ? const Color(0xFF10B981) : c.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'مدفوع نقداً',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: paymentStatus == 'paid' ? const Color(0xFF10B981) : c.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => paymentStatus = 'credit'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: paymentStatus == 'credit'
                                      ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                                      : c.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: paymentStatus == 'credit' ? const Color(0xFFEF4444) : c.border,
                                    width: paymentStatus == 'credit' ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.access_time_filled_rounded,
                                      size: 18,
                                      color: paymentStatus == 'credit' ? const Color(0xFFEF4444) : c.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'آجل / ذمة مستحقة',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: paymentStatus == 'credit' ? const Color(0xFFEF4444) : c.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
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
                    final numStr = numCtrl.text.trim();
                    final supp = suppCtrl.text.trim();
                    final total = double.tryParse(totalCtrl.text.trim()) ?? 0.0;
                    if (supp.isEmpty || total <= 0) return;

                    final payload = {
                      'restaurantId': _activeId,
                      'invoiceNumber': numStr,
                      'supplierName': supp,
                      'itemsSummary': itemsCtrl.text.trim(),
                      'totalAmount': total,
                      'paymentStatus': paymentStatus,
                      'date': FieldValue.serverTimestamp(),
                      'createdAt': FieldValue.serverTimestamp(),
                    };

                    if (_activeId.isNotEmpty) {
                      await _purchasesRef().add(payload);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('حفظ الفاتورة', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, PurchaseInvoice inv) {
    final c = context.posColors;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          title: Text('حذف فاتورة الشراء؟', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MadarResponsive.dialogWidth(context, maxWidth: 380),
            child: Text('هل أنت متأكد من حذف فاتورة رقم "${inv.invoiceNumber}"؟', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_activeId.isNotEmpty) {
                  await _purchasesRef().doc(inv.id).delete();
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
