import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:dalal_alqaim/shared/app_colors.dart';

class RestaurantAnalyticsPage extends StatefulWidget {
  const RestaurantAnalyticsPage({super.key});

  @override
  State<RestaurantAnalyticsPage> createState() => _RestaurantAnalyticsPageState();
}

class _RestaurantAnalyticsPageState extends State<RestaurantAnalyticsPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _restaurantId;
  bool _isAdmin = false;
  String? _selectedRestaurantId;
  String? _selectedRestaurantName;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _restaurantId = _uid;
    _fetchRestaurantIdAndRole();
  }

  Future<void> _fetchRestaurantIdAndRole() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        final role = data?['role'] ?? 'user';
        setState(() {
          _isAdmin = (role == 'admin' || role == 'main_admin');
          _restaurantId = data?['restaurantId'] ?? data?['uid'] ?? _uid;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? darkBackground : backgroundColor;
    final txt = isDark ? darkText : textColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? darkSurface : primaryColor,
          elevation: 0,
          leading: (_isAdmin && _selectedRestaurantId != null)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _selectedRestaurantId = null;
                      _selectedRestaurantName = null;
                    });
                  },
                )
              : const BackButton(),
          title: Text(
            _selectedRestaurantName != null
                ? 'إحصائيات: $_selectedRestaurantName'
                : 'تحليلات ومبيعات المطاعم',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: _isAdmin && _selectedRestaurantId == null
            ? _buildAdminMasterView(isDark)
            : _buildRestaurantDetailView(_selectedRestaurantId ?? _restaurantId ?? _uid, isDark),
      ),
    );
  }

  // ══════════ واجهة الأدمن الشاملة لجميع المطاعم ══════════
  Widget _buildAdminMasterView(bool isDark) {
    final card = isDark ? darkCard : cardColor;
    final txt = isDark ? darkText : textColor;
    final sub = isDark ? darkSubText : subTextColor;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, ordersSnapshot) {
        if (ordersSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final allOrders = ordersSnapshot.data?.docs ?? [];
        
        // حساب إجمالي مبيعات وطلبات كل مطعم في الذاكرة
        final Map<String, double> salesMap = {};
        final Map<String, int> ordersMap = {};
        double totalGlobalSales = 0.0;
        int totalGlobalOrders = 0;

        for (var doc in allOrders) {
          final data = doc.data() as Map<String, dynamic>;
          final restId = data['restaurantId']?.toString() ?? '';
          if (restId.isEmpty) continue;

          final price = ((data['total'] ?? data['totalPrice'] ?? data['grandTotal']) as num?)?.toDouble() ?? 0.0;
          final status = data['status'] ?? 'pending';

          // زيادة عدد الطلبات الكلي للمطعم
          ordersMap[restId] = (ordersMap[restId] ?? 0) + 1;
          totalGlobalOrders++;

          // إضافة المبيعات فقط للطلبات المكتملة
          if (status == 'completed') {
            salesMap[restId] = (salesMap[restId] ?? 0.0) + price;
            totalGlobalSales += price;
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
          builder: (context, restSnapshot) {
            if (restSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryColor));
            }

            final restaurants = restSnapshot.data?.docs ?? [];
            final filteredRestaurants = restaurants.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString().toLowerCase();
              return _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
            }).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // لافتة الإحصائيات العامة الكبرى للمنصة
                  Row(
                    children: [
                      _buildStatCard(
                        'مبيعات المنصة الكلية',
                        '${totalGlobalSales.toStringAsFixed(0)} د.ع',
                        Icons.monetization_on_rounded,
                        Colors.green,
                        isDark,
                        card,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'إجمالي الطلبات',
                        totalGlobalOrders.toString(),
                        Icons.shopping_bag_rounded,
                        Colors.blue,
                        isDark,
                        card,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // شريط البحث المطور
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: primaryColor),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      hintText: 'البحث عن مطعم...',
                      hintStyle: TextStyle(color: sub.withValues(alpha: 0.6), fontSize: 13),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF14243B) : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    style: TextStyle(color: txt, fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'قائمة أداء المطاعم ومبيعاتها (${filteredRestaurants.length})',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: txt),
                  ),
                  const SizedBox(height: 12),

                  if (filteredRestaurants.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'ماكو مطاعم حالياً مطابقة للبحث',
                          style: TextStyle(color: sub.withValues(alpha: 0.5)),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredRestaurants.length,
                      itemBuilder: (context, index) {
                        final doc = filteredRestaurants[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final rid = doc.id;
                        final rname = data['name'] ?? 'مطعم بدون اسم';
                        final logo = data['imageUrl'] ?? '';
                        final sales = salesMap[rid] ?? 0.0;
                        final orders = ordersMap[rid] ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFFB8C00)]),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundImage: logo.isNotEmpty ? NetworkImage(logo) : null,
                                backgroundColor: isDark ? const Color(0xFF0F2027) : Colors.white,
                                child: logo.isEmpty ? const Icon(Icons.store, color: Color(0xFFFFA726), size: 24) : null,
                              ),
                            ),
                            title: Text(
                              rname,
                              style: TextStyle(fontWeight: FontWeight.bold, color: txt, fontSize: 14),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'مبيعات: ${sales.toStringAsFixed(0)} د.ع',
                                      style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'الطلبات: $orders',
                                      style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_forward_ios_rounded, color: primaryColor, size: 14),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedRestaurantId = rid;
                                _selectedRestaurantName = rname;
                              });
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ══════════ واجهة تفاصيل الأداء لمطعم محدد ══════════
  Widget _buildRestaurantDetailView(String restaurantId, bool isDark) {
    final card = isDark ? darkCard : cardColor;
    final txt = isDark ? darkText : textColor;
    final sub = isDark ? darkSubText : subTextColor;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: restaurantId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final orders = snapshot.data?.docs ?? [];
        double totalRevenue = 0;
        int completedCount = 0;
        int pendingCount = 0;
        int preparingCount = 0;

        for (var doc in orders) {
          final data = doc.data() as Map<String, dynamic>;
          final price = ((data['total'] ?? data['totalPrice'] ?? data['grandTotal']) as num?)?.toDouble() ?? 0.0;
          final status = data['status'] ?? 'pending';

          if (status == 'completed') {
            completedCount++;
            totalRevenue += price;
          } else if (status == 'pending') {
            pendingCount++;
          } else if (status == 'preparing' || status == 'accepted' || status == 'approved') {
            preparingCount++;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // زر العودة لقائمة الأدمن (إذا كان المستخدم أدمن)
              if (_isAdmin) ...[
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedRestaurantId = null;
                      _selectedRestaurantName = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 18, color: primaryColor),
                  label: const Text(
                    'العودة لقائمة جميع المطاعم',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Text(
                'ملخص الأداء المالي والعمليات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: txt),
              ),
              const SizedBox(height: 16),

              // شبكة الإحصائيات الثنائية للمطعم المحدد
              Row(
                children: [
                  _buildStatCard('إجمالي المبيعات', '${totalRevenue.toStringAsFixed(0)} د.ع', Icons.monetization_on_rounded, Colors.green, isDark, card),
                  const SizedBox(width: 12),
                  _buildStatCard('الطلبات المكتملة', completedCount.toString(), Icons.done_all_rounded, Colors.blue, isDark, card),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatCard('قيد التحضير', preparingCount.toString(), Icons.restaurant_rounded, Colors.orange, isDark, card),
                  const SizedBox(width: 12),
                  _buildStatCard('قيد الانتظار', pendingCount.toString(), Icons.hourglass_empty_rounded, Colors.purple, isDark, card),
                ],
              ),

              const SizedBox(height: 28),
              Text(
                'سجل العمليات والطلبات الأخيرة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: txt),
              ),
              const SizedBox(height: 12),

              if (orders.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'ماكو عمليات حالياً بيع مسجلة بعد لهذا المطعم',
                      style: TextStyle(color: sub.withValues(alpha: 0.5)),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.length > 15 ? 15 : orders.length,
                  itemBuilder: (context, index) {
                    final doc = orders[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final buyerName = data['customerName'] ?? data['buyerName'] ?? 'زبون مدار';
                    final price = data['total'] ?? data['totalPrice'] ?? data['grandTotal'] ?? 0;
                    final status = data['status'] ?? 'pending';
                    final timestamp = data['createdAt'] as Timestamp?;
                    final dateStr = timestamp != null
                        ? DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate())
                        : '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                buyerName,
                                style: TextStyle(fontWeight: FontWeight.bold, color: txt, fontSize: 13),
                              ),
                              Text(
                                dateStr,
                                style: TextStyle(color: sub.withValues(alpha: 0.5), fontSize: 10),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$price د.ع',
                                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  color: _statusColor(status),
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
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark, Color card) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? darkText : textColor),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: isDark ? darkSubText : subTextColor),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'preparing':
      case 'accepted':
      case 'approved':
        return Colors.orange;
      case 'pending':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'مكتمل';
      case 'preparing':
        return 'قيد التحضير';
      case 'accepted':
      case 'approved':
        return 'مقبول';
      case 'pending':
        return 'قيد الانتظار';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }
}
