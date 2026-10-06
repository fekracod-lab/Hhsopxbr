import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/constants/pos_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/design_system/madar_design_system.dart';
import '../../../../core/widgets/pos_empty_state.dart';
import '../../../../core/widgets/pos_page_header.dart';
import '../../../../core/widgets/pos_status_chip.dart';
import '../../../../services/audio_alert_service.dart';
import '../../../../services/thermal_printer_service.dart';
import '../../../../core/localization/pos_language_controller.dart';
import '../../pos/domain/pos_order.dart';
import '../../pos/presentation/widgets/printer_settings_dialog.dart';

/// شاشة طلبات مدار الحية — لاستقبال وتتبع الطلبات القادمة من تطبيق مدار مع الطباعة الحرارية المباشرة
class LiveOrdersPage extends StatefulWidget {
  const LiveOrdersPage({super.key});

  @override
  State<LiveOrdersPage> createState() => _LiveOrdersPageState();
}

class _LiveOrdersPageState extends State<LiveOrdersPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _effectiveRestaurantId = '';
  String _filterStatus = 'all'; // 'all', 'pending', 'preparing', 'ready', 'completed'
  int _selectedKanbanTabIndex = 0; // 0: جديد, 1: تحضير, 2: جاهز
  final Set<String> _knownPendingIds = {};
  bool _isInitialLoad = true;
  StreamSubscription<QuerySnapshot>? _alertSub;

  @override
  void initState() {
    super.initState();
    _resolveRestaurantId();
    _setupNewOrderAlarm();
  }

  Future<void> _resolveRestaurantId() async {
    if (_uid.isEmpty) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final restId = userDoc.data()!['restaurantId'] ?? userDoc.data()!['merchantId'] ?? userDoc.data()!['storeId'];
        if (restId != null && restId.toString().trim().isNotEmpty && mounted) {
          setState(() {
            _effectiveRestaurantId = restId.toString().trim();
          });
          _setupNewOrderAlarm();
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    AudioAlertService.stopAlarm();
    super.dispose();
  }

  void _setupNewOrderAlarm() {
    _alertSub?.cancel();
    final ids = [
      _uid,
      if (_effectiveRestaurantId.isNotEmpty && _effectiveRestaurantId != _uid)
        _effectiveRestaurantId,
    ];

    Query<Map<String, dynamic>> alertQuery = FirebaseFirestore.instance.collection('orders');
    if (ids.length == 1) {
      alertQuery = alertQuery.where('restaurantId', isEqualTo: ids.first);
    } else {
      alertQuery = alertQuery.where('restaurantId', whereIn: ids);
    }
    alertQuery = alertQuery.where('status', isEqualTo: 'pending');

    _alertSub = alertQuery
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (_isInitialLoad) {
        for (var doc in snapshot.docs) {
          _knownPendingIds.add(doc.id);
        }
        _isInitialLoad = false;
        return;
      }
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          if (!_knownPendingIds.contains(change.doc.id)) {
            _knownPendingIds.add(change.doc.id);
            AudioAlertService.playOrderAlarm(durationSeconds: 25);
            HapticFeedback.heavyImpact();
          }
        }
      }
    }, onError: (error) {
      debugPrint('[LiveOrdersPage:Alarm] Error listening to pending orders: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PosLanguageController.instance,
      builder: (context, _) {
        return Directionality(
          textDirection: PosLanguageController.instance.textDirection,
          child: Column(
            children: [
              // رأس الصفحة + فلاتر الحالة
              _buildFilterBar(context),

              // قائمة الطلبات
              Expanded(child: _buildOrdersList()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;

    return PosPageHeader(
      icon: Icons.delivery_dining_rounded,
      title: isEn ? 'Live Kitchen & Online Orders' : 'طلبات مدار الحية',
      subtitle: isEn ? 'Real-time order dispatch with acoustic alarm & auto-printing' : 'استقبال طلبات التطبيق والمطبخ مع تنبيه صوتي وطباعة تلقائية',
      actions: [
        // زر إيقاف التنبيه الصوتي المباشر
        OutlinedButton.icon(
          onPressed: () {
            AudioAlertService.stopAlarm();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isEn ? 'Alarm muted 🔇' : 'تم إيقاف صوت التنبيه 🔇'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.volume_off_rounded, size: 16, color: Colors.amberAccent),
          label: Text(
            isEn ? PosLocale.muteAlarmEn : PosLocale.muteAlarmAr,
            style: GoogleFonts.ibmPlexSansArabic(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.amberAccent),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 8),

        // زر إعدادات الطابعة الحرارية
        OutlinedButton.icon(
          onPressed: () => PrinterSettingsDialog.show(context),
          icon: Icon(Icons.print_rounded, size: 16, color: c.accent),
          label: Text(
            isEn ? PosLocale.printerSettingsEn : PosLocale.printerSettingsAr,
            style: GoogleFonts.ibmPlexSansArabic(
              color: c.accent,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: c.primary.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
      bottom: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(context, isEn ? PosLocale.allEn : 'الكل', 'all'),
                  const SizedBox(width: 6),
                  _buildFilterChip(context, isEn ? PosLocale.pendingEn : 'جديد', 'pending'),
                  const SizedBox(width: 6),
                  _buildFilterChip(context, isEn ? PosLocale.preparingEn : 'تحضير', 'preparing'),
                  const SizedBox(width: 6),
                  _buildFilterChip(context, isEn ? PosLocale.readyEn : 'جاهز', 'ready'),
                  const SizedBox(width: 6),
                  _buildFilterChip(context, isEn ? PosLocale.completedEn : 'مكتمل', 'completed'),
                  const SizedBox(width: 6),
                  _buildFilterChip(context, isEn ? PosLocale.cancelledEn : 'ملغي', 'cancelled'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String status) {
    final c = context.posColors;
    final isSelected = _filterStatus == status;
    return InkWell(
      onTap: () => setState(() => _filterStatus = status),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? c.primary : c.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? c.primary : c.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            color: isSelected ? Colors.white : c.textMuted,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersList() {
    final ids = [
      _uid,
      if (_effectiveRestaurantId.isNotEmpty && _effectiveRestaurantId != _uid)
        _effectiveRestaurantId,
    ];

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('orders');
    if (ids.length == 1) {
      query = query.where('restaurantId', isEqualTo: ids.first);
    } else {
      query = query.where('restaurantId', whereIn: ids);
    }
    query = query.limit(100);

    if (_filterStatus != 'all') {
      query = query.where('status', isEqualTo: _filterStatus);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final c = context.posColors;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: c.primary, strokeWidth: 3),
          );
        }

        final docs = (snapshot.data?.docs ?? []).toList();
        docs.sort((a, b) {
          final da = (a.data() as Map<String, dynamic>)['createdAt'];
          final db = (b.data() as Map<String, dynamic>)['createdAt'];
          final ta = PosOrder.parseDate(da);
          final tb = PosOrder.parseDate(db);
          return tb.compareTo(ta);
        });

        final isEn = PosLanguageController.instance.isEnglish;

        if (docs.isEmpty) {
          return PosEmptyState(
            icon: Icons.inbox_rounded,
            title: isEn ? 'No orders currently' : 'لا توجد طلبات حالياً',
            subtitle: isEn ? 'New incoming orders from Madar App will appear here in real-time' : 'الطلبات الجديدة من تطبيق مدار ستظهر هنا فور وصولها',
          );
        }

        // تقسيم الطلبات لأعمدة الكانبان المطبخي
        final pendingDocs = docs.where((d) {
          final s = (d.data() as Map<String, dynamic>)['status'] ?? '';
          return s == 'pending';
        }).toList();

        final preparingDocs = docs.where((d) {
          final s = (d.data() as Map<String, dynamic>)['status'] ?? '';
          return s == 'preparing' || s == 'accepted';
        }).toList();

        final readyDocs = docs.where((d) {
          final s = (d.data() as Map<String, dynamic>)['status'] ?? '';
          return s == 'ready';
        }).toList();

        final otherDocs = docs.where((d) {
          final s = (d.data() as Map<String, dynamic>)['status'] ?? '';
          return s != 'pending' && s != 'preparing' && s != 'accepted' && s != 'ready';
        }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900 ||
                (constraints.maxWidth >= 600 && MadarResponsive.isLandscape(context));

            if (isWide) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildKanbanColumn(
                        context,
                        title: isEn ? 'New Orders' : 'طلبات جديدة',
                        subtitle: isEn ? 'Waiting for chef acceptance' : 'بانتظار قبول الشيف',
                        color: const Color(0xFFF59E0B),
                        count: pendingDocs.length,
                        icon: Icons.notifications_active_rounded,
                        docs: pendingDocs,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildKanbanColumn(
                        context,
                        title: isEn ? 'Preparing' : 'قيد التحضير',
                        subtitle: isEn ? 'In kitchen & ovens' : 'في الفرن والمطبخ',
                        color: const Color(0xFF3B82F6),
                        count: preparingDocs.length,
                        icon: Icons.soup_kitchen_rounded,
                        docs: preparingDocs,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildKanbanColumn(
                        context,
                        title: isEn ? 'Ready for Pickup' : 'جاهز للتسليم',
                        subtitle: isEn ? 'Waiting for driver or customer' : 'بانتظار السائق أو الزبون',
                        color: const Color(0xFF10B981),
                        count: readyDocs.length,
                        icon: Icons.check_circle_rounded,
                        docs: readyDocs,
                      ),
                    ),
                  ],
                ),
              );
            }

            // في وضع التابلت الرأسي أو الشاشات الضيقة: استخدام التبويبات لعرض العمود المحدد
            final List<QueryDocumentSnapshot> currentDocs;
            if (_selectedKanbanTabIndex == 0) {
              currentDocs = pendingDocs;
            } else if (_selectedKanbanTabIndex == 1) {
              currentDocs = preparingDocs;
            } else if (_selectedKanbanTabIndex == 2) {
              currentDocs = readyDocs;
            } else {
              currentDocs = otherDocs;
            }

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildKanbanTabButton(0, isEn ? 'New (${pendingDocs.length})' : 'جديد (${pendingDocs.length})', const Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      _buildKanbanTabButton(1, isEn ? 'Prep (${preparingDocs.length})' : 'تحضير (${preparingDocs.length})', const Color(0xFF3B82F6)),
                      const SizedBox(width: 8),
                      _buildKanbanTabButton(2, isEn ? 'Ready (${readyDocs.length})' : 'جاهز (${readyDocs.length})', const Color(0xFF10B981)),
                    ],
                  ),
                ),
                Expanded(
                  child: currentDocs.isEmpty
                      ? Center(
                          child: Text(
                            isEn ? 'No orders in this column' : 'لا توجد طلبات في هذا العمود حالياً',
                            style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: currentDocs.length,
                          itemBuilder: (context, i) {
                            final data = currentDocs[i].data() as Map<String, dynamic>;
                            final orderId = currentDocs[i].id;
                            return _buildOrderCard(context, orderId, data);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildKanbanColumn(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color color,
    required int count,
    required IconData icon,
    required List<QueryDocumentSnapshot> docs,
  }) {
    final c = context.posColors;

    return Container(
      decoration: BoxDecoration(
        color: c.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 10.5,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: docs.isEmpty
                ? Center(
                    child: Text(
                      PosLanguageController.instance.isEnglish ? 'No orders here' : 'لا توجد طلبات هنا',
                      style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      final orderId = docs[i].id;
                      return _buildOrderCard(context, orderId, data);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanTabButton(int index, String label, Color color) {
    final c = context.posColors;
    final isSelected = _selectedKanbanTabIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedKanbanTabIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : c.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : c.border),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                color: isSelected ? Colors.white : c.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerBadge(DateTime? createdAt) {
    if (createdAt == null) return const SizedBox.shrink();
    final diff = DateTime.now().difference(createdAt);
    final minutes = diff.inMinutes;
    final Color bg;
    final Color text;
    if (minutes >= 25) {
      bg = const Color(0xFFFEF2F2);
      text = const Color(0xFFDC2626);
    } else if (minutes >= 15) {
      bg = const Color(0xFFFFFBEB);
      text = const Color(0xFFD97706);
    } else {
      bg = const Color(0xFFF0FDF4);
      text = const Color(0xFF16A34A);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: text.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            minutes < 1 ? 'الآن' : '$minutes دقيقة',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
  ) {
    final c = context.posColors;
    final status = data['status'] ?? 'pending';
    final customerName =
        data['customerName'] ?? data['buyerName'] ?? 'زبون مدار';
    final customerPhone = data['customerPhone'] ?? data['buyerPhone'] ?? '';
    final deliveryAddress = data['deliveryAddress'] ?? data['address'] ?? '';
    final notes = data['notes']?.toString() ?? '';
    final items = data['items'] as List<dynamic>? ?? [];
    final total = (data['total'] ?? data['totalPrice'] ?? 0).toDouble();
    final source = data['source'] ?? 'madar_app';
    final autoPrinted = data['autoPrinted'] == true;

    DateTime? createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    }

    Color statusColor = c.textMuted;
    String statusLabel = 'غير معروف';
    IconData statusIcon = Icons.help_outline;

    switch (status) {
      case 'pending':
        statusColor = c.gold;
        statusLabel = 'بانتظار القبول';
        statusIcon = Icons.notifications_active_rounded;
        break;
      case 'accepted':
      case 'preparing':
        statusColor = c.info;
        statusLabel = 'قيد التجهيز';
        statusIcon = Icons.restaurant_rounded;
        break;
      case 'ready':
        statusColor = c.success;
        statusLabel = 'جاهز للتسليم';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'completed':
        statusColor = c.textMuted;
        statusLabel = 'مكتمل';
        statusIcon = Icons.done_all_rounded;
        break;
      case 'cancelled':
        statusColor = c.danger;
        statusLabel = 'ملغي';
        statusIcon = Icons.cancel_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'pending'
              ? c.gold.withValues(alpha: 0.6)
              : c.border,
          width: status == 'pending' ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الصف العلوي (الحالة ومصدر الطلب وشارة الطباعة)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PosStatusChip(
                    label: statusLabel,
                    icon: statusIcon,
                    color: statusColor,
                  ),
                  _buildTimerBadge(createdAt),
                  if (source == 'pos_windows')
                    PosStatusChip(
                      label: 'كاشير',
                      icon: Icons.point_of_sale_rounded,
                      color: c.info,
                    )
                  else
                    PosStatusChip(
                      label: 'مدار أونلاين',
                      icon: Icons.cloud_done_rounded,
                      color: c.primary,
                    ),
                  if (autoPrinted)
                    PosStatusChip(
                      label: 'طُبعت 🖨️',
                      icon: Icons.print_rounded,
                      color: c.success,
                    ),
                ],
              ),
              Text(
                '#${orderId.substring(0, orderId.length > 6 ? 6 : orderId.length).toUpperCase()}',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: c.textMuted,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // الزبون والوقت
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.person_rounded, color: c.textMuted, size: 15),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        customerName,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: c.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (customerPhone.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '($customerPhone)',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: c.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (createdAt != null)
                Text(
                  DateFormat('hh:mm a', 'ar').format(createdAt),
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: c.textMuted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),

          // عنوان التوصيل
          if (deliveryAddress.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: c.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      deliveryAddress,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.textMuted,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // الملاحظات
          if (notes.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.gold.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.note_alt_outlined, size: 14, color: c.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ملاحظة: $notes',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.gold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // الأصناف
          ...items.take(3).map((item) {
            final name = (item is Map ? item['name'] : item).toString();
            final qty = item is Map ? (item['quantity'] ?? 1) : 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '  • $name × $qty',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: c.textMuted,
                  fontSize: 12,
                ),
              ),
            );
          }),
          if (items.length > 3)
            Text(
              '  ...و ${items.length - 3} أصناف أخرى',
              style: GoogleFonts.ibmPlexSansArabic(
                color: c.textDisabled,
                fontSize: 11,
              ),
            ),

          const SizedBox(height: 10),

          // الإجمالي وأزرار الإجراء والطباعة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    PosConstants.formatMoney(total),
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: c.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  if (total > 0)
                    Text(
                      'إجمالي الطلب',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: c.textDisabled,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  // زر طباعة الفاتورة الحرارية
                  InkWell(
                    onTap: () => _printOrderManually(context, orderId, data),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: c.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: c.primary.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.print_rounded,
                            size: 16,
                            color: c.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'طباعة 🖨️',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: c.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // زر طباعة بون المطبخ KOT للشيف
                  InkWell(
                    onTap: () => _printKitchenTicketManually(context, orderId, data),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 7),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: c.gold.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.soup_kitchen_rounded,
                            size: 15,
                            color: c.gold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'بون المطبخ',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: c.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // أزرار الحالة
                  if (status == 'pending') ...[
                    _buildActionButton(
                      'قبول',
                      c.success,
                      () => _updateStatus(orderId, 'preparing'),
                    ),
                    const SizedBox(width: 6),
                    _buildActionButton(
                      'رفض',
                      c.danger,
                      () => _updateStatus(orderId, 'cancelled'),
                    ),
                  ],
                  if (status == 'preparing')
                    _buildActionButton(
                      'جاهز للتسليم',
                      c.accent,
                      () => _updateStatus(orderId, 'ready'),
                    ),
                  if (status == 'ready')
                    _buildActionButton(
                      'تم التسليم',
                      c.success,
                      () => _updateStatus(orderId, 'completed'),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton(
      onPressed: () {
        AudioAlertService.stopAlarm();
        onTap();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(64, 44),
      ),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _printOrderManually(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
  ) async {
    HapticFeedback.selectionClick();
    final c = context.posColors;
    try {
      final posOrder = PosOrder.fromMap(data, orderId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('جاري إرسال الفاتورة إلى الطابعة الحرارية... 🖨️'),
          duration: const Duration(seconds: 1),
          backgroundColor: c.primary,
        ),
      );

      final ok = await ThermalPrinterService.printOrder(order: posOrder);
      if (!context.mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تمت طباعة الفاتورة بنجاح ✅'),
            backgroundColor: c.success,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشلت الطباعة - تأكد من اتصال الطابعة أو تعريفها في ويندوز'),
            backgroundColor: c.danger,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء الطباعة: $e'),
          backgroundColor: c.danger,
        ),
      );
    }
  }

  Future<void> _printKitchenTicketManually(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
  ) async {
    HapticFeedback.selectionClick();
    final c = context.posColors;
    try {
      final posOrder = PosOrder.fromMap(data, orderId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('جاري طباعة بون المطبخ (KOT)... 👨‍🍳'),
          duration: const Duration(seconds: 1),
          backgroundColor: c.primary,
        ),
      );

      final ok = await ThermalPrinterService.printKitchenTicketOnly(order: posOrder);
      if (!context.mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تمت طباعة بون المطبخ بنجاح ✅'),
            backgroundColor: c.success,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر طباعة بون المطبخ - تأكد من الطابعة'),
            backgroundColor: c.danger,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء الطباعة: $e'),
          backgroundColor: c.danger,
        ),
      );
    }
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}