import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import 'package:dalal_alqaim/pages/delivery_weekly_accounting_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'ar');

  // Light Palette
  static const Color _bgLight = Color(0xFFF8FAFC);
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF475569);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _primaryLight = Color(0xFF00BFA5);
  static const Color _accentLight = Color(0xFF00897B);

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _bgLight,
          body: Center(child: Text('سجّل دخولك أولاً', style: TextStyle(color: _textMain))),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(
          title: const Text(
            'محفظة وأرباح المندوب',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _textMain),
          ),
          centerTitle: true,
          backgroundColor: _cardLight,
          elevation: 0,
          foregroundColor: _textMain,
        ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('drivers').doc(_uid).snapshots(),
        builder: (context, driverSnap) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(_uid).snapshots(),
            builder: (context, userSnap) {
              final driverData = driverSnap.data?.data() as Map<String, dynamic>? ?? {};
              final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};

              final double balance = (driverData['balance'] as num?)?.toDouble() ??
                  (userData['balance'] as num?)?.toDouble() ??
                  0.0;

              final double totalEarnings = (driverData['totalEarnings'] as num?)?.toDouble() ??
                  (userData['totalEarnings'] as num?)?.toDouble() ??
                  0.0;

              final double appDebt = (driverData['appDebt'] as num?)?.toDouble() ??
                  (userData['appDebt'] as num?)?.toDouble() ??
                  0.0;

              final String delegateName = driverData['name'] ?? userData['name'] ?? 'مندوب مدار';
              final String delegatePhone = driverData['phone'] ?? userData['phone'] ?? '';

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                children: [
                  // 1. بطاقة الرصيد الفخمة (Bento Hero Card)
                  _buildBalanceCard(balance, totalEarnings, appDebt, delegateName, delegatePhone),
                  const SizedBox(height: 14),

                  // 2. زر المحاسبة الأسبوعية والعمولات
                  _buildAccountingRow(appDebt),
                  const SizedBox(height: 18),

                  // 3. قسم طلبات السحب المعلقة
                  _buildPendingWithdrawalsSection(),
                  const SizedBox(height: 18),

                  // 4. سجل أرباح التوصيل الأخيرة
                  _buildRecentTransactionsSection(),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: _buildBottomActions(),
    ),
  );
}

  // ────────────────────────────────────────────
  // 1. بطاقة الرصيد الرئيسية المشرقة
  // ────────────────────────────────────────────
  Widget _buildBalanceCard(
    double balance,
    double totalEarnings,
    double appDebt,
    String name,
    String phone,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primaryLight.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'رصيدك القابل للسحب',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'مندوب مدار',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_currencyFormat.format(balance)} د.ع',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('إجمالي الأرباح', '${_currencyFormat.format(totalEarnings)} د.ع', Colors.white),
                Container(width: 1, height: 28, color: Colors.white24),
                _buildStatItem('العمولة المستحقة', '${_currencyFormat.format(appDebt)} د.ع', appDebt > 0 ? const Color(0xFFFFD54F) : Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(color: valueColor, fontSize: 13.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────
  // 2. زر المحاسبة الأسبوعية وتصفير الحساب
  // ────────────────────────────────────────────
  Widget _buildAccountingRow(double appDebt) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeliveryWeeklyAccountingPage(driverId: _uid!),
                ),
              );
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              decoration: BoxDecoration(
                color: _cardLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderLight),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: _primaryLight, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'المحاسبة الأسبوعية',
                      style: TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: _textSub, size: 13),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: () => _contactAdminToSettle(appDebt),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: const Row(
              children: [
                Icon(Icons.chat_bubble_rounded, color: Color(0xFF2E7D32), size: 18),
                SizedBox(width: 6),
                Text(
                  'تسديد العمولة',
                  style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _contactAdminToSettle(double appDebt) {
    final msg = 'مرحباً إدارة مدار، أود تسديد وتصفير عمولة حساب التوصيل (ID: $_uid).\nالمبلغ المستحق: ${_currencyFormat.format(appDebt)} د.ع\nيرجى تزويدي برقم زين كاش أو الحساب لتسديد المبلغ.';
    launchUrl(Uri.parse('https://wa.me/9647819436408?text=${Uri.encodeComponent(msg)}'), mode: LaunchMode.externalApplication);
  }

  // ────────────────────────────────────────────
  // 3. قسم طلبات السحب المعلقة الحقيقية من Firestore
  // ────────────────────────────────────────────
  Widget _buildPendingWithdrawalsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('withdrawal_requests')
          .where('userId', isEqualTo: _uid)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardLight,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFFFD54F)),
            boxShadow: [
              BoxShadow(color: Colors.amber.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Color(0xFFF57F17), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'طلبات السحب الأخيرة',
                    style: TextStyle(color: _textMain, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final double amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                final String status = data['status'] ?? 'pending';
                final String method = data['method'] ?? 'زين كاش';
                final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

                Color statusColor = const Color(0xFFF57F17);
                String statusText = 'قيد المراجعة';
                if (status == 'approved' || status == 'completed') {
                  statusColor = const Color(0xFF2E7D32);
                  statusText = 'تم التحويل';
                } else if (status == 'rejected') {
                  statusColor = const Color(0xFFD32F2F);
                  statusText = 'مرفوض';
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _borderLight),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_currencyFormat.format(amount)} د.ع ($method)',
                            style: const TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            DateFormat('yyyy/MM/dd - hh:mm a').format(date),
                            style: const TextStyle(color: _textSub, fontSize: 11),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────
  // 4. سجل أرباح وتوصيل الطلبات الأخيرة المشرق
  // ────────────────────────────────────────────
  Widget _buildRecentTransactionsSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: _primaryLight, size: 20),
              SizedBox(width: 8),
              Text(
                'سجل أرباح الطلبات المكتملة',
                style: TextStyle(color: _textMain, fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('mersal_requests')
                .where('driverId', isEqualTo: _uid)
                .where('status', isEqualTo: 'completed')
                .orderBy('createdAt', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: _primaryLight),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'ماكو أرباح مسجلة بعد، أول ما تكمل طلب راح تظهرلك هنا',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _textSub, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(color: _borderLight, height: 1),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final double price = (data['deliveryFee'] as num?)?.toDouble() ??
                      (data['price'] as num?)?.toDouble() ??
                      (data['netProfit'] as num?)?.toDouble() ??
                      3000.0;
                  final date = (data['completedAt'] as Timestamp?)?.toDate() ??
                      (data['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.now();

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF2E7D32), size: 20),
                    ),
                    title: Text(
                      'توصيل طلب #${doc.id.substring(0, doc.id.length > 5 ? 5 : doc.id.length)}',
                      style: const TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text(
                      DateFormat('yyyy/MM/dd - hh:mm a').format(date),
                      style: const TextStyle(color: _textSub, fontSize: 11),
                    ),
                    trailing: Text(
                      '+ ${_currencyFormat.format(price)} د.ع',
                      style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // زر طلب سحب الأرباح المشرق (Withdrawal Action)
  // ────────────────────────────────────────────
  Widget _buildBottomActions() {
    return Container(
      color: _cardLight,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _primaryLight.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showRealWithdrawDialog,
            borderRadius: BorderRadius.circular(18),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'طلب سحب الأرباح',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  // نافذة طلب السحب المشرقة
  // ────────────────────────────────────────────
  void _showRealWithdrawDialog() async {
    final driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(_uid).get();
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();

    final driverData = driverDoc.data() ?? {};
    final userData = userDoc.data() ?? {};

    final double currentBalance = (driverData['balance'] as num?)?.toDouble() ??
        (userData['balance'] as num?)?.toDouble() ??
        0.0;

    final String delegateName = driverData['name'] ?? userData['name'] ?? 'مندوب مدار';
    final String delegatePhone = driverData['phone'] ?? userData['phone'] ?? '';

    final amountController = TextEditingController();
    final accountController = TextEditingController(text: delegatePhone);
    String selectedMethod = 'زين كاش (ZainCash)';
    bool isSubmitting = false;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.payments_rounded, color: _primaryLight, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'طلب سحب أرباح جديد',
                        style: TextStyle(color: _textMain, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'رصيدك المتاح حالياً: ${_currencyFormat.format(currentBalance)} د.ع',
                    style: const TextStyle(color: _accentLight, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),

                  // اختيار طريقة الاستلام
                  const Text('طريقة الاستلام:', style: TextStyle(color: _textSub, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    dropdownColor: _cardLight,
                    style: const TextStyle(color: _textMain, fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _bgLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _borderLight)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _borderLight)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'زين كاش (ZainCash)', child: Text('زين كاش (ZainCash)')),
                      DropdownMenuItem(value: 'آسيا حوالة (AsiaHawala)', child: Text('آسيا حوالة (AsiaHawala)')),
                      DropdownMenuItem(value: 'نقداً بالمركز (Office Cash)', child: Text('استلام نقدي من مكتب الإدارة')),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedMethod = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // حقل المبلغ
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: _textMain, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'المبلغ المطلوب سحبه (د.ع)',
                      labelStyle: const TextStyle(color: _textSub, fontSize: 12),
                      hintText: 'مثال: 25000',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      filled: true,
                      fillColor: _bgLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _borderLight)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _borderLight)),
                      prefixIcon: const Icon(Icons.money_rounded, color: _primaryLight),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // حقل رقم المحفظة / الحساب
                  if (selectedMethod != 'نقداً بالمركز (Office Cash)')
                    TextField(
                      controller: accountController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: _textMain, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'رقم محفظة التحويل',
                        labelStyle: const TextStyle(color: _textSub, fontSize: 12),
                        filled: true,
                        fillColor: _bgLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _borderLight)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _borderLight)),
                        prefixIcon: const Icon(Icons.phone_iphone_rounded, color: _primaryLight),
                      ),
                    ),

                  const SizedBox(height: 22),

                  // زر التأكيد والإرسال
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final double reqAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
                              if (reqAmount < 5000) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('الحد الأدنى لطلب السحب هو 5,000 د.ع')),
                                );
                                return;
                              }
                              if (reqAmount > currentBalance) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('المبلغ المطلوب أكبر من رصيدك المتاح حالياً!')),
                                );
                                return;
                              }

                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(ctx);

                              setSheetState(() => isSubmitting = true);

                              try {
                                await FirebaseFirestore.instance.collection('withdrawal_requests').add({
                                  'userId': _uid,
                                  'driverId': _uid,
                                  'driverName': delegateName,
                                  'phone': delegatePhone,
                                  'role': 'delivery',
                                  'amount': reqAmount,
                                  'method': selectedMethod,
                                  'accountNumber': accountController.text.trim(),
                                  'status': 'pending',
                                  'createdAt': FieldValue.serverTimestamp(),
                                });

                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('عاشت إيدك! تم إرسال طلب السحب للإدارة وراح يتم التحويل بأقرب وقت'),
                                    backgroundColor: Color(0xFF2E7D32),
                                  ),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('حدث خطأ أثناء إرسال الطلب: $e')),
                                );
                              } finally {
                                if (ctx.mounted) setSheetState(() => isSubmitting = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryLight,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text(
                              'تأكيد وإرسال الطلب',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
