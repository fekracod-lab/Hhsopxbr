import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../../../core/responsive/madar_responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/error/madar_crash_guard.dart';
import '../../../../services/shift_service.dart';

/// نموذج بند المصروف
class ExpenseItem {
  final String id;
  final String title;
  final String category; // 'فواتير ومرافق', 'إيجار', 'رواتب وأجور', 'صيانة ومعدات', 'نثريات يومية'
  final double amount;
  final String paymentMethod; // 'cash', 'bank', 'card'
  final String recipient;
  final DateTime date;
  final String notes;

  const ExpenseItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.recipient,
    required this.date,
    this.notes = '',
  });

  factory ExpenseItem.fromFirestore(DocumentSnapshot doc) {
    try {
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

      return ExpenseItem(
        id: doc.id,
        title: (d['title'] ?? 'مصروف').toString(),
        category: (d['category'] ?? 'نثريات يومية').toString(),
        amount: parseAmount(d['amount']),
        paymentMethod: (d['paymentMethod'] ?? 'cash').toString(),
        recipient: (d['recipient'] ?? '—').toString(),
        date: dt,
        notes: (d['notes'] ?? '').toString(),
      );
    } catch (_) {
      return ExpenseItem(
        id: doc.id,
        title: 'مصروف مسجل',
        category: 'نثريات يومية',
        amount: 0.0,
        paymentMethod: 'cash',
        recipient: '—',
        date: DateTime.now(),
      );
    }
  }
}

