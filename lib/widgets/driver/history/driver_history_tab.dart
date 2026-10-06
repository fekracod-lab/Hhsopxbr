import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:dalal_alqaim/utils/theme_constants.dart';
import '../requests/location_row.dart';

class DriverHistoryTab extends StatelessWidget {
  final Stream<QuerySnapshot>? historyStream;
  final bool isDark;

  const DriverHistoryTab({super.key, required this.historyStream, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (historyStream == null) {
      return const Center(
        child: Text(
          'يرجى التأكد من تسجيل دخولك ككابتن',
          style: TextStyle(fontFamily: AppTheme.kFontFamily),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: historyStream!,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history_rounded,
            title: 'ماكو مشاوير سابقة لحد هسه',
            subtitle: 'كل الدروب اللي تكملها بالسلامة راح تنحفظ هنا مع حساب الأرباح',
            isDark: isDark,
          );
        }

        final history = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final doc = history[index];
            final data = doc.data() as Map<String, dynamic>;
            final tripId = doc.id;
            return _buildHistoryCard(context, data, tripId, isDark);
          },
        );
      },
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> data, String tripId, bool isDark) {
    final price = _formatPrice(data['price']);
    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : (data['acceptedAt'] is Timestamp ? (data['acceptedAt'] as Timestamp).toDate() : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C2428) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showTripReceiptSheet(context, data, tripId, isDark),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 6),
                        const Text(
                          'وصل بالسلامة',
                          style: TextStyle(
                            fontFamily: AppTheme.kFontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          price,
                          style: const TextStyle(
                            fontFamily: AppTheme.kFontFamily,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? Colors.white38 : Colors.grey),
                      ],
                    ),
                  ],
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      DateFormat('yyyy/MM/dd - hh:mm a').format(createdAt),
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45),
                    ),
                  ),
                ],
                const Divider(height: 20),
                LocationRow(
                  icon: Icons.radio_button_checked,
                  text: data['pickupAddress'] ?? 'موقع الزبون',
                  color: AppTheme.primaryColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                LocationRow(
                  icon: Icons.location_on,
                  text: data['dropoffAddress'] ?? data['destinationAddress'] ?? 'الوجهة',
                  color: AppTheme.errorColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الراكب: ${data['userName'] ?? data['passengerName'] ?? 'زبون مدار'}',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'عرض الإيصال',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ── نافذة إيصال وتفاصيل المشوار الكامل (Trip Receipt Modal) ──
  // ════════════════════════════════════════════════════════════════════════════
  void _showTripReceiptSheet(BuildContext context, Map<String, dynamic> data, String tripId, bool isDark) {
    final double rawPrice = double.tryParse(data['price']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;
    final double commission = rawPrice * 0.10; // عمولة 10%
    final double netEarnings = rawPrice - commission;

    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : (data['acceptedAt'] is Timestamp ? (data['acceptedAt'] as Timestamp).toDate() : DateTime.now());

    final passengerName = data['userName'] ?? data['passengerName'] ?? 'زبون مدار';
    final passengerPhone = data['userPhone'] ?? data['passengerPhone'] ?? '';
    final pickup = data['pickupAddress'] ?? 'غير محدد';
    final dropoff = data['dropoffAddress'] ?? data['destinationAddress'] ?? 'غير محدد';
    final distance = data['distance']?.toString() ?? '-- كم';
    final duration = data['duration']?.toString() ?? '-- دقيقة';
    final paymentMethod = data['paymentMethod'] ?? 'نقداً';
    final passengerRating = (data['passengerRating'] as num?)?.toDouble();
    final passengerComment = data['passengerComment'] as String? ?? '';
    final passengerCompliments = (data['passengerCompliments'] as List?)?.map((e) => e.toString()).toList() ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C2428) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),

                // Receipt Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryColor, size: 24),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إيصال المشوار',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              '#${tripId.length > 8 ? tripId.substring(0, 8).toUpperCase() : tripId}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'مكتمل بنجاح',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('yyyy/MM/dd - hh:mm a').format(createdAt),
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                ),

                const Divider(height: 24),

                // Net Earnings Highlight Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF0F3A37), const Color(0xFF062322)]
                          : [const Color(0xFFE0F2F1), const Color(0xFFB2DFDB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'صافي ربح الكابتن من هذا الدرب',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${NumberFormat('#,###').format(netEarnings)} د.ع',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          color: isDark ? Colors.white : const Color(0xFF004D40),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text('الأجرة: ${NumberFormat('#,###').format(rawPrice)} د.ع', style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87)),
                          Text('العمولة: -${NumberFormat('#,###').format(commission)} د.ع', style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          Text('الدفع: $paymentMethod', style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Route Details
                Text(
                  'تفاصيل المسار',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF07191A) : const Color(0xFFF8FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      LocationRow(icon: Icons.radio_button_checked, text: pickup, color: AppTheme.primaryColor, isDark: isDark),
                      const SizedBox(height: 10),
                      LocationRow(icon: Icons.location_on, text: dropoff, color: AppTheme.errorColor, isDark: isDark),
                      const Divider(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.straighten_rounded, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text('المسافة: $distance', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text('الوقت: $duration', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Passenger & Review Details
                Text(
                  'بيانات الزبون والتقييم',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF07191A) : const Color(0xFFF8FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                            child: const Icon(Icons.person, color: AppTheme.primaryColor, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(passengerName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                                if (passengerPhone.isNotEmpty)
                                  Text(passengerPhone, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (passengerRating != null) ...[
                        const Divider(height: 16),
                        Row(
                          children: [
                            const Text('تقييم الزبون لك:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Row(
                              children: List.generate(5, (i) {
                                return Icon(
                                  i < passengerRating ? Icons.star_rounded : Icons.star_border_rounded,
                                  color: Colors.amber,
                                  size: 16,
                                );
                              }),
                            ),
                          ],
                        ),
                        if (passengerComment.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(' "$passengerComment"', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? Colors.white70 : Colors.black87)),
                        ],
                        if (passengerCompliments.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: passengerCompliments.map((c) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(6)),
                              child: Text(c, style: const TextStyle(fontSize: 9.5, color: Color(0xFF00796B), fontWeight: FontWeight.bold)),
                            )).toList(),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('إغلاق الفاتورة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(dynamic p) {
    if (p == null) return 'غير محدد';
    final n = double.tryParse(p.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
    if (n == null) return p.toString();
    return '${NumberFormat('#,###').format(n)} د.ع';
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 54, color: AppTheme.primaryColor.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.kFontFamily,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkText : AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppTheme.kFontFamily, fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
