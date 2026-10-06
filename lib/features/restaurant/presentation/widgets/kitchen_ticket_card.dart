import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dalal_alqaim/services/ringtone_manager.dart';
import 'package:dalal_alqaim/services/notification_service.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/features/restaurant/presentation/widgets/thermal_printer_modal.dart';

class KitchenTicketCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;

  const KitchenTicketCard({
    super.key,
    required this.orderId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? app_colors.darkCard : Colors.white;
    final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;
    final textSecondary = isDark ? app_colors.darkSubText : app_colors.subTextColor;

    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final itemsList = (data['items'] as List<dynamic>?) ?? [];
    final totalPrice = data['total'] ??
        data['totalPrice'] ??
        data['grandTotal'] ??
        0;
    final deliveryFee = data['deliveryFee'] ?? data['deliveryPrice'] ?? 0;
    final buyerName = data['customerName'] ??
        data['buyerName'] ??
        data['userName'] ??
        'زبون مدار';
    final buyerPhone = data['customerPhone'] ??
        data['buyerPhone'] ??
        data['userPhone'] ??
        '';
    final deliveryAddress = data['deliveryAddress'] ??
        data['address'] ??
        'استلام من المطعم سفري';
    final specialNotes = data['notes'] ?? data['specialInstructions'] ?? '';
    final driverName = data['driverName'] ?? data['captainName'];

    // Time formatting
    DateTime? orderTime;
    if (data['createdAt'] is Timestamp) {
      orderTime = (data['createdAt'] as Timestamp).toDate();
    } else if (data['timestamp'] is Timestamp) {
      orderTime = (data['timestamp'] as Timestamp).toDate();
    } else if (data['orderTime'] != null) {
      try {
        orderTime = DateTime.parse(data['orderTime'].toString());
      } catch (_) {}
    }
    String formattedTime = 'هسة';
    if (orderTime != null) {
      try {
        formattedTime = DateFormat('hh:mm a', 'ar_IQ').format(orderTime);
      } catch (_) {
        try {
          formattedTime = DateFormat('hh:mm a', 'ar').format(orderTime);
        } catch (_) {
          formattedTime = DateFormat('hh:mm a').format(orderTime);
        }
      }
    }

    final (statusLabel, statusColor, statusIcon) = _getStatusConfig(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: status == 'pending'
              ? const Color(0xFFFFB830).withValues(alpha: 0.6)
              : (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.6),
          width: status == 'pending' ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: status == 'pending'
                ? const Color(0xFFFFB830).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Ticket Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: isDark ? 0.15 : 0.08),
                border: Border(
                  bottom: BorderSide(
                    color: statusColor.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 5),
                        Text(
                          statusLabel,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '#${orderId.length > 6 ? orderId.substring(orderId.length - 6).toUpperCase() : orderId}',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.schedule_rounded, size: 14, color: textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    formattedTime,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.print_rounded,
                      color: app_colors.primaryColor,
                      size: 20,
                    ),
                    tooltip: 'طباعة الوصل',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ThermalPrinterModal.show(
                        context,
                        orderData: data,
                        orderId: orderId,
                      );
                    },
                  ),
                ],
              ),
            ),

            // 2. Customer Information Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: app_colors.primaryColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_pin_circle_rounded,
                      color: app_colors.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          buyerName,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          deliveryAddress,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            color: textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (buyerPhone.toString().isNotEmpty)
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_rounded,
                          color: Colors.green,
                          size: 16,
                        ),
                      ),
                      onPressed: () => _callPhone(buyerPhone.toString()),
                      tooltip: 'خابر الزبون',
                    ),
                ],
              ),
            ),

            // 3. Special Notes / Allergy Alerts
            if (specialNotes.toString().trim().isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ملاحظة الزبون : $specialNotes',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 4. Order Items List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: itemsList.map((item) {
                  final iMap = item is Map<String, dynamic>
                      ? item
                      : <String, dynamic>{};
                  final name = iMap['title'] ??
                      iMap['name'] ??
                      iMap['mealName'] ??
                      'وجبة طعام';
                  final qty = iMap['quantity'] ?? iMap['qty'] ?? 1;
                  final price = iMap['price'] ?? 0;
                  final itemNotes = iMap['notes'] ?? iMap['selectedOptions'];

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: app_colors.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${qty}x',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: app_colors.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.toString(),
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              if (itemNotes != null && itemNotes.toString().isNotEmpty)
                                Text(
                                  itemNotes.toString(),
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 10,
                                    color: textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '$price د.ع',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // 5. Financial Summary Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (driverName != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.sports_motorsports_rounded,
                          size: 16,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'الكابتن: $driverName',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ],
                    )
                  else if (deliveryFee > 0)
                    Text(
                      'أجرة التوصيل: $deliveryFee د.ع',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      Text(
                        'المجموع الكلي:',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          color: textSecondary,
                        ),
                      ),
                      Text(
                        '$totalPrice د.ع',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                          color: app_colors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 6. Action Buttons Bar
            _buildActionButtons(context, status),
          ],
        ),
      ),
    );
  }

  (String, Color, IconData) _getStatusConfig(String status) {
    switch (status) {
      case 'pending':
        return ('طلبية جديدة واصلة', const Color(0xFFFFB830), Icons.notifications_active_rounded);
      case 'accepted':
      case 'preparing':
        return ('جاي نحضّرها بالمطبخ', const Color(0xFFFF7043), Icons.soup_kitchen_rounded);
      case 'ready':
        return ('جاهزة تنتظر الكابتن', app_colors.primaryColor, Icons.takeout_dining_rounded);
      case 'delivering':
      case 'on_way':
        return ('بالطريق وية الكابتن', Colors.blueAccent, Icons.motorcycle_rounded);
      case 'completed':
        return ('تسلمت للزبون وعاشت إيدك', const Color(0xFF00E676), Icons.check_circle_rounded);
      case 'rejected':
      case 'cancelled':
        return ('ملغية', Colors.redAccent, Icons.cancel_rounded);
      default:
        return (status, Colors.grey, Icons.info_outline_rounded);
    }
  }

  Widget _buildActionButtons(BuildContext context, String status) {
    if (status == 'pending') {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => _updateStatus(context, 'accepted'),
                icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                label: Text(
                  'استلم وحضّر الطلبية',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: app_colors.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _updateStatus(context, 'rejected'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  'اعتذار / رفض',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (status == 'accepted' || status == 'preparing') {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: ElevatedButton.icon(
          onPressed: () => _updateStatus(context, 'ready'),
          icon: const Icon(Icons.done_all_rounded, color: Colors.white, size: 18),
          label: Text(
            'كمّلناها وجاهزة للتسليم',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7043),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
        ),
      );
    } else if (status == 'ready') {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: ElevatedButton.icon(
          onPressed: () => _updateStatus(context, 'completed'),
          icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          label: Text(
            'تم تسليمها للزبون وعاشت إيدك',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E676),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      HapticFeedback.mediumImpact();
      RingtoneManager.stopAlarm('order_$orderId');

      final batch = FirebaseFirestore.instance.batch();
      final mainOrderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
      batch.update(mainOrderRef, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final restaurantId = data['restaurantId'] ?? data['restaurantDocId'];
      if (restaurantId != null && restaurantId.toString().isNotEmpty) {
        final restaurantOrderRef = FirebaseFirestore.instance
            .collection('restaurants')
            .doc(restaurantId.toString())
            .collection('orders')
            .doc(orderId);
        batch.update(restaurantOrderRef, {'status': newStatus});
      }

      final customerId = data['customerId'] ?? data['userId'];
      if (customerId != null && customerId.toString().isNotEmpty) {
        final customerOrderRef = FirebaseFirestore.instance
            .collection('madar_orders')
            .doc(customerId.toString())
            .collection('orders')
            .doc(orderId);
        batch.update(customerOrderRef, {'status': newStatus});
      }

      await batch.commit();

      if (newStatus == 'ready') {
        try {
          final String rId = (data['restaurantId'] ?? data['restaurantDocId'] ?? '').toString();
          await NotificationService.emitEvent(
            type: 'food_order_ready',
            payload: {
              'orderId': orderId,
              'restaurantId': rId,
              'restaurantName': data['restaurantName'] ?? 'المطعم',
            },
          );
        } catch (e) {
          debugPrint('Error emitting food_order_ready: $e');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'accepted'
                  ? 'استلمنا الطلبية وجاي نجهّزها بالمطبخ، عاشت إيدك!'
                  : (newStatus == 'rejected'
                      ? 'تم رفض الطلبية والاعتذار للزبون'
                      : 'تحدّثت حالة الطلبية بنجاح'),
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: newStatus == 'accepted'
                ? app_colors.primaryColor
                : (newStatus == 'rejected' ? Colors.redAccent : app_colors.accentColor),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'صار خطأ أثناء التحديث: $e',
              style: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
