import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/notification_router.dart';
import 'package:dalal_alqaim/core/app_globals.dart';
import 'package:intl/intl.dart' hide TextDirection;

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  void _showClearAllConfirmDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 24),
              SizedBox(width: 8),
              Text('مسح كل الإشعارات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text(
            'متأكد تريد تمسح كل الإشعارات؟ ما راح تكدر ترجعها بعد الحذف عيوني.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                Navigator.pop(ctx);
                await NotificationService.clearAllNotifications(userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('مسحنا كل الإشعارات بنجاح')),
                  );
                }
              },
              child: const Text('امسح الكل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("سجّل دخولك أولاً يا غالي")));
    }

    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        final bgColor = isDark ? const Color(0xFF07191A) : Colors.white;
        final cardColor = isDark ? const Color(0xFF113033) : const Color(0xFFF8F9FA);
        final textColor = isDark ? Colors.white : const Color(0xFF333333);

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            title: Text(
              'الإشعارات والتنبيهات',
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_forward_ios_rounded, color: textColor, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                tooltip: 'تحديد الكل كمقروء',
                icon: Icon(Icons.done_all_rounded, color: textColor.withValues(alpha: 0.8), size: 22),
                onPressed: () async {
                  await NotificationService.markAllAsRead(user.uid);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('صار، كل الإشعارات صارت مقروءة'), duration: Duration(seconds: 2)),
                    );
                  }
                },
              ),
              IconButton(
                tooltip: 'مسح الكل',
                icon: Icon(Icons.delete_sweep_outlined, color: Colors.redAccent.withValues(alpha: 0.8), size: 22),
                onPressed: () => _showClearAllConfirmDialog(context, user.uid),
              ),
            ],
          ),
          body: StreamBuilder<List<AppNotification>>(
            stream: NotificationService.getNotificationsStream(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState(isDark, textColor);
              }

              final notifications = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return _buildNotificationCard(context, notif, isDark, cardColor, textColor);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark, Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: textColor.withValues(alpha: 0.2)),
          const SizedBox(height: 18),
          Text(
            'ماكو إشعارات جديدة هسة',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'أي تحديث عن رحلاتك أو طلباتك راح يوصلك هنا فوراً!',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    AppNotification notif,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    IconData icon;
    Color iconColor;

    // Exhaustive switch handling all NotificationTypes
    switch (notif.type) {
      case NotificationType.restaurant:
        icon = Icons.restaurant;
        iconColor = Colors.orange;
        break;
      case NotificationType.taxi:
        icon = Icons.local_taxi;
        iconColor = Colors.yellow.shade700;
        break;
      case NotificationType.parcel:
        icon = Icons.inventory_2;
        iconColor = Colors.blue;
        break;
      case NotificationType.mersal:
        icon = Icons.auto_awesome;
        iconColor = const Color(0xFF26A69A);
        break;
      case NotificationType.delegate:
        icon = Icons.hail_rounded;
        iconColor = Colors.purple;
        break;
      case NotificationType.vacancy:
        icon = Icons.work;
        iconColor = Colors.green;
        break;
      case NotificationType.complaint:
        icon = Icons.report;
        iconColor = Colors.red;
        break;
      case NotificationType.system:
        icon = Icons.notifications;
        iconColor = Colors.grey;
        break;
      case NotificationType.real_estate:
        icon = Icons.home_work;
        iconColor = Colors.indigo;
        break;
    }

    return GestureDetector(
      onTap: () {
        NotificationService.markAsRead(notif.id);
        final Map<String, dynamic> routingData = Map<String, dynamic>.from(notif.data);
        routingData['type'] = routingData['type'] ?? notif.type.name;
        NotificationRouter.handleNotificationData(routingData);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border:
              notif.isRead ? null : Border.all(color: iconColor.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notif.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      Text(
                        DateFormat('hh:mm a').format(notif.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notif.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!notif.isRead)
              Container(
                margin: const EdgeInsets.only(top: 5, left: 5),
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
