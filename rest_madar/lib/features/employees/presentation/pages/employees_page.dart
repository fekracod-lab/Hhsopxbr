import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/responsive/madar_responsive.dart';
import 'package:rest_madar/core/theme/app_theme.dart';

/// نموذج موظف في نظام مطاعم مدار
class EmployeeItem {
  final String id;
  final String name;
  final String phone;
  final String role; // 'manager', 'cashier', 'chef', 'waiter', 'delivery'
  final String pin;
  final double salary;
  final bool isActive;
  final DateTime hireDate;
  final String? notes;

  EmployeeItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.pin,
    required this.salary,
    required this.isActive,
    required this.hireDate,
    this.notes,
  });

  factory EmployeeItem.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return EmployeeItem(
      id: id,
      name: map['name']?.toString() ?? 'موظف غير معرف',
      phone: map['phone']?.toString() ?? '',
      role: map['role']?.toString() ?? 'cashier',
      pin: map['pin']?.toString() ?? '1234',
      salary: (map['salary'] as num?)?.toDouble() ?? 0.0,
      isActive: map['isActive'] as bool? ?? true,
      hireDate: parseDate(map['hireDate'] ?? map['createdAt']),
      notes: map['notes']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'role': role,
      'pin': pin,
      'salary': salary,
      'isActive': isActive,
      'hireDate': Timestamp.fromDate(hireDate),
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  EmployeeItem copyWith({
    String? name,
    String? phone,
    String? role,
    String? pin,
    double? salary,
    bool? isActive,
    DateTime? hireDate,
    String? notes,
  }) {
    return EmployeeItem(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      pin: pin ?? this.pin,
      salary: salary ?? this.salary,
      isActive: isActive ?? this.isActive,
      hireDate: hireDate ?? this.hireDate,
      notes: notes ?? this.notes,
    );
  }
}

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _activeId = '';
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedRoleFilter = 'all';

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

  CollectionReference _employeesRef() {
    final id = _activeId.isNotEmpty ? _activeId : _uid;
    return FirebaseFirestore.instance
        .collection('merchant_employees')
        .doc(id)
        .collection('employees');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'manager':
        return 'مدير النظام';
      case 'cashier':
        return 'كاشير ومحاسب';
      case 'chef':
        return 'شيف ومطبخ';
      case 'waiter':
        return 'مباشر صالة';
      case 'delivery':
        return 'مندوب توصيل';
      default:
        return 'موظف';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'manager':
        return const Color(0xFF8B5CF6);
      case 'cashier':
        return const Color(0xFF10B981);
      case 'chef':
        return const Color(0xFFFF5B22);
      case 'waiter':
        return const Color(0xFF0EA5E9);
      case 'delivery':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'manager':
        return Icons.admin_panel_settings_rounded;
      case 'cashier':
        return Icons.point_of_sale_rounded;
      case 'chef':
        return Icons.soup_kitchen_rounded;
      case 'waiter':
        return Icons.room_service_rounded;
      case 'delivery':
        return Icons.two_wheeler_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.background,
        body: StreamBuilder<QuerySnapshot>(
          stream: (_activeId.isEmpty && _uid.isEmpty) ? null : _employeesRef().snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<EmployeeItem> employees = [];

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              for (final doc in snapshot.data!.docs) {
                employees.add(EmployeeItem.fromMap(doc.id, doc.data() as Map<String, dynamic>));
              }
            }

            final searchQuery = _searchCtrl.text.trim().toLowerCase();
            final filtered = employees.where((emp) {
              final matchSearch = searchQuery.isEmpty ||
                  emp.name.toLowerCase().contains(searchQuery) ||
                  emp.phone.contains(searchQuery);
              final matchRole = _selectedRoleFilter == 'all' || emp.role == _selectedRoleFilter;
              return matchSearch && matchRole;
            }).toList();

            final totalCount = employees.length;
            final activeCount = employees.where((e) => e.isActive).length;
            final managersCount = employees.where((e) => e.role == 'manager' || e.role == 'cashier').length;
            final floorCount = employees.where((e) => e.role == 'chef' || e.role == 'waiter').length;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // رأس الصفحة
                  _buildHeader(context, c),
                  const SizedBox(height: 20),

                  // إحصائيات سريعة
                  _buildStatCards(
                    c,
                    totalCount: totalCount,
                    activeCount: activeCount,
                    managersCount: managersCount,
                    floorCount: floorCount,
                  ),
                  const SizedBox(height: 20),

                  // شريط البحث والفلترة
                  _buildToolbar(c),
                  const SizedBox(height: 16),

                  // قائمة الموظفين
                  Expanded(
                    child: filtered.isEmpty
                        ? _buildEmptyState(c, isSearch: employees.isNotEmpty)
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _buildEmployeeCard(context, c, filtered[index]);
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

  Widget _buildHeader(BuildContext context, PosColors c) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.badge_rounded, color: c.primary, size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إدارة الموظفين والورديات',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
            Text(
              'تسجيل الموظفين، الأدوار، رموز الدخول (PIN)، وصلاحيات الكاشير والمدير',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 12.5,
                color: c.textMuted,
              ),
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () => _showAddEditDialog(context),
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: Text(
            'إضافة موظف جديد',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(
    PosColors c, {
    required int totalCount,
    required int activeCount,
    required int managersCount,
    required int floorCount,
  }) {
    return Row(
      children: [
        _buildStatCard(
          c,
          title: 'إجمالي الكادر',
          value: '$totalCount موظف',
          icon: Icons.groups_rounded,
          color: const Color(0xFF6366F1),
        ),
        const SizedBox(width: 14),
        _buildStatCard(
          c,
          title: 'الموظفين على رأس العمل',
          value: '$activeCount نشط',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF10B981),
        ),
        const SizedBox(width: 14),
        _buildStatCard(
          c,
          title: 'المدراء والكاشيرات',
          value: '$managersCount موظف',
          icon: Icons.admin_panel_settings_rounded,
          color: const Color(0xFF8B5CF6),
        ),
        const SizedBox(width: 14),
        _buildStatCard(
          c,
          title: 'طاقم المطبخ والصالة',
          value: '$floorCount موظف',
          icon: Icons.soup_kitchen_rounded,
          color: const Color(0xFFFF5B22),
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

  Widget _buildToolbar(PosColors c) {
    final roles = [
      {'id': 'all', 'label': 'جميع الموظفين'},
      {'id': 'manager', 'label': 'المدراء'},
      {'id': 'cashier', 'label': 'الكاشيرات'},
      {'id': 'chef', 'label': 'الشيفات والمطبخ'},
      {'id': 'waiter', 'label': 'مباشرين الصالة'},
      {'id': 'delivery', 'label': 'مناديب التوصيل'},
    ];

    return Row(
      children: [
        // حقل البحث
        Expanded(
          flex: 2,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'البحث بالاسم أو رقم الهاتف...',
                hintStyle: GoogleFonts.ibmPlexSansArabic(
                  color: c.textMuted,
                  fontSize: 12.5,
                ),
                prefixIcon: Icon(Icons.search_rounded, color: c.textMuted, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // تصفية حسب الدور
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: roles.map((r) {
                final isSelected = _selectedRoleFilter == r['id'];
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(
                      r['label']!,
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
                        setState(() => _selectedRoleFilter = r['id']!);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeCard(BuildContext context, PosColors c, EmployeeItem emp) {
    final roleColor = _getRoleColor(emp.role);
    final roleIcon = _getRoleIcon(emp.role);
    final roleName = _getRoleName(emp.role);
    final currencyFmt = NumberFormat('#,###', 'en_US');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emp.isActive ? c.border : c.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // أيقونة الدور / الصورة
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(roleIcon, color: roleColor, size: 24),
          ),
          const SizedBox(width: 16),

          // تفاصيل الموظف
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      emp.name,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: emp.isActive ? c.textPrimary : c.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        roleName,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: roleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (!emp.isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'غير نشط / إجازة',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone_rounded, size: 14, color: c.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      emp.phone.isEmpty ? 'بدون هاتف' : emp.phone,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        color: c.textMuted,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today_rounded, size: 13, color: c.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'تاريخ التعيين: ${DateFormat('yyyy/MM/dd').format(emp.hireDate)}',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        color: c.textMuted,
                      ),
                    ),
                    if (emp.notes != null && emp.notes!.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.notes_rounded, size: 13, color: c.textMuted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          emp.notes!,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5,
                            color: c.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // الراتب والـ PIN
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${currencyFmt.format(emp.salary)} د.ع',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 12, color: c.primary),
                  const SizedBox(width: 3),
                  Text(
                    'رمز الدخول: ${emp.pin}',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: c.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 20),

          // التبديل بين نشط وغير نشط
          Switch(
            value: emp.isActive,
            activeThumbColor: const Color(0xFF10B981),
            onChanged: (val) => _toggleEmployeeStatus(emp, val),
          ),
          const SizedBox(width: 8),

          // أزرار التحكم
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: c.textMuted),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: c.surface,
            onSelected: (action) {
              if (action == 'edit') {
                _showAddEditDialog(context, existing: emp);
              } else if (action == 'delete') {
                _confirmDeleteEmployee(context, emp);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 18, color: c.primary),
                    const SizedBox(width: 8),
                    Text(
                      'تعديل الموظف',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Text(
                      'حذف الموظف',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(PosColors c, {bool isSearch = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.badge_outlined, size: 56, color: c.primary),
          ),
          const SizedBox(height: 16),
          Text(
            isSearch ? 'لا يوجد موظفون يطابقون شروط البحث' : 'لا يوجد موظفون مسجلون حالياً',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearch
                ? 'جرب البحث باسم آخر أو تغيير فلتر الدور الوظيفي'
                : 'قم بإضافة موظفي المطعم وتحديد أدوارهم وصلاحياتهم وأكواد PIN للدخول',
            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.textMuted),
          ),
          if (!isSearch) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(context),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: Text('إضافة أول موظف', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleEmployeeStatus(EmployeeItem emp, bool newStatus) async {
    if (_activeId.isEmpty) return;

    try {
      await _employeesRef()
          .doc(emp.id)
          .update({'isActive': newStatus});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحديث الحالة: $e')),
        );
      }
    }
  }

  void _showAddEditDialog(BuildContext context, {EmployeeItem? existing}) {
    final c = context.posColors;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final pinCtrl = TextEditingController(text: existing?.pin ?? '1234');
    final salaryCtrl = TextEditingController(
      text: existing != null ? existing.salary.toStringAsFixed(0) : '750000',
    );
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String selectedRole = existing?.role ?? 'cashier';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      existing == null ? Icons.person_add_rounded : Icons.edit_rounded,
                      color: c.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    existing == null ? 'إضافة موظف جديد' : 'تعديل بيانات الموظف',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: MadarResponsive.dialogWidth(context, maxWidth: 460),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الاسم
                      _buildTextField(c, label: 'اسم الموظف الكامل', controller: nameCtrl, icon: Icons.person_outline),
                      const SizedBox(height: 12),

                      // الهاتف
                      _buildTextField(
                        c,
                        label: 'رقم الهاتف',
                        controller: phoneCtrl,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),

                      // الدور الوظيفي
                      Text(
                        'الدور الوظيفي والصلاحية',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: c.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedRole,
                            isExpanded: true,
                            dropdownColor: c.surface,
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedRole = val);
                              }
                            },
                            items: [
                              DropdownMenuItem(
                                value: 'manager',
                                child: Text('مدير النظام (كامل الصلاحيات)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
                              ),
                              DropdownMenuItem(
                                value: 'cashier',
                                child: Text('كاشير ومحاسب (نقاط البيع والفواتير)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
                              ),
                              DropdownMenuItem(
                                value: 'chef',
                                child: Text('شيف مطبخ (شاشة KDS فقط)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
                              ),
                              DropdownMenuItem(
                                value: 'waiter',
                                child: Text('مباشر صالة (طاولات وطلبات)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
                              ),
                              DropdownMenuItem(
                                value: 'delivery',
                                child: Text('مندوب توصيل (شحنات وتوصيل مدار)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          // رمز الدخول PIN
                          Expanded(
                            child: _buildTextField(
                              c,
                              label: 'رمز الدخول (PIN 4 أرقام)',
                              controller: pinCtrl,
                              icon: Icons.lock_outline_rounded,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // الراتب الشهري
                          Expanded(
                            child: _buildTextField(
                              c,
                              label: 'الراتب الشهري (د.ع)',
                              controller: salaryCtrl,
                              icon: Icons.attach_money_rounded,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ملاحظات
                      _buildTextField(
                        c,
                        label: 'ملاحظات إضافية أو الشفت',
                        controller: notesCtrl,
                        icon: Icons.notes_rounded,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    'إلغاء',
                    style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;

                    final salary = double.tryParse(salaryCtrl.text.trim()) ?? 0.0;
                    final pin = pinCtrl.text.trim().isEmpty ? '1234' : pinCtrl.text.trim();

                    Navigator.pop(dialogCtx);

                    if (_activeId.isEmpty) return;

                    try {
                      final col = _employeesRef();

                      if (existing != null) {
                        await col.doc(existing.id).update({
                          'name': name,
                          'phone': phoneCtrl.text.trim(),
                          'role': selectedRole,
                          'pin': pin,
                          'salary': salary,
                          'notes': notesCtrl.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                      } else {
                        await col.add({
                          'restaurantId': _activeId,
                          'name': name,
                          'phone': phoneCtrl.text.trim(),
                          'role': selectedRole,
                          'pin': pin,
                          'salary': salary,
                          'isActive': true,
                          'hireDate': FieldValue.serverTimestamp(),
                          'notes': notesCtrl.text.trim(),
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(existing == null ? 'تمت إضافة الموظف بنجاح' : 'تم تحديث الموظف بنجاح'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('حدث خطأ: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    existing == null ? 'إضافة' : 'حفظ التعديلات',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField(
    PosColors c, {
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: c.primary, size: 20),
            filled: true,
            fillColor: c.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteEmployee(BuildContext context, EmployeeItem emp) {
    final c = context.posColors;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'تأكيد حذف الموظف',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
          ),
          content: SizedBox(
            width: MadarResponsive.dialogWidth(context, maxWidth: 400),
            child: Text(
              'هل أنت متأكد من حذف الموظف "${emp.name}"؟ لن يتمكن من تسجيل الدخول للنظام بعد الحذف.',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: c.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (_activeId.isEmpty) return;
                try {
                  await _employeesRef()
                      .doc(emp.id)
                      .delete();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ أثناء الحذف: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: Text(
                'حذف الموظف',
                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
