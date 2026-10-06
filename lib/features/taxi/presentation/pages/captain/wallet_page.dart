import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import 'package:dalal_alqaim/services/driver_service.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final _driverService = DriverService();
  final _currencyFormat = NumberFormat.currency(symbol: 'د.ع', decimalDigits: 0, locale: 'ar');

  int _todayTrips = 0;
  double _todayEarnings = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDailyStats();
  }

  Future<void> _loadDailyStats() async {
    final uid = _uid;
    if (uid == null) return;
    final stats = await _driverService.getDailyStats(uid);
    if (mounted) {
      setState(() {
        _todayTrips = stats['trips'] ?? 0;
        _todayEarnings = (stats['earnings'] as num?)?.toDouble() ?? 0.0;
      });
    }
  }

  void _openWhatsAppSettlement(double appDebt) {
    final text = 'مرحباً إدارة مدار، أود تسوية عمولة رحلات التاكسي لحسابي.\n'
        'المبلغ المستحق: ${NumberFormat('#,###').format(appDebt)} د.ع\n'
        'معرف الكابتن: $_uid';
    launchUrl(
      Uri.parse('https://wa.me/9647819436408?text=${Uri.encodeComponent(text)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF07191A),
        body: Center(child: Text('سجّل دخولك أولاً', style: TextStyle(color: Colors.white))),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF07191A), // Dark Luxury Background
        appBar: AppBar(
          title: const Text('المحفظة والعمولات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          centerTitle: true,
          backgroundColor: const Color(0xFF0C2428),
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('drivers').doc(_uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF26A69A)));

            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final double appDebt = (data['appDebt'] as num?)?.toDouble() ?? 0.0;
            final double maxLimit = (data['customCommissionLimit'] as num?)?.toDouble() ?? 5000.0;
            final bool commissionException = data['commissionException'] == true;
            final double totalEarnings = (data['totalEarnings'] as num?)?.toDouble() ?? 0.0;
            final double balance = (data['balance'] as num?)?.toDouble() ?? 0.0;

            final bool isBlocked = (appDebt >= maxLimit && !commissionException);

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // 1. Commission & Debt Card (بطاقة مديونية العمولة والحد المسموح)
                  _buildCommissionDebtCard(appDebt, maxLimit, isBlocked, commissionException),

                  // 2. Withdrawable Electronic Balance (رصيد المحفظة الإلكترونية القابل للسحب)
                  _buildWithdrawableBalanceCard(balance),

                  // 3. Earnings & Stats Summary Card (أرباح الكابتن الإجمالية)
                  _buildEarningsSummaryCard(totalEarnings, balance),

                  // 4. Transactions & Trips History (سجل خصومات العمولات والأرباح)
                  _buildTransactionsSection(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── 1. بطاقة عمولة التطبيق والمديونية وسياسة الـ 5,000 د.ع ──
  Widget _buildCommissionDebtCard(double appDebt, double maxLimit, bool isBlocked, bool hasException) {
    final double progress = (appDebt / maxLimit).clamp(0.0, 1.0);
    final double remaining = (maxLimit - appDebt).clamp(0.0, maxLimit);

    Color cardBorderColor = const Color(0xFF26A69A).withValues(alpha: 0.3);
    Color progressColor = const Color(0xFF26A69A);
    String statusTitle = 'الحساب نشط ويستقبل الطلبات';
    Color statusBg = Colors.green.withValues(alpha: 0.15);
    Color statusTextColor = Colors.greenAccent;

    if (hasException) {
      statusTitle = 'استثناء مالي مفعل من الإدارة';
      statusBg = Colors.amber.withValues(alpha: 0.15);
      statusTextColor = Colors.amberAccent;
      progressColor = Colors.amber;
    } else if (isBlocked) {
      statusTitle = 'موقوف عن استقبال الطلبات لتجاوز 5,000 د.ع';
      statusBg = Colors.red.withValues(alpha: 0.2);
      statusTextColor = Colors.redAccent;
      cardBorderColor = Colors.redAccent.withValues(alpha: 0.7);
      progressColor = Colors.redAccent;
    } else if (progress > 0.7) {
      statusTitle = 'تحذير: اقتربت من بلوغ حد الـ 5,000 د.ع';
      statusBg = Colors.orange.withValues(alpha: 0.15);
      statusTextColor = Colors.orangeAccent;
      progressColor = Colors.orangeAccent;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2428),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: progressColor.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badges Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF004D40),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF26A69A).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.percent_rounded, color: Colors.tealAccent, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'عمولة التطبيق: 10%',
                      style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: statusTextColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusTitle,
                  style: TextStyle(color: statusTextColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Text(
            'عمولة التطبيق المستحقة بذمتك',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                NumberFormat('#,###').format(appDebt),
                style: TextStyle(
                  color: isBlocked ? Colors.redAccent : Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              const Text('د.ع', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                'الحد الأقصى: ${NumberFormat('#,###').format(maxLimit)} د.ع',
                style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
            ),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isBlocked
                    ? 'تجاوزت الحد بمقدار: ${(appDebt - maxLimit).abs().toStringAsFixed(0)} د.ع'
                    : 'المتبقي حتى إيقاف الطلبات: ${remaining.toStringAsFixed(0)} د.ع',
                style: TextStyle(
                  color: isBlocked ? Colors.redAccent : Colors.white60,
                  fontSize: 11,
                  fontWeight: isBlocked ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: progressColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Policy Info Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isBlocked
                  ? Colors.red.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isBlocked ? Colors.redAccent.withValues(alpha: 0.3) : Colors.white12,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isBlocked ? Icons.block_rounded : Icons.info_outline_rounded,
                      color: isBlocked ? Colors.redAccent : Colors.tealAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isBlocked ? 'تنبيه: تم إيقاف استقبال الطلبات' : 'شروط وقوانين قبول المشاوير',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isBlocked ? Colors.redAccent : Colors.tealAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isBlocked
                      ? 'لا يمكنك قبول أي طلبات جديدة الآن لأن مديونية العمولة بلغت (5,000 د.ع أو أكثر). يرجى سداد المبلغ وتصفير المحفظة لدى الإدارة لفك القفل واستئناف العمل فوراً.'
                      : 'عمولة التطبيق هي 10% فقط من كل مشوار. إذا بلغت ديون العمولة 5,000 د.ع يتم إيقاف قبول الطلبات تلقائياً حتى يتم تسديد وتصفير المحفظة.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isBlocked ? Colors.white : Colors.white70,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Settlement Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _openWhatsAppSettlement(appDebt),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              label: Text(
                isBlocked ? 'سداد وتصفير المحفظة لفك الحظر (واتساب)' : 'تسديد وتصفير العمولة مع الإدارة (واتساب)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isBlocked ? Colors.green.shade600 : const Color(0xFF26A69A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. بطاقة رصيد المحفظة القابل للسحب ──
  Widget _buildWithdrawableBalanceCard(double balance) {
    if (balance <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF26A69A).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('رصيد المحفظة القابل للسحب', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  Text(
                    '${NumberFormat('#,###').format(balance)} د.ع',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF004D40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () {
              final text = 'مرحباً إدارة مدار، أود طلب سحب رصيد محفظتي الإلكترونية.\nالمبلغ: ${NumberFormat('#,###').format(balance)} د.ع\nمعرف الكابتن: $_uid';
              launchUrl(Uri.parse('https://wa.me/9647819436408?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
            },
            child: const Text('طلب سحب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  // ── 3. ملخص الأرباح والرحلات ──
  Widget _buildEarningsSummaryCard(double totalEarnings, double balance) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2323),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('أرباح اليوم', _currencyFormat.format(_todayEarnings), Icons.today_rounded, Colors.amber),
          Container(width: 1, height: 35, color: Colors.white12),
          _buildSummaryItem('إجمالي الأرباح', _currencyFormat.format(totalEarnings), Icons.account_balance_wallet_rounded, Colors.greenAccent),
          Container(width: 1, height: 35, color: Colors.white12),
          _buildSummaryItem('مشاوير اليوم', '$_todayTrips درب', Icons.local_taxi_rounded, Colors.tealAccent),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color iconColor) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
      ],
    );
  }

  int _historyTab = 0;

  // ── 4. سجل العمليات والتسويات ──
  Widget _buildTransactionsSection() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0C2428),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHistoryTabButton(0, 'رحلات المشاوير'),
              const SizedBox(width: 10),
              _buildHistoryTabButton(1, 'سجل التصفير والتسوية'),
            ],
          ),
          const SizedBox(height: 16),

          if (_historyTab == 0) _buildTripsHistoryList() else _buildSettlementsHistoryList(),
        ],
      ),
    );
  }

  Widget _buildHistoryTabButton(int index, String title) {
    final isSelected = _historyTab == index;
    return GestureDetector(
      onTap: () => setState(() => _historyTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF26A69A) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF26A69A) : Colors.white12),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTripsHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .where('driverId', isEqualTo: _uid)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(15)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF26A69A))));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text('ماكو رحلات حالياً مكتملة مسجلة بعد', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.05)),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final double price = double.tryParse(data['price']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ?? '0') ?? 0.0;
            final double commission = (data['commission'] as num?)?.toDouble() ?? (price * 0.1);
            final double netProfit = (data['netProfit'] as num?)?.toDouble() ?? (price - commission);
            final date = (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26A69A).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_taxi_rounded, color: Color(0xFF26A69A), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مشوار #${doc.id.substring(0, mathMin(6, doc.id.length))}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          DateFormat('yyyy/MM/dd - hh:mm a').format(date),
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+ ${_currencyFormat.format(netProfit)}',
                        style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      Text(
                        'العمولة (10%): -${_currencyFormat.format(commission)}',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 10.5),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettlementsHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('commission_settlements')
          .where('driverId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .limit(15)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF26A69A))));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text('ماكو عمليات حالياً تسوية أو تصفير مسجلة بعد', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.05)),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final double amountPaid = (data['amountPaid'] as num?)?.toDouble() ?? 0.0;
            final double remainingDebt = (data['remainingDebt'] as num?)?.toDouble() ?? 0.0;
            final bool isFullReset = data['isFullReset'] == true || remainingDebt == 0.0;
            final String notes = data['notes']?.toString() ?? 'تسوية مع الإدارة';
            final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isFullReset ? Colors.green.withValues(alpha: 0.15) : const Color(0xFF26A69A).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFullReset ? Icons.verified_rounded : Icons.payments_rounded,
                      color: isFullReset ? Colors.greenAccent : const Color(0xFF26A69A),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFullReset ? 'تصفير شامل للمحفظة' : 'تسوية دفعة عمولة',
                          style: TextStyle(
                            color: isFullReset ? Colors.greenAccent : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          notes,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormat('yyyy/MM/dd - hh:mm a').format(date),
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_currencyFormat.format(amountPaid)}',
                        style: TextStyle(
                          color: isFullReset ? Colors.greenAccent : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        isFullReset ? 'الحساب: 0 د.ع' : 'المتبقي: ${_currencyFormat.format(remainingDebt)}',
                        style: TextStyle(
                          color: isFullReset ? Colors.greenAccent : Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  int mathMin(int a, int b) => a < b ? a : b;
}
