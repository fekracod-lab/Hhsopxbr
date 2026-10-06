import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/error/madar_crash_guard.dart';

/// نموذج حجز الطاولة
class TableReservation {
  final String id;
  final String customerName;
  final String customerPhone;
  final String tableNumber;
  final int guestCount;
  final DateTime reservationTime;
  final String notes;
  final String status; // 'confirmed', 'pending', 'seated', 'cancelled'

  const TableReservation({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.tableNumber,
    required this.guestCount,
    required this.reservationTime,
    this.notes = '',
    this.status = 'confirmed',
  });

  factory TableReservation.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    DateTime resTime = DateTime.now();
    if (d['reservationTime'] is Timestamp) {
      resTime = (d['reservationTime'] as Timestamp).toDate();
    }
    return TableReservation(
      id: doc.id,
      customerName: d['customerName'] ?? 'زبون',
      customerPhone: d['customerPhone'] ?? '—',
      tableNumber: (d['tableNumber'] ?? '1').toString(),
      guestCount: (d['guestCount'] ?? 2) as int,
      reservationTime: resTime,
      notes: d['notes'] ?? '',
      status: d['status'] ?? 'confirmed',
    );
  }
}

/// شاشة إدارة حجوزات الطاولات في نظام مطاعم مدار
class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key});

  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _effectiveRestaurantId = '';
  String _statusFilter = 'الكل'; // 'الكل', 'confirmed', 'seated', 'cancelled'
  String _searchQuery = '';

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

  CollectionReference _reservationsRef() {
    return FirebaseFirestore.instance
        .collection('merchant_reservations')
        .doc(_activeId)
        .collection('reservations');
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
            stream: _activeId.isEmpty
                ? null
                : _reservationsRef().orderBy('reservationTime', descending: true).snapshots(),
            builder: (context, snapshot) {
              List<TableReservation> list = [];

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                list = snapshot.data!.docs.map((d) => TableReservation.fromFirestore(d)).toList();
              }

              final filtered = list.where((r) {
                final matchStatus = _statusFilter == 'الكل' || r.status == _statusFilter;
                final matchSearch = _searchQuery.isEmpty ||
                    r.customerName.contains(_searchQuery) ||
                    r.customerPhone.contains(_searchQuery) ||
                    r.tableNumber.contains(_searchQuery);
                return matchStatus && matchSearch;
              }).toList();

              final todayCount = list.where((r) => _isSameDay(r.reservationTime, DateTime.now())).length;
              final confirmedCount = list.where((r) => r.status == 'confirmed').length;
              final seatedCount = list.where((r) => r.status == 'seated').length;
              final totalGuests = list.where((r) => r.status != 'cancelled').fold(0, (s, r) => s + r.guestCount);

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
                              'إدارة حجوزات الطاولات',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'سجل الحجوزات المسبقة، الطاولات المخصصة، وعدد الضيوف ومواعيد الوصول',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 13,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => _showAddReservationDialog(context),
                          icon: const Icon(Icons.event_seat_rounded, size: 20),
                          label: Text(
                            'تسجيل حجز جديد',
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

                    // 2. بطاقات الإحصائيات
                    Row(
                      children: [
                        _buildStatCard(
                          title: 'حجوزات اليوم',
                          value: '$todayCount حجز',
                          icon: Icons.today_rounded,
                          color: const Color(0xFF3B82F6),
                          bg: const Color(0xFFEFF6FF),
                        ),
                        const SizedBox(width: 14),
                        _buildStatCard(
                          title: 'مؤكدة بانتظار الوصول',
                          value: '$confirmedCount حجز',
                          icon: Icons.access_time_rounded,
                          color: const Color(0xFFF59E0B),
                          bg: const Color(0xFFFFFBEB),
                        ),
                        const SizedBox(width: 14),
                        _buildStatCard(
                          title: 'حاضرون حالياً بالصالة',
                          value: '$seatedCount حجز',
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF10B981),
                          bg: const Color(0xFFECFDF5),
                        ),
                        const SizedBox(width: 14),
                        _buildStatCard(
                          title: 'إجمالي الضيوف',
                          value: '$totalGuests شخص',
                          icon: Icons.groups_rounded,
                          color: const Color(0xFF8B5CF6),
                          bg: const Color(0xFFFAF5FF),
                        ),
                      ],
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
                                      hintText: 'ابحث باسم الزبون، رقم الهاتف، أو رقم الطاولة...',
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
                            ButtonSegment(value: 'confirmed', label: Text('مؤكد')),
                            ButtonSegment(value: 'seated', label: Text('حاضر')),
                            ButtonSegment(value: 'cancelled', label: Text('ملغي')),
                          ],
                          selected: {_statusFilter},
                          onSelectionChanged: (set) => setState(() => _statusFilter = set.first),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 4. جدول الحجوزات
                    if (list.isEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: c.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.event_seat_rounded, size: 48, color: c.primary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد أي حجوزات مسجلة حالياً',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'قائمة الحجوزات المسبقة فارغة تماماً. يمكنك تسجيل حجز طاولة جديد للزبائن من الزر أدناه.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.textMuted),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _showAddReservationDialog(context),
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                              label: Text(
                                'تسجيل حجز جديد',
                                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: c.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (filtered.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            children: [
                              Icon(Icons.search_off_rounded, size: 56, color: c.textDisabled),
                              const SizedBox(height: 12),
                              Text(
                                'لا توجد حجوزات تطابق المعايير المحددة',
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
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2.5),
                              1: FlexColumnWidth(1.8),
                              2: FlexColumnWidth(1.5),
                              3: FlexColumnWidth(1.5),
                              4: FlexColumnWidth(2.2),
                              5: FlexColumnWidth(1.8),
                              6: FixedColumnWidth(180),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                  color: c.background,
                                  border: Border(bottom: BorderSide(color: c.border)),
                                ),
                                children: [
                                  _buildHeaderCell('اسم صاحب الحجز'),
                                  _buildHeaderCell('الهاتف'),
                                  _buildHeaderCell('رقم الطاولة'),
                                  _buildHeaderCell('عدد الضيوف'),
                                  _buildHeaderCell('موعد الحجز'),
                                  _buildHeaderCell('الحالة'),
                                  _buildHeaderCell('إجراءات الحجز'),
                                ],
                              ),

                              ...filtered.map((res) {
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
                                            res.customerName,
                                            style: GoogleFonts.ibmPlexSansArabic(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: c.textPrimary,
                                            ),
                                          ),
                                          if (res.notes.isNotEmpty)
                                            Text(
                                              '📝 ${res.notes}',
                                              style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                      child: Text(res.customerPhone, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textPrimary)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: c.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'طاولة #${res.tableNumber}',
                                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold, color: c.primary),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                      child: Text(
                                        '${res.guestCount} أفراد',
                                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: c.textPrimary),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            DateFormat('yyyy/MM/dd').format(res.reservationTime),
                                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textPrimary),
                                          ),
                                          Text(
                                            DateFormat('hh:mm a').format(res.reservationTime),
                                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                      child: _buildStatusBadge(res.status),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (res.status == 'confirmed')
                                            ElevatedButton(
                                              onPressed: () => _updateStatus(res, 'seated'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF10B981),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                minimumSize: Size.zero,
                                              ),
                                              child: Text('حضر 🍽️', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                          if (res.status == 'confirmed')
                                            const SizedBox(width: 4),
                                          if (res.status != 'cancelled')
                                            IconButton(
                                              icon: const Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFF59E0B)),
                                              tooltip: 'إلغاء الحجز',
                                              onPressed: () => _updateStatus(res, 'cancelled'),
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                            tooltip: 'حذف الحجز',
                                            onPressed: () => _confirmDeleteReservation(res),
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
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'seated':
        bg = const Color(0xFF10B981).withValues(alpha: 0.12);
        fg = const Color(0xFF10B981);
        label = 'حضر بالصالة';
        break;
      case 'cancelled':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
        fg = const Color(0xFFEF4444);
        label = 'حجز ملغي';
        break;
      default:
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        fg = const Color(0xFFF59E0B);
        label = 'مؤكد بانتظار';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
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

  void _showAddReservationDialog(BuildContext context) {
    final c = context.posColors;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final tableCtrl = TextEditingController(text: '1');
    final guestsCtrl = TextEditingController(text: '4');
    final notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('تسجيل حجز طاولة جديد', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('اسم الزبون', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          hintText: 'اسم صاحب الحجز...',
                          filled: true,
                          fillColor: c.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('رقم الهاتف للتأكيد', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '0770xxxxxxx...',
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
                                Text('رقم الطاولة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: tableCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'رقم الطاولة...',
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
                                Text('عدد الأفراد', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: guestsCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'عدد الأشخاص...',
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

                      Text('تاريخ ووقت الوصول', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today_rounded, size: 16),
                              label: Text(DateFormat('yyyy/MM/dd').format(selectedDate)),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 60)),
                                );
                                if (d != null) setModalState(() => selectedDate = d);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time_rounded, size: 16),
                              label: Text(selectedTime.format(context)),
                              onPressed: () async {
                                final t = await showTimePicker(context: context, initialTime: selectedTime);
                                if (t != null) setModalState(() => selectedTime = t);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Text('ملاحظات خاصة (مناسبة عائلية، ديكور، إلخ)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesCtrl,
                        decoration: InputDecoration(
                          hintText: 'ملاحظات إضافية...',
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
                    final phone = phoneCtrl.text.trim();
                    final table = tableCtrl.text.trim();
                    final guests = int.tryParse(guestsCtrl.text.trim()) ?? 2;
                    final fullDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    final payload = {
                      'restaurantId': _activeId,
                      'customerName': name,
                      'customerPhone': phone,
                      'tableNumber': table,
                      'guestCount': guests,
                      'reservationTime': Timestamp.fromDate(fullDateTime),
                      'notes': notesCtrl.text.trim(),
                      'status': 'confirmed',
                      'createdAt': FieldValue.serverTimestamp(),
                    };

                    if (_activeId.isNotEmpty) {
                      final messenger = ScaffoldMessenger.of(context);
                      await _reservationsRef().add(payload);
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('تم تأكيد وتسجيل الحجز بنجاح')),
                        );
                      }
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('تأكيد الحجز', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _updateStatus(TableReservation res, String newStatus) async {
    if (_activeId.isEmpty) return;
    try {
      await _reservationsRef().doc(res.id).set({'status': newStatus}, SetOptions(merge: true));
    } catch (_) {}
  }

  void _confirmDeleteReservation(TableReservation res) {
    final c = context.posColors;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            'حذف الحجز',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف حجز الزبون "${res.customerName}" لطاولة #${res.tableNumber}؟',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _reservationsRef().doc(res.id).delete();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حذف الحجز بنجاح')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل حذف الحجز: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: Text('حذف نهائياً', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
