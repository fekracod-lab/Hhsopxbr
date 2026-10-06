import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:rest_madar/core/theme/app_theme.dart';
import 'package:rest_madar/core/widgets/made_in_iraq_badge.dart';
import 'package:rest_madar/features/shell/presentation/desktop_shell_page.dart' show MadarNav;

/// نموذج إشعار في نظام مطاعم مدار
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type; // 'order', 'stock', 'delivery', 'system', 'payment'
  final bool isRead;
  final DateTime createdAt;
  final String? actionRoute;
  final String? relatedId;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.actionRoute,
    this.relatedId,
  });

  factory NotificationItem.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return NotificationItem(
      id: id,
      title: map['title']?.toString() ?? 'إشعار جديد',
      message: map['message']?.toString() ?? '',
      type: map['type']?.toString() ?? 'system',
      isRead: map['isRead'] as bool? ?? false,
      createdAt: parseDate(map['createdAt']),
      actionRoute: map['actionRoute']?.toString(),
      relatedId: map['relatedId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'actionRoute': actionRoute,
      'relatedId': relatedId,
    };
  }

  NotificationItem copyWith({
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    String? actionRoute,
    String? relatedId,
  }) {
    return NotificationItem(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      actionRoute: actionRoute ?? this.actionRoute,
      relatedId: relatedId ?? this.relatedId,
    );
  }
}

class NotificationsCenterPage extends StatefulWidget {
  final void Function(int navIndex)? onNavigate;

  const NotificationsCenterPage({super.key, this.onNavigate});

  @override
  State<NotificationsCenterPage> createState() => _NotificationsCenterPageState();
}

