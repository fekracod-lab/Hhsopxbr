import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dalal_alqaim/features/complaints/widgets/complaint_details_sheet.dart';
import 'package:dalal_alqaim/shared/app_colors.dart';

class ComplaintsManagementPage extends StatelessWidget {
  const ComplaintsManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? darkBackground : const Color(0xFFF5F7FA);
    final txt = isDark ? darkText : const Color(0xFF333333);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? darkSurface : Colors.white,
          elevation: 0,
          title: Text(
            'لوحة تحكم الشكاوى والاقتراحات',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: txt,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: Icon(Icons.arrow_back, color: txt),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          actions: [
            IconButton(
              icon: Icon(Icons.logout, color: txt),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              tooltip: 'تسجيل الخروج',
            ),
          ],
        ),
        body: const ComplaintsDashboardView(),
      ),
    );
  }
}

class ComplaintsDashboardView extends StatefulWidget {
  const ComplaintsDashboardView({super.key});

  @override
  State<ComplaintsDashboardView> createState() => _ComplaintsDashboardViewState();
}

class _ComplaintsDashboardViewState extends State<ComplaintsDashboardView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedType = 'all'; // all, complaint, suggestion
  String _selectedStatus = 'all'; // all, pending, in_progress, resolved, rejected

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة';
      case 'in_progress':
        return 'قيد المعالجة';
      case 'resolved':
        return 'تم الحل';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? darkCard : Colors.white;
    final txt = isDark ? darkText : const Color(0xFF333333);
    final searchBg = isDark ? darkSurface : const Color(0xFFECEFF1);

    return Column(
      children: [
        // ── Stats Summary Row ──
        Container(
          padding: const EdgeInsets.all(16),
          color: isDark ? darkSurface : Colors.white,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('complaints').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
              }
              final docs = snapshot.data?.docs ?? [];
              final total = docs.length;
              final pending = docs.where((d) => d['status'] == 'pending').length;
              final inProgress = docs.where((d) => d['status'] == 'in_progress').length;
              final resolved = docs.where((d) => d['status'] == 'resolved').length;
              final rejected = docs.where((d) => d['status'] == 'rejected').length;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildStatCard('الكل', total, Colors.purple, isDark),
                    const SizedBox(width: 8),
                    _buildStatCard('معلق', pending, Colors.orange, isDark),
                    const SizedBox(width: 8),
                    _buildStatCard('قيد الحل', inProgress, Colors.blue, isDark),
                    const SizedBox(width: 8),
                    _buildStatCard('تم الحل', resolved, Colors.green, isDark),
                    const SizedBox(width: 8),
                    _buildStatCard('مرفوض', rejected, Colors.red, isDark),
                  ],
                ),
              );
            },
          ),
        ),

        // ── Filters & Search ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? darkSurface : Colors.white,
          child: Column(
            children: [
              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: searchBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: txt, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'البحث في الشكاوى...',
                    hintStyle: TextStyle(color: isDark ? darkHint : Colors.grey, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: primaryColor),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    // Type Filter
                    _buildFilterChip('الكل', 'all', _selectedType, (v) => setState(() => _selectedType = v), isDark),
                    const SizedBox(width: 6),
                    _buildFilterChip('شكاوى', 'complaint', _selectedType, (v) => setState(() => _selectedType = v), isDark),
                    const SizedBox(width: 6),
                    _buildFilterChip('اقتراحات', 'suggestion', _selectedType, (v) => setState(() => _selectedType = v), isDark),

                    Container(
                      height: 20,
                      width: 1,
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                    ),

                    // Status Filter
                    _buildFilterChip('كل الحالات', 'all', _selectedStatus, (v) => setState(() => _selectedStatus = v), isDark),
                    const SizedBox(width: 6),
                    _buildFilterChip('معلق', 'pending', _selectedStatus, (v) => setState(() => _selectedStatus = v), isDark),
                    const SizedBox(width: 6),
                    _buildFilterChip('قيد الحل', 'in_progress', _selectedStatus, (v) => setState(() => _selectedStatus = v), isDark),
                    const SizedBox(width: 6),
                    _buildFilterChip('تم الحل', 'resolved', _selectedStatus, (v) => setState(() => _selectedStatus = v), isDark),
                    const SizedBox(width: 6),
                    _buildFilterChip('مرفوض', 'rejected', _selectedStatus, (v) => setState(() => _selectedStatus = v), isDark),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Complaints List ──
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('complaints').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: primaryColor));
              }

              final allDocs = snapshot.data?.docs ?? [];
              final filtered = allDocs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                
                // Type Filter
                if (_selectedType != 'all' && data['type'] != _selectedType) return false;

                // Status Filter
                if (_selectedStatus != 'all' && data['status'] != _selectedStatus) return false;

                // Search query
                if (_searchQuery.isNotEmpty) {
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final desc = (data['description'] ?? '').toString().toLowerCase();
                  final userEmail = (data['userEmail'] ?? '').toString().toLowerCase();
                  if (!title.contains(_searchQuery.toLowerCase()) &&
                      !desc.contains(_searchQuery.toLowerCase()) &&
                      !userEmail.contains(_searchQuery.toLowerCase())) {
                    return false;
                  }
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: isDark ? darkHint : Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        'لا توجد شكاوى أو اقتراحات مطابقة',
                        style: TextStyle(color: isDark ? darkSubText : Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final doc = filtered[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final id = doc.id;

                  final isComplaint = data['type'] == 'complaint';
                  final status = data['status'] ?? 'pending';
                  final title = data['title'] ?? 'بدون عنوان';
                  final desc = data['description'] ?? '';
                  final userEmail = data['userEmail'] ?? 'بدون ايميل';
                  final userId = data['userId'];
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => ComplaintDetailsSheet(
                            data: data,
                            docId: id,
                            isDark: isDark,
                            isAdmin: true,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isComplaint ? Colors.red : Colors.amber).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isComplaint ? Icons.campaign_rounded : Icons.lightbulb_rounded,
                                    color: isComplaint ? Colors.red : Colors.amber[700],
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: txt,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        userEmail,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? darkSubText : Colors.grey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    _getStatusText(status),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(status),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  tooltip: 'حذف الشكوى',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: cardBg,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: const Text('حذف البلاغ؟', style: TextStyle(fontWeight: FontWeight.bold)),
                                        content: const Text('متأكد تريد تحذف هذا البلاغ نهائياً؟', style: TextStyle()),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('إلغاء', style: TextStyle()),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                            child: const Text('حذف', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await FirebaseFirestore.instance.collection('complaints').doc(id).delete();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('تم حذف البلاغ بنجاح', style: TextStyle()), backgroundColor: Color(0xFF10B981)),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              desc,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? darkSubText : const Color(0xFF666666),
                                height: 1.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                            // Complainant Name Fetch snippet
                            if (userId != null) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                                builder: (context, uSnap) {
                                  if (!uSnap.hasData) return const SizedBox.shrink();
                                  final uData = uSnap.data?.data() as Map<String, dynamic>?;
                                  final name = uData?['username'] ?? uData?['name'] ?? '';
                                  final phone = uData?['phone'] ?? '';
                                  if (name.isEmpty && phone.isEmpty) return const SizedBox.shrink();

                                  return Row(
                                    children: [
                                      Icon(Icons.person_outline, size: 14, color: isDark ? darkSubText : Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        'المشتكي: $name ${phone.isNotEmpty ? "($phone)" : ""}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? darkSubText : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int count, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? darkCard : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? darkText : const Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String selectedValue,
    Function(String) onSelected,
    bool isDark,
  ) {
    final isSelected = value == selectedValue;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (v) => onSelected(value),
      selectedColor: primaryColor.withValues(alpha: 0.2),
      backgroundColor: isDark ? darkCard : const Color(0xFFF5F7FA),
      labelStyle: TextStyle(
        color: isSelected ? primaryColor : (isDark ? darkSubText : const Color(0xFF666666)),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? primaryColor.withValues(alpha: 0.5) : Colors.transparent),
      ),
    );
  }
}
