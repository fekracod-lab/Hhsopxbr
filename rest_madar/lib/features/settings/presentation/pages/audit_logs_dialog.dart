import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/responsive/madar_responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/audit_log_service.dart';

/// نافذة وشاشة عرض سجل التدقيق التجاري والعمليات الحساسة
class AuditLogsDialog extends StatefulWidget {
  const AuditLogsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const AuditLogsDialog(),
    );
  }

  @override
  State<AuditLogsDialog> createState() => _AuditLogsDialogState();
}

class _AuditLogsDialogState extends State<AuditLogsDialog> {
  bool _isLoading = true;
  bool _isSyncing = false;
  String _selectedFilter = 'all';
  String _searchQuery = '';

  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final localLogs = await AuditLogService.instance.getLocalLogs(limit: 100);

      // إذا كانت السجلات المحلية فارغة، نحاول قراءة نسخة السحابة
      if (localLogs.isEmpty) {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        if (uid.isNotEmpty) {
          final snap = await FirebaseFirestore.instance
              .collection('merchant_audit_logs')
              .doc(uid)
              .collection('logs')
              .orderBy('timestamp', descending: true)
              .limit(100)
              .get();

          _logs = snap.docs.map((d) {
            final data = d.data();
            return {
              'log_id': d.id,
              'user_name': data['userName'] ?? 'الكاشير',
              'action': data['action'] ?? '',
              'reason': data['reason'] ?? '',
              'manager_pin_verified': data['managerPinVerified'] == true ? 1 : 0,
              'timestamp': (data['timestamp'] as Timestamp?)?.toDate().toIso8601String() ?? '',
              'target_id': data['targetId'] ?? '',
              'terminal_id': data['terminalId'] ?? 'terminal_main',
            };
          }).toList();
        }
      } else {
        _logs = localLogs;
      }
    } catch (e) {
      debugPrint('[AuditLogsDialog] Error loading logs: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerCloudSync() async {
    setState(() => _isSyncing = true);
    try {
      final syncedCount = await AuditLogService.instance.syncPendingLogsToCloud();
      await _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncedCount > 0
                  ? 'تمت مزامنة $syncedCount حركة تدقيق مع السحابة بنجاح!'
                  : 'كافة الحركات متزامنة مع السحابة مسبقاً ✅',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
            ),
            backgroundColor: context.posColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء المزامنة: $e'),
            backgroundColor: context.posColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    return _logs.where((l) {
      final action = (l['action'] ?? '').toString();
      final userName = (l['user_name'] ?? '').toString();
      final reason = (l['reason'] ?? '').toString();
      final targetId = (l['target_id'] ?? '').toString();

      bool matchFilter = true;
      if (_selectedFilter == 'delete') {
        matchFilter = action.contains('delete') || action.contains('cancel');
      } else if (_selectedFilter == 'price') {
        matchFilter = action.contains('price') || action.contains('discount');
      } else if (_selectedFilter == 'drawer') {
        matchFilter = action.contains('drawer');
      } else if (_selectedFilter == 'shift') {
        matchFilter = action.contains('shift');
      }

      final query = _searchQuery.toLowerCase();
      final matchQuery = query.isEmpty ||
          userName.toLowerCase().contains(query) ||
          reason.toLowerCase().contains(query) ||
          targetId.toLowerCase().contains(query) ||
          AuditLogService.actionToArabic(action).toLowerCase().contains(query);

      return matchFilter && matchQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;
    final filtered = _filteredLogs;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.border),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: SizedBox(
          width: MadarResponsive.dialogWidth(context, maxWidth: 820),
          height: (MediaQuery.sizeOf(context).height * 0.85).clamp(400.0, 640.0),
          child: Column(
            children: [
              // 1. رأس النافذة
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.security_rounded, color: Color(0xFFD97706), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'سجل التدقيق التجاري والعمليات الحساسة (Audit Log)',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'توثيق دقيق لكافة عمليات الحذف وتعديل الأسعار وفتح الدرج مع بيانات المسؤول والسبب',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isSyncing ? null : _triggerCloudSync,
                      icon: _isSyncing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cloud_upload_outlined, size: 16),
                      label: Text(
                        _isSyncing ? 'جاري المزامنة...' : 'مزامنة السحابة',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.primary,
                        side: BorderSide(color: c.primary.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: c.textMuted),
                    ),
                  ],
                ),
              ),

              // 2. شريط البحث والتصفية
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  children: [
                    // حقل البحث
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v.trim()),
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'بحث باسم المستخدم أو السبب أو رقم الطلب...',
                            hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                            prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.textMuted),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: c.background,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // فلاتر سريعة
                    _buildFilterChip('الكل', 'all', c),
                    const SizedBox(width: 6),
                    _buildFilterChip('حذف وإلغاء', 'delete', c),
                    const SizedBox(width: 6),
                    _buildFilterChip('أسعار وخصومات', 'price', c),
                    const SizedBox(width: 6),
                    _buildFilterChip('درج النقود', 'drawer', c),
                    const SizedBox(width: 6),
                    _buildFilterChip('الورديات', 'shift', c),
                  ],
                ),
              ),

              // 3. قائمة الحركات
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user_outlined, size: 48, color: c.textDisabled),
                                const SizedBox(height: 12),
                                Text(
                                  'لا توجد حركات حساسة مسجلة حالياً',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'أي عمليات حذف أو خصم أو فتح درج نقود ستظهر هنا فورياً',
                                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final log = filtered[index];
                              return _buildLogCard(c, log);
                            },
                          ),
              ),

              // 4. تذييل النافذة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    Text(
                      'إجمالي الحركات المعروضة: ${filtered.length} من أصل ${_logs.length}',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      ),
                      child: Text('إغلاق', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, PosColors c) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? c.primary : c.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? c.primary : c.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : c.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildLogCard(PosColors c, Map<String, dynamic> log) {
    final action = (log['action'] ?? '').toString();
    final actionArabic = AuditLogService.actionToArabic(action);
    final userName = (log['user_name'] ?? 'الكاشير').toString();
    final reason = (log['reason'] ?? '').toString();
    final pinVerified = log['manager_pin_verified'] == 1 || log['manager_pin_verified'] == true;
    final targetId = (log['target_id'] ?? '').toString();
    final tsStr = (log['timestamp'] ?? '').toString();

    DateTime? dt;
    if (tsStr.isNotEmpty) {
      dt = DateTime.tryParse(tsStr);
    }
    final formattedTime = dt != null ? DateFormat('yyyy/MM/dd HH:mm').format(dt) : '-';

    // ألوان وأيقونات مخصصة حسب نوع الإجراء
    Color badgeColor = const Color(0xFF3B82F6);
    IconData badgeIcon = Icons.info_outline_rounded;

    if (action.contains('delete') || action.contains('cancel')) {
      badgeColor = const Color(0xFFEF4444);
      badgeIcon = Icons.delete_forever_rounded;
    } else if (action.contains('price')) {
      badgeColor = const Color(0xFFF59E0B);
      badgeIcon = Icons.price_change_outlined;
    } else if (action.contains('drawer')) {
      badgeColor = const Color(0xFF8B5CF6);
      badgeIcon = Icons.point_of_sale_rounded;
    } else if (action.contains('discount')) {
      badgeColor = const Color(0xFF06B6D4);
      badgeIcon = Icons.discount_outlined;
    } else if (action.contains('shift')) {
      badgeColor = const Color(0xFF10B981);
      badgeIcon = Icons.lock_clock_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // أيقونة الإجراء
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(badgeIcon, color: badgeColor, size: 20),
          ),
          const SizedBox(width: 12),

          // التفاصيل
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      actionArabic,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    if (targetId.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: c.border),
                        ),
                        child: Text(
                          'معرّف: $targetId',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: c.textMuted),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      formattedTime,
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // المنفذ والسبب
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 14, color: c.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      userName,
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
                    ),
                    const SizedBox(width: 14),
                    if (reason.isNotEmpty) ...[
                      Icon(Icons.notes_rounded, size: 14, color: c.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'السبب: $reason',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5,
                            color: c.textPrimary,
                            fontWeight: FontWeight.w500,
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
          const SizedBox(width: 10),

          // شارة تصريح رمز المدير
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: pinVerified
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: pinVerified
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pinVerified ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 13,
                  color: pinVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 4),
                Text(
                  pinVerified ? 'رمز المدير ✅' : 'إجراء كاشير',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: pinVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