/// شاشة إدارة المصروفات والنثريات اليومية في نظام مطاعم مدار
class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _activeId = '';
  String _selectedCategory = 'الكل';
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

  CollectionReference _expensesRef() {
    final id = _activeId.isNotEmpty ? _activeId : _uid;
    return FirebaseFirestore.instance
        .collection('merchant_expenses')
        .doc(id)
        .collection('expenses');
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
            stream: (_activeId.isEmpty && _uid.isEmpty)
                ? null
                : _expensesRef().orderBy('date', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final list = (snapshot.data?.docs ?? [])
                  .map((d) => ExpenseItem.fromFirestore(d))
                  .toList();

              final Set<String> categories = {'الكل'};
              for (var it in list) {
                categories.add(it.category);
              }

              final filtered = list.where((e) {
                final matchCat = _selectedCategory == 'الكل' || e.category == _selectedCategory;
                final matchSearch = _searchQuery.isEmpty ||
                    e.title.contains(_searchQuery) ||
                    e.recipient.contains(_searchQuery) ||
                    e.notes.contains(_searchQuery);
                return matchCat && matchSearch;
              }).toList();

              final now = DateTime.now();
              final todayExpenses = list.where((e) => e.date.year == now.year && e.date.month == now.month && e.date.day == now.day).fold(0.0, (s, e) => s + e.amount);
              final monthExpenses = list.where((e) => e.date.year == now.year && e.date.month == now.month).fold(0.0, (s, e) => s + e.amount);
              final totalCount = list.length;

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
                              'المصروفات اليومية والنثريات',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'تسجيل وتوثيق المصاريف التشغيلية، فواتير الكهرباء والمولدات، وأجور الصيانة والرواتب اليومية',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => _showAddExpenseDialog(context),
                          icon: const Icon(Icons.add_card_rounded, size: 20),
                          label: Text(
                            'تسجيل مصروف جديد',
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
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.account_balance_wallet_outlined, size: 56, color: Color(0xFFEF4444)),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد مصروفات مسجلة حالياً',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 17, fontWeight: FontWeight.bold, color: c.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'قم بتسجيل نثريات ومصروفات وفواتير المطعم اليومية للتحكم بالتدفقات المالية والأرباح',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.textMuted),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => _showAddExpenseDialog(context),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text('تسجيل أول سند صرف', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
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
                            title: 'مصروفات اليوم',
                            value: '${NumberFormat('#,###').format(todayExpenses)} د.ع',
                            icon: Icons.today_rounded,
                            color: const Color(0xFFEF4444),
                            bg: const Color(0xFFFEF2F2),
                          ),
                        const SizedBox(width: 14),
                        _buildStatCard(
                          title: 'مصروفات هذا الشهر',
                          value: '${NumberFormat('#,###').format(monthExpenses)} د.ع',
                          icon: Icons.calendar_month_rounded,
                          color: const Color(0xFFF59E0B),
                          bg: const Color(0xFFFFFBEB),
                        ),
                        const SizedBox(width: 14),
                        _buildStatCard(
                          title: 'إجمالي القيود المسجلة',
                          value: '$totalCount سند صرف',
                          icon: Icons.receipt_long_rounded,
                          color: const Color(0xFF3B82F6),
                          bg: const Color(0xFFEFF6FF),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 3. شريط الفئات والبحث
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: categories.map((cat) {
                                final isSel = _selectedCategory == cat;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      cat,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        fontSize: 12,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                        color: isSel ? Colors.white : c.textPrimary,
                                      ),
                                    ),
                                    selected: isSel,
                                    selectedColor: c.primary,
                                    backgroundColor: c.card,
                                    onSelected: (_) => setState(() => _selectedCategory = cat),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: isSel ? c.primary : c.border),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          width: 260,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded, size: 18, color: c.textMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: c.textPrimary),
                                  decoration: InputDecoration(
                                    hintText: 'ابحث عن سند صرف...',
                                    hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 4. جدول المصروفات
                    if (filtered.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            children: [
                              Icon(Icons.money_off_rounded, size: 60, color: c.textDisabled),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد مصروفات تطابق البحث',
                                style: GoogleFonts.ibmPlexSansArabic(fontSize: 15, fontWeight: FontWeight.bold, color: c.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: c.border),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: math.max(constraints.maxWidth, 780)),
                                  child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2.6),
                              1: FlexColumnWidth(1.8),
                              2: FlexColumnWidth(1.8),
                              3: FlexColumnWidth(1.8),
                              4: FlexColumnWidth(1.8),
                              5: FlexColumnWidth(1.4),
                              6: FixedColumnWidth(80),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                  color: c.background,
                                  border: Border(bottom: BorderSide(color: c.border)),
                                ),
                                children: [
                                  _buildHeaderCell('بيان المصروف'),
                                  _buildHeaderCell('التصنيف'),
                                  _buildHeaderCell('المبلغ المستقطع'),
                                  _buildHeaderCell('المدفوع له (المستلم)'),
                                  _buildHeaderCell('التاريخ والوقت'),
                                  _buildHeaderCell('طريقة الدفع'),
                                  _buildHeaderCell('إجراءات'),
                                ],
                              ),

                              ...filtered.map((exp) {
                                return TableRow(
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: c.border.withValues(alpha: 0.5))),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            exp.title,
                                            style: GoogleFonts.ibmPlexSansArabic(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: c.textPrimary,
                                            ),
                                          ),
                                          if (exp.notes.isNotEmpty)
                                            Text(
                                              exp.notes,
                                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
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
                                        child: Text(exp.category, style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textPrimary)),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                      child: Text(
                                        '-${NumberFormat('#,###').format(exp.amount)} د.ع',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: const Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                      child: Text(exp.recipient, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textPrimary)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                      child: Text(DateFormat('yyyy/MM/dd hh:mm a').format(exp.date), style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                      child: Text(
                                        exp.paymentMethod == 'cash' ? 'نقدي من الصندوق' : 'تحويل مصرفي',
                                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                        tooltip: 'حذف',
                                        onPressed: () => _confirmDelete(context, exp),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                              ],
                            ),
                          ),
                        ),
                      ),
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.ibmPlexSansArabic(fontSize: 18, fontWeight: FontWeight.w900, color: c.textPrimary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    final c = context.posColors;
    final titleCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'نثريات يومية');
    final amountCtrl = TextEditingController();
    final recipientCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String payMethod = 'cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('تسجيل سند صرف / مصروف جديد', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: MadarResponsive.dialogWidth(context, maxWidth: 440),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('بيان المصروف', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          hintText: 'مثال: وقود مولدة، فاتورة كهرباء، شراء ثلج، صيانة مكيف...',
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
                                Text('التصنيف', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: catCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'مرافق، رواتب، صيانة، نثريات...',
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
                                Text('المبلغ المصروف (د.ع)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: amountCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'المبلغ بالدينار...',
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

                      Text('المدفوع له (المستلم)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: recipientCtrl,
                        decoration: InputDecoration(
                          hintText: 'اسم الشخص أو المحل أو الشركة المستلمة...',
                          filled: true,
                          fillColor: c.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('طريقة الدفع', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => payMethod = 'cash'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: payMethod == 'cash' ? c.primary.withValues(alpha: 0.12) : c.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: payMethod == 'cash' ? c.primary : c.border,
                                    width: payMethod == 'cash' ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      payMethod == 'cash' ? Icons.radio_button_checked : Icons.radio_button_off,
                                      size: 16,
                                      color: payMethod == 'cash' ? c.primary : c.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text('نقدي من الصندوق', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: payMethod == 'cash' ? FontWeight.bold : FontWeight.normal)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => payMethod = 'bank'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: payMethod == 'bank' ? c.primary.withValues(alpha: 0.12) : c.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: payMethod == 'bank' ? c.primary : c.border,
                                    width: payMethod == 'bank' ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      payMethod == 'bank' ? Icons.radio_button_checked : Icons.radio_button_off,
                                      size: 16,
                                      color: payMethod == 'bank' ? c.primary : c.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text('حساب بنكي / ماستر', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: payMethod == 'bank' ? FontWeight.bold : FontWeight.normal)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Text('ملاحظات إضافية', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesCtrl,
                        decoration: InputDecoration(
                          hintText: 'أي تفاصيل أخرى تخص سند الصرف...',
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
                    final title = titleCtrl.text.trim();
                    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                    if (title.isEmpty || amt <= 0) return;

                    final payload = {
                      'restaurantId': _activeId,
                      'title': title,
                      'category': catCtrl.text.trim().isEmpty ? 'نثريات يومية' : catCtrl.text.trim(),
                      'amount': amt,
                      'recipient': recipientCtrl.text.trim().isNotEmpty ? recipientCtrl.text.trim() : 'غير محدد',
                      'paymentMethod': payMethod,
                      'notes': notesCtrl.text.trim(),
                      'date': FieldValue.serverTimestamp(),
                      'createdAt': FieldValue.serverTimestamp(),
                      // ربط المصروف بالوردية المفتوحة حالياً (إن وجدت)
                      'shiftId': context.read<ShiftService>().currentShiftId ?? '',
                    };

                    if (_activeId.isNotEmpty) {
                      await _expensesRef().add(payload);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('تأكيد الصرف', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, ExpenseItem exp) {
    final c = context.posColors;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          title: Text('حذف قيد المصروف؟', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من حذف سند صرف "${exp.title}" بقيمة ${NumberFormat('#,###').format(exp.amount)} د.ع؟', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_activeId.isNotEmpty) {
                  await _expensesRef().doc(exp.id).delete();
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