class _NotificationsCenterPageState extends State<NotificationsCenterPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _activeId = '';
  String _selectedFilter = 'all';
  bool _soundAlerts = true;

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

  CollectionReference _notificationsRef() {
    final id = _activeId.isNotEmpty ? _activeId : _uid;
    return FirebaseFirestore.instance
        .collection('merchant_notifications')
        .doc(id)
        .collection('notifications');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.background,
        body: StreamBuilder<QuerySnapshot>(
          stream: (_activeId.isEmpty && _uid.isEmpty)
              ? null
              : _notificationsRef().orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<NotificationItem> notifs = [];

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              for (final doc in snapshot.data!.docs) {
                notifs.add(NotificationItem.fromMap(doc.id, doc.data() as Map<String, dynamic>));
              }
            }

            final unreadCount = notifs.where((n) => !n.isRead).length;
            final stockCount = notifs.where((n) => n.type == 'stock').length;
            final orderCount = notifs.where((n) => n.type == 'order').length;

            final filtered = notifs.where((n) {
              if (_selectedFilter == 'all') return true;
              if (_selectedFilter == 'unread') return !n.isRead;
              return n.type == _selectedFilter;
            }).toList();

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // رأس الصفحة
                  _buildHeader(context, c, unreadCount),
                  const SizedBox(height: 20),

                  // كروت الإحصائيات
                  _buildStatCards(
                    c,
                    totalCount: notifs.length,
                    unreadCount: unreadCount,
                    stockCount: stockCount,
                    orderCount: orderCount,
                  ),
                  const SizedBox(height: 20),

                  // شريط الفلترة
                  _buildFilterBar(c),
                  const SizedBox(height: 16),

                  // قائمة الإشعارات
                  Expanded(
                    child: filtered.isEmpty
                        ? _buildEmptyState(c)
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _buildNotificationCard(context, c, filtered[index]);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PosColors c, int unreadCount) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.notifications_active_rounded, color: c.primary, size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'مركز الإشعارات والتنبيهات المباشرة',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$unreadCount جديدة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                const MadeInIraqBadge(isCompact: false),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'سجل عمليات حي ومربوط لحظياً مع الكاشير والمطبخ والمناديب وتطبيق مدار',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12.5,
                color: c.textMuted,
              ),
            ),
          ],
        ),
        const Spacer(),
        // مفتاح تشغيل/كتم الصوت
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: IconButton(
            icon: Icon(
              _soundAlerts ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _soundAlerts ? const Color(0xFF10B981) : c.textMuted,
              size: 20,
            ),
            tooltip: _soundAlerts ? 'تنبيهات الصوت مفعلة' : 'تنبيهات الصوت مكتومة',
            onPressed: () {
              setState(() => _soundAlerts = !_soundAlerts);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_soundAlerts ? 'تم تفعيل التنبيه الصوتي للإشعارات 🔔' : 'تم كتم التنبيه الصوتي 🔕'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        // زر تنظيف المقروءة
        OutlinedButton.icon(
          onPressed: _clearAllRead,
          icon: const Icon(Icons.cleaning_services_rounded, size: 16),
          label: Text(
            'مسح المقروءة',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.textMuted,
            side: BorderSide(color: c.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _markAllAsRead,
          icon: const Icon(Icons.done_all_rounded, size: 18),
          label: Text(
            'تحديد الكل كمقروء',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.primary,
            side: BorderSide(color: c.primary.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _simulateTestAlert,
          icon: const Icon(Icons.add_alert_rounded, size: 18),
          label: Text(
            'إشعار تجريبي ⚡',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(
    PosColors c, {
    required int totalCount,
    required int unreadCount,
    required int stockCount,
    required int orderCount,
  }) {
    return Row(
      children: [
        _buildStatCard(
          c,
          title: 'إجمالي الإشعارات',
          value: '$totalCount إشعار',
          icon: Icons.notifications_rounded,
          color: const Color(0xFF6366F1),
        ),
        const SizedBox(width: 14),
        _buildStatCard(
          c,
          title: 'تنبيهات غير مقروءة',
          value: '$unreadCount تنبيه',
          icon: Icons.mark_email_unread_rounded,
          color: const Color(0xFFEF4444),
        ),
        const SizedBox(width: 14),
        _buildStatCard(
          c,
          title: 'تنبيهات نقص المستودع',
          value: '$stockCount تنبيه',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFF59E0B),
        ),
        const SizedBox(width: 14),
        _buildStatCard(
          c,
          title: 'إشعارات الطلبات والبيع',
          value: '$orderCount طلب',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF10B981),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    PosColors c, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5,
                    color: c.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(PosColors c) {
    final filters = [
      {'id': 'all', 'label': 'جميع الإشعارات'},
      {'id': 'unread', 'label': 'غير المقروءة'},
      {'id': 'order', 'label': 'الطلبات والمبيعات'},
      {'id': 'stock', 'label': 'نواقص المستودع'},
      {'id': 'delivery', 'label': 'حركة التوصيل'},
      {'id': 'system', 'label': 'تنبيهات النظام'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['id'];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(
                f['label']!,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : c.textPrimary,
                ),
              ),
              selected: isSelected,
              selectedColor: c.primary,
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? c.primary : c.border,
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedFilter = f['id']!);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, PosColors c, NotificationItem notif) {
    final color = _getNotificationColor(notif.type);
    final icon = _getNotificationIcon(notif.type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: notif.isRead ? c.surface : c.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: notif.isRead ? c.border : c.primary.withValues(alpha: 0.35),
          width: notif.isRead ? 1 : 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // أيقونة نوع الإشعار
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),

          // نص الإشعار وتفاصيله
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      notif.title,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                        fontSize: 14.5,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getTypeName(notif.type),
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: color,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!notif.isRead) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  notif.message,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    color: c.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 12, color: c.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('yyyy/MM/dd - hh:mm a').format(notif.createdAt),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildActionButton(context, notif, color),
              ],
            ),
          ),

          // أزرار الإجراءات
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  notif.isRead ? Icons.mark_email_read_rounded : Icons.mark_email_unread_rounded,
                  color: notif.isRead ? c.textMuted : c.primary,
                  size: 20,
                ),
                tooltip: notif.isRead ? 'مقروء' : 'تحديد كمقروء',
                onPressed: () => _toggleReadStatus(notif),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                tooltip: 'حذف الإشعار',
                onPressed: () => _deleteNotification(notif),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(PosColors c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined, size: 60, color: c.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text(
            'لا توجد إشعارات في هذا التصنيف',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ستظهر الإشعارات والتنبيهات المباشرة فور حدوث أي نشاط في المطعم',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: c.textMuted),
          ),
        ],
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'order':
        return const Color(0xFF10B981);
      case 'stock':
        return const Color(0xFFEF4444);
      case 'delivery':
        return const Color(0xFF0EA5E9);
      case 'system':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFFFF5B22);
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag_rounded;
      case 'stock':
        return Icons.inventory_2_rounded;
      case 'delivery':
        return Icons.two_wheeler_rounded;
      case 'system':
        return Icons.settings_suggest_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _getTypeName(String type) {
    switch (type) {
      case 'order':
        return 'طلب بيع';
      case 'stock':
        return 'مخزون';
      case 'delivery':
        return 'توصيل';
      case 'system':
        return 'نظام';
      default:
        return 'عام';
    }
  }

  Future<void> _toggleReadStatus(NotificationItem notif) async {
    if (_activeId.isEmpty) return;

    try {
      await _notificationsRef()
          .doc(notif.id)
          .update({'isRead': !notif.isRead});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _deleteNotification(NotificationItem notif) async {
    if (_activeId.isEmpty) return;

    try {
      await _notificationsRef()
          .doc(notif.id)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحذف: $e')));
      }
    }
  }

  Future<void> _markAllAsRead() async {
    if (_activeId.isEmpty) return;

    try {
      final snap = await _notificationsRef()
          .where('isRead', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديد كافة الإشعارات كمقروءة'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _simulateTestAlert() async {
    final newItem = NotificationItem(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: 'إشعار فوري: فحص اتصال مدار',
      message: 'تم التحقق من ربط محطة الكاشير مع سحابة مدار بنجاح. حالة التوصيل والطابعات الحرارية ممتازة.',
      type: 'system',
      isRead: false,
      createdAt: DateTime.now(),
    );

    if (_activeId.isEmpty) return;

    try {
      await _notificationsRef().add(newItem.toMap());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _clearAllRead() async {
    if (_activeId.isEmpty) return;
    try {
      final snap = await _notificationsRef().where('isRead', isEqualTo: true).get();
      if (snap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد إشعارات مقروءة لمسحها')),
          );
        }
        return;
      }
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تنظيف كافة الإشعارات المقروءة بنجاح 🧹'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Widget _buildActionButton(BuildContext context, NotificationItem notif, Color color) {
    String label;
    IconData icon;
    int targetNav;

    switch (notif.type) {
      case 'order':
        label = 'معاينة في الطلبات والكاشير ⚡';
        icon = Icons.receipt_long_rounded;
        targetNav = MadarNav.orders;
        break;
      case 'delivery':
        label = 'متابعة أسطول التوصيل 🛵';
        icon = Icons.two_wheeler_rounded;
        targetNav = MadarNav.delivery;
        break;
      case 'stock':
        label = 'فحص قائمة المنيو 📦';
        icon = Icons.restaurant_menu_rounded;
        targetNav = MadarNav.menu;
        break;
      case 'system':
        label = 'فحص إعدادات النظام ⚙️';
        icon = Icons.settings_rounded;
        targetNav = MadarNav.settings;
        break;
      default:
        label = 'فتح شاشة المطبخ 👨‍🍳';
        icon = Icons.soup_kitchen_rounded;
        targetNav = MadarNav.kds;
    }

    return OutlinedButton.icon(
      onPressed: () {
        if (!notif.isRead) {
          _toggleReadStatus(notif);
        }
        widget.onNavigate?.call(targetNav);
      },
      icon: Icon(icon, size: 14, color: color),
      label: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
