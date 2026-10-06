import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/localization/pos_language_controller.dart';
import '../../../../core/responsive/madar_responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/audit_log_service.dart';
import '../../../pos/presentation/widgets/printer_settings_dialog.dart';
import 'audit_logs_dialog.dart';

/// مركز إعدادات نظام مدار المتكامل لسطح المكتب (Madar Enterprise Control Center)
/// واجهة إدارة عصرية مبوبة ومصممة بأعلى معايير أنظمة الـ POS العالمية
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  int _activeTab = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  // 1. هوية وبيانات المطعم
  final TextEditingController _nameCtrl = TextEditingController(text: 'مطعم مدار');
  final TextEditingController _ownerCtrl = TextEditingController(text: 'صاحب المطعم');
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController(text: 'القائم - الأنبار');
  final TextEditingController _descCtrl = TextEditingController();
  String? _logoUrl;

  // 2. التشغيل وساعات العمل
  bool _isOpen = true;
  int _prepTimeMinutes = 20;
  String _surgeStatus = 'normal'; // normal, busy, paused
  String _openTimeStr = '10:00 ص';
  String _closeTimeStr = '01:00 ص';

  // 3. المالية والضرائب
  bool _enableCash = true;
  bool _enableZainCash = true;
  bool _enableQiCard = true;
  bool _enableTax = false;
  final TextEditingController _taxRateCtrl = TextEditingController(text: '0');
  final TextEditingController _serviceFeeCtrl = TextEditingController(text: '0');

  // 4. المطبخ والتوصيل
  final TextEditingController _deliveryFeeCtrl = TextEditingController(text: '3000');
  final TextEditingController _minOrderCtrl = TextEditingController(text: '10000');
  final TextEditingController _deliveryRadiusCtrl = TextEditingController(text: '15');
  bool _autoAcceptDeliveryOrders = false;

  // 5. الأمان ورمز المدير
  final TextEditingController _pinCtrl = TextEditingController(text: '1234');
  bool _requirePinForDelete = true;
  bool _requirePinForPriceChange = true;
  bool _requirePinForDrawer = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ownerCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    _taxRateCtrl.dispose();
    _serviceFeeCtrl.dispose();
    _deliveryFeeCtrl.dispose();
    _minOrderCtrl.dispose();
    _deliveryRadiusCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  String _sanitizeOwnerName(dynamic raw) {
    if (raw == null) return 'صاحب المطعم';
    final name = raw.toString().trim();
    if (name.isEmpty) return 'صاحب المطعم';
    final lower = name.toLowerCase();
    if (name == 'عمر مثنى' ||
        name == 'عمر مثنى الراوي' ||
        name == 'عمر مثنى حامد' ||
        lower == 'omar muthana' ||
        lower == 'omar' ||
        lower == 'عمر') {
      return 'صاحب المطعم';
    }
    return name;
  }

  Future<void> _loadSettings() async {
    if (_uid.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      final restDoc = await FirebaseFirestore.instance.collection('restaurants').doc(_uid).get();

      final data = {
        ...?userDoc.data(),
        ...?restDoc.data(),
      };

      if (data.isNotEmpty && mounted) {
        _nameCtrl.text = data['restaurantName'] ?? data['name'] ?? 'مطعم مدار';
        _ownerCtrl.text = _sanitizeOwnerName(data['ownerName'] ?? data['fullName']);
        _phoneCtrl.text = data['phone'] ?? data['phoneNumber'] ?? '';
        _addressCtrl.text = data['address'] ?? data['location'] ?? 'القائم - الأنبار';
        _descCtrl.text = data['description'] ?? '';
        _logoUrl = data['photoUrl'] ?? data['imageUrl'] ?? data['logoUrl'];

        _isOpen = data['isOpen'] as bool? ?? true;
        _prepTimeMinutes = (data['prepTimeMinutes'] as num?)?.toInt() ?? 20;
        _surgeStatus = (data['surgeStatus'] ?? 'normal').toString();
        _openTimeStr = data['openTime'] ?? '10:00 ص';
        _closeTimeStr = data['closeTime'] ?? '01:00 ص';

        _enableCash = data['enableCash'] ?? true;
        _enableZainCash = data['enableZainCash'] ?? true;
        _enableQiCard = data['enableQiCard'] ?? true;
        _enableTax = data['enableTax'] ?? false;
        _taxRateCtrl.text = ((data['taxRate'] ?? 0) as num).toString();
        _serviceFeeCtrl.text = ((data['serviceFee'] ?? 0) as num).toString();

        _deliveryFeeCtrl.text = ((data['deliveryBaseFee'] ?? 3000) as num).toString();
        _minOrderCtrl.text = ((data['minOrderAmount'] ?? 10000) as num).toString();
        _deliveryRadiusCtrl.text = ((data['deliveryRadiusKm'] ?? 15) as num).toString();
        _autoAcceptDeliveryOrders = data['autoAcceptDeliveryOrders'] ?? false;

        _requirePinForDelete = data['requirePinForDelete'] ?? true;
        _requirePinForPriceChange = data['requirePinForPriceChange'] ?? true;
        _requirePinForDrawer = data['requirePinForDrawer'] ?? true;
      }
    } catch (e) {
      debugPrint('[SettingsPage] Error loading settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_uid.isEmpty) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final payload = <String, dynamic>{
        'restaurantName': _nameCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'ownerName': _ownerCtrl.text.trim(),
        'fullName': _ownerCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'isOpen': _isOpen,
        'prepTimeMinutes': _prepTimeMinutes,
        'surgeStatus': _surgeStatus,
        'openTime': _openTimeStr,
        'closeTime': _closeTimeStr,
        'enableCash': _enableCash,
        'enableZainCash': _enableZainCash,
        'enableQiCard': _enableQiCard,
        'enableTax': _enableTax,
        'taxRate': double.tryParse(_taxRateCtrl.text) ?? 0.0,
        'serviceFee': double.tryParse(_serviceFeeCtrl.text) ?? 0.0,
        'deliveryBaseFee': double.tryParse(_deliveryFeeCtrl.text) ?? 3000.0,
        'minOrderAmount': double.tryParse(_minOrderCtrl.text) ?? 10000.0,
        'deliveryRadiusKm': double.tryParse(_deliveryRadiusCtrl.text) ?? 15.0,
        'autoAcceptDeliveryOrders': _autoAcceptDeliveryOrders,
        'requirePinForDelete': _requirePinForDelete,
        'requirePinForPriceChange': _requirePinForPriceChange,
        'requirePinForDrawer': _requirePinForDrawer,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .set(payload, SetOptions(merge: true)),
        FirebaseFirestore.instance
            .collection('restaurants')
            .doc(_uid)
            .set(payload, SetOptions(merge: true)),
      ]);

      // تحديث رمز المدير في SharedPreferences
      final pin = _pinCtrl.text.trim();
      if (pin.isNotEmpty) {
        await AuditLogService.instance.updateManagerPin(pin);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'تم حفظ وتطبيق كافة الإعدادات بنجاح في السحابة ✅',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء حفظ الإعدادات: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PosLanguageController.instance,
      builder: (context, _) {
        final c = context.posColors;
        final pad = MadarResponsive.contentPadding(context);
        final textDir = PosLanguageController.instance.textDirection;

        return Directionality(
          textDirection: textDir,
          child: Scaffold(
            backgroundColor: c.background,
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 880;
                      return Column(
                        children: [
                          // 1. رأس الصفحة التكيفي
                          _buildHeader(c, isCompact),

                          // 2. المحتوى المبوب: شريط أفقي على التابلت، أو قائمة جانبية على الديسكتوب
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                              child: isCompact
                                  ? Column(
                                      children: [
                                        _buildHorizontalSettingsNav(c),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: _buildActivePanel(c),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // قائمة التبويبات الجانبية
                                        _buildSettingsNavigation(c),

                                        const SizedBox(width: 20),

                                        // لوحة الإعدادات النشطة
                                        Expanded(
                                          child: _buildActivePanel(c),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  // ─────────────────────────── 1. رأس الصفحة ───────────────────────────

  Widget _buildHeader(PosColors c, bool isCompact) {
    final isEn = PosLanguageController.instance.isEnglish;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: isCompact ? 12 : 18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5B22), Color(0xFFFF7A45)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5B22).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isEn ? 'System Settings Center' : 'مركز إعدادات النظام',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: isCompact ? 16 : 18,
                          fontWeight: FontWeight.w900,
                          color: c.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text(
                            isEn ? 'Cloud Synced' : 'متزامن سحابياً',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isEn
                      ? 'Manage store identity, operational hours, payments, printers, security and appearance'
                      : 'إدارة هوية المطعم، أوقات العمل، طرق الدفع والضرائب، الطابعات، الأمان وسجل التدقيق',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(
              _isSaving
                  ? (isEn ? 'Saving...' : 'جاري الحفظ...')
                  : (isEn ? 'Save Changes' : 'حفظ التغييرات'),
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5B22),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 22, vertical: 12),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── الشريط الأفقي للتابلت ───────────────────────────

  Widget _buildHorizontalSettingsNav(PosColors c) {
    final isEn = PosLanguageController.instance.isEnglish;
    final tabs = [
      {'title': isEn ? 'Identity' : 'هوية المطعم', 'icon': Icons.storefront_rounded, 'color': const Color(0xFF10B981)},
      {'title': isEn ? 'Hours' : 'ساعات العمل', 'icon': Icons.access_time_rounded, 'color': const Color(0xFF3B82F6)},
      {'title': isEn ? 'Payments' : 'طرق الدفع', 'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFF059669)},
      {'title': isEn ? 'Hardware' : 'الطابعات والعتاد', 'icon': Icons.print_rounded, 'color': const Color(0xFF6366F1)},
      {'title': isEn ? 'Kitchen & Fleet' : 'المطبخ والتوصيل', 'icon': Icons.two_wheeler_rounded, 'color': const Color(0xFFFF5B22)},
      {'title': isEn ? 'Security' : 'الأمان والتدقيق', 'icon': Icons.security_rounded, 'color': const Color(0xFFD97706)},
      {'title': isEn ? 'Appearance & Lang' : 'المظهر والنظام', 'icon': Icons.palette_rounded, 'color': const Color(0xFF8B5CF6)},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (idx) {
          final tab = tabs[idx];
          final isSelected = _activeTab == idx;
          final color = tab['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeTab = idx);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.15) : c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : c.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab['icon'] as IconData, size: 18, color: isSelected ? color : c.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      tab['title'] as String,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? c.textPrimary : c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────── 2. قائمة التبويبات الجانبية ───────────────────────────

  Widget _buildSettingsNavigation(PosColors c) {
    final isEn = PosLanguageController.instance.isEnglish;
    final tabs = [
      {'title': isEn ? 'Store Identity' : 'هوية وبيانات المطعم', 'desc': isEn ? 'Name, address, phone & logo' : 'الاسم، العنوان، الهاتف والشعار', 'icon': Icons.storefront_rounded, 'color': const Color(0xFF10B981)},
      {'title': isEn ? 'Hours & Operations' : 'ساعات العمل والتشغيل', 'desc': isEn ? 'Working hours & rush surge' : 'أوقات الدوام وحالة الذروة', 'icon': Icons.access_time_rounded, 'color': const Color(0xFF3B82F6)},
      {'title': isEn ? 'Payments & Finance' : 'طرق الدفع والمالية', 'desc': isEn ? 'Payment methods, taxes & fees' : 'وسائل الدفع، الضرائب والرسوم', 'icon': Icons.account_balance_wallet_rounded, 'color': const Color(0xFF059669)},
      {'title': isEn ? 'Printers & Hardware' : 'الطابعات وأجهزة العتاد', 'desc': isEn ? 'Receipt printers & cash drawer' : 'طابعات الفواتير ودرج النقود', 'icon': Icons.print_rounded, 'color': const Color(0xFF6366F1)},
      {'title': isEn ? 'Kitchen & Delivery' : 'المطبخ والتوصيل', 'desc': isEn ? 'Delivery zones & KDS screen' : 'مناطق التوصيل وشاشات KDS', 'icon': Icons.two_wheeler_rounded, 'color': const Color(0xFFFF5B22)},
      {'title': isEn ? 'Security & Audit' : 'الأمان وسجل التدقيق', 'desc': isEn ? 'Manager PIN & activity audit' : 'رمز المدير وسجل العمليات الحساسة', 'icon': Icons.security_rounded, 'color': const Color(0xFFD97706)},
      {'title': isEn ? 'Appearance & Lang' : 'المظهر والنظام', 'desc': isEn ? 'Dark mode, theme & language' : 'السمة الداكنة واللغة والنسخ', 'icon': Icons.palette_rounded, 'color': const Color(0xFF8B5CF6)},
    ];

    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, idx) {
          final tab = tabs[idx];
          final isSelected = _activeTab == idx;
          final color = tab['color'] as Color;

          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _activeTab = idx);
            },
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border(right: BorderSide(color: color, width: 3.5))
                    : const Border(right: BorderSide(color: Colors.transparent, width: 3.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.2) : c.background,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(tab['icon'] as IconData, color: isSelected ? color : c.textMuted, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tab['title'] as String,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? c.textPrimary : c.textMuted,
                          ),
                        ),
                        Text(
                          tab['desc'] as String,
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: c.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────── 3. اللوحة النشطة ───────────────────────────

  Widget _buildActivePanel(PosColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _getTabContent(c),
        ),
      ),
    );
  }

  Widget _getTabContent(PosColors c) {
    switch (_activeTab) {
      case 0:
        return _buildStoreInfoTab(c);
      case 1:
        return _buildOperationsTab(c);
      case 2:
        return _buildFinanceTab(c);
      case 3:
        return _buildPrintersTab(c);
      case 4:
        return _buildDeliveryTab(c);
      case 5:
        return _buildSecurityTab(c);
      case 6:
        return _buildAppearanceTab(c);
      default:
        return _buildStoreInfoTab(c);
    }
  }

  // ── التبويب 0: هوية وبيانات المطعم ──
  Widget _buildStoreInfoTab(PosColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('هوية وبيانات المطعم الأساسية', 'تظهر هذه المعلومات للزبائن في تطبيق مدار وفي رأس الفواتير المطبوعة'),
        const SizedBox(height: 20),

        // بطاقة الشعار والمعاينة
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 64,
                  height: 64,
                  color: const Color(0xFF1E2430),
                  child: _logoUrl != null && _logoUrl!.isNotEmpty
                      ? Image.network(_logoUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.storefront_rounded, color: Color(0xFFFF5B22), size: 30))
                      : const Icon(Icons.storefront_rounded, color: Color(0xFFFF5B22), size: 30),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'اسم المطعم',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'الفرع الرئيسي • ${_addressCtrl.text}',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('يمكنك تغيير الشعار من صفحة المنيو أو إضافة وجبة'), backgroundColor: c.primary),
                  );
                },
                icon: const Icon(Icons.photo_camera_rounded, size: 16),
                label: Text('تحديث الشعار', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.primary,
                  side: BorderSide(color: c.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // الحقول الأساسية
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                c: c,
                label: 'اسم المطعم الرسمي',
                controller: _nameCtrl,
                icon: Icons.store_rounded,
                hint: 'مثال: مطعم مدار الفاخر',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                c: c,
                label: 'اسم المدير أو المالك',
                controller: _ownerCtrl,
                icon: Icons.person_rounded,
                hint: 'اسم صاحب المطعم أو المسؤول',
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: _buildTextField(
                c: c,
                label: 'رقم الهاتف والتواصل',
                controller: _phoneCtrl,
                icon: Icons.phone_rounded,
                hint: '07700000000',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                c: c,
                label: 'العنوان والمدينة',
                controller: _addressCtrl,
                icon: Icons.location_on_rounded,
                hint: 'القائم - شارع الكورنيش',
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        _buildTextField(
          c: c,
          label: 'وصف المطعم ونوع المأكولات',
          controller: _descCtrl,
          icon: Icons.description_rounded,
          hint: 'مشويات، وجبات سريعة، بيتزا وإيطالي...',
          maxLines: 2,
        ),
      ],
    );
  }

  // ── التبويب 1: ساعات العمل والتشغيل ──
  Widget _buildOperationsTab(PosColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('التشغيل وساعات العمل وإدارة الذروة', 'التحكم بحالة استقبال الطلبات وسرعة التحضير وتنبيه الزبائن في تطبيق مدار'),
        const SizedBox(height: 20),

        // حالة استقبال الطلبات الحالية
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isOpen ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: _isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOpen ? 'المطعم متاح ومفتوح لاستقبال الطلبات' : 'المطعم مغلق حالياً أمام الزبائن',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    Text(
                      _isOpen ? 'الزبائن قادرون على إرسال الطلبات عبر التطبيق والنظام المباشر' : 'تطبيق مدار يعرض تنبيهاً بأن المطعم مغلق مؤقتاً',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isOpen,
                activeThumbColor: const Color(0xFF10B981),
                onChanged: (val) => setState(() => _isOpen = val),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // وضع الذروة
        Text('مستوى ضغط العمل (Surge Control):', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSurgeCard(
                c: c,
                title: 'استقبال طبيعي',
                subtitle: 'وقت تحضير معتاد',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF10B981),
                isSelected: _surgeStatus == 'normal',
                onTap: () => setState(() => _surgeStatus = 'normal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSurgeCard(
                c: c,
                title: 'ساعة ذروة وضغط',
                subtitle: 'تنبيه بتأخر التحضير',
                icon: Icons.electric_bolt_rounded,
                color: const Color(0xFFF59E0B),
                isSelected: _surgeStatus == 'busy',
                onTap: () => setState(() => _surgeStatus = 'busy'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSurgeCard(
                c: c,
                title: 'إيقاف مؤقت',
                subtitle: 'المطبخ ممتلئ تماماً',
                icon: Icons.pause_circle_outline_rounded,
                color: const Color(0xFFEF4444),
                isSelected: _surgeStatus == 'paused',
                onTap: () => setState(() => _surgeStatus = 'paused'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // وقت التحضير وساعات الدوام
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('وقت التحضير الافتراضي: $_prepTimeMinutes دقيقة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  Slider(
                    value: _prepTimeMinutes.toDouble(),
                    min: 10,
                    max: 90,
                    divisions: 16,
                    label: '$_prepTimeMinutes دقيقة',
                    activeColor: const Color(0xFFFF5B22),
                    onChanged: (v) => setState(() => _prepTimeMinutes = v.toInt()),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildTimePickerCard(c, 'وقت الافتتاح', _openTimeStr, (t) => setState(() => _openTimeStr = t)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTimePickerCard(c, 'وقت الإغلاق', _closeTimeStr, (t) => setState(() => _closeTimeStr = t)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── التبويب 2: طرق الدفع والمالية ──
  Widget _buildFinanceTab(PosColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('طرق الدفع والسياسات المالية والضرائب', 'تحديد قنوات الدفع المقبولة ونسب الضريبة ورسوم الخدمة على الفواتير'),
        const SizedBox(height: 20),

        _buildSwitchTile(
          c: c,
          title: 'الدفع النقدي (كاش في الصندوق)',
          subtitle: 'قبول الدفع المباشر بالدينار العراقي عند الكاشير',
          value: _enableCash,
          icon: Icons.money_rounded,
          color: const Color(0xFF10B981),
          onChanged: (v) => setState(() => _enableCash = v),
        ),
        const SizedBox(height: 10),

        _buildSwitchTile(
          c: c,
          title: 'محفظة زين كاش (ZainCash)',
          subtitle: 'قبول الدفع الإلكتروني عبر المحفظة ورقم الهاتف أو الرمز',
          value: _enableZainCash,
          icon: Icons.wallet_rounded,
          color: const Color(0xFFFF5B22),
          onChanged: (v) => setState(() => _enableZainCash = v),
        ),
        const SizedBox(height: 10),

        _buildSwitchTile(
          c: c,
          title: 'بطاقات كي كارد وماستركارد (Qi Card)',
          subtitle: 'قبول الدفع عبر أجهزة نقاط البيع POS وبطاقات الدفع الوطنية',
          value: _enableQiCard,
          icon: Icons.credit_card_rounded,
          color: const Color(0xFF3B82F6),
          onChanged: (v) => setState(() => _enableQiCard = v),
        ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        _buildSwitchTile(
          c: c,
          title: 'تطبيق ضريبة القيمة المضافة / المبيعات',
          subtitle: 'إضافة نسبة مئوية تلقائياً على إجمالي كل طلب',
          value: _enableTax,
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF8B5CF6),
          onChanged: (v) => setState(() => _enableTax = v),
        ),

        if (_enableTax) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  c: c,
                  label: 'نسبة الضريبة (%)',
                  controller: _taxRateCtrl,
                  icon: Icons.percent_rounded,
                  hint: '5',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  c: c,
                  label: 'رسوم خدمة الصالة (%)',
                  controller: _serviceFeeCtrl,
                  icon: Icons.room_service_rounded,
                  hint: '0',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── التبويب 3: الطابعات وأجهزة العتاد ──
  Widget _buildPrintersTab(PosColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('الطابعات الحرارية وأجهزة نقاط البيع', 'إدارة طابعات الفواتير والمطبخ وفتح درج النقود الآلي عبر البلوتوث والشبكة'),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: _buildHardwareStatusCard(
                c: c,
                title: 'طابعة الفواتير (الكاشير)',
                statusText: 'طباعة حرارية 80mm متصلة',
                icon: Icons.receipt_rounded,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildHardwareStatusCard(
                c: c,
                title: 'طابعة المطبخ (KDS Ticket)',
                statusText: 'طباعة تلقائية عند ورود الطلب',
                icon: Icons.soup_kitchen_rounded,
                color: const Color(0xFFFF5B22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildHardwareStatusCard(
                c: c,
                title: 'درج النقود الآلي (Cash Drawer)',
                statusText: 'فتح تلقائي مع كل عملية بيع نقدية',
                icon: Icons.point_of_sale_rounded,
                color: const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.print_outlined, color: Color(0xFF6366F1), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إدارة وتكوين أجهزة الطابعات المتقدمة', style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary)),
                    const SizedBox(height: 2),
                    Text('البحث عن طابعات البلوتوث والشبكة المحلية (IP)، تعيين عدد النسخ، واختبار الطباعة فورياً', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => PrinterSettingsDialog.show(context),
                icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                label: Text('فتح إعدادات الطابعات', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── التبويب 4: المطبخ والتوصيل ──
  Widget _buildDeliveryTab(PosColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('المطبخ ومناطق التوصيل والطلبات الخارجية', 'تحديد تكاليف التوصيل، نطاق التغطية الجغرافية، وسياسات قبول الطلبات'),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: _buildTextField(
                c: c,
                label: 'أجرة التوصيل الأساسية (د.ع)',
                controller: _deliveryFeeCtrl,
                icon: Icons.delivery_dining_rounded,
                hint: '3000',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                c: c,
                label: 'الحد الأدنى لقيمة الطلب (د.ع)',
                controller: _minOrderCtrl,
                icon: Icons.shopping_basket_rounded,
                hint: '10000',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                c: c,
                label: 'نطاق التوصيل الأقصى (كم)',
                controller: _deliveryRadiusCtrl,
                icon: Icons.map_rounded,
                hint: '15',
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        _buildSwitchTile(
          c: c,
          title: 'القبول التلقائي لطلبات التوصيل',
          subtitle: 'إرسال الطلب فوراً إلى شاشة المطبخ دون انتظار موافقة يدوية من الكاشير',
          value: _autoAcceptDeliveryOrders,
          icon: Icons.auto_mode_rounded,
          color: const Color(0xFFFF5B22),
          onChanged: (v) => setState(() => _autoAcceptDeliveryOrders = v),
        ),
      ],
    );
  }

  // ── التبويب 5: الأمان وسجل التدقيق ──
  Widget _buildSecurityTab(PosColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('الأمان التجاري وسجل التدقيق وكود المدير', 'حماية العمليات الحساسة برمز PIN أمني ومراقبة سجل نشاط الكاشير والمبيعات'),
        const SizedBox(height: 20),

        // بطاقة رمز المدير
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pin_rounded, color: Color(0xFFD97706), size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('كود مرور المدير (Manager PIN)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary)),
                    const SizedBox(height: 2),
                    Text('الرمز السري المعتمد لترخيص عمليات الحذف والخصومات وتعديل الأسعار', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted)),
                  ],
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 6),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: c.surface,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // سياسات الحماية
        Text('طلب رمز المدير قبل تنفيذ الإجراءات التالية:', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary)),
        const SizedBox(height: 10),

        _buildSwitchTile(
          c: c,
          title: 'حذف أو إلغاء طلب مسجل',
          subtitle: 'منع الكاشير من حذف أي فاتورة دون حضور وموافقة المدير',
          value: _requirePinForDelete,
          icon: Icons.delete_forever_rounded,
          color: const Color(0xFFEF4444),
          onChanged: (v) => setState(() => _requirePinForDelete = v),
        ),
        const SizedBox(height: 8),

        _buildSwitchTile(
          c: c,
          title: 'تعديل السعر يدوياً أو منح خصم إضافي',
          subtitle: 'حماية المبيعات من التلاعب بالأسعار أو الخصومات العشوائية',
          value: _requirePinForPriceChange,
          icon: Icons.price_change_rounded,
          color: const Color(0xFFF59E0B),
          onChanged: (v) => setState(() => _requirePinForPriceChange = v),
        ),
        const SizedBox(height: 8),

        _buildSwitchTile(
          c: c,
          title: 'فتح درج النقود يدوياً دون عملية بيع',
          subtitle: 'توثيق كل فتحة لدرج النقود في سجل التدقيق التجاري',
          value: _requirePinForDrawer,
          icon: Icons.lock_open_rounded,
          color: const Color(0xFF3B82F6),
          onChanged: (v) => setState(() => _requirePinForDrawer = v),
        ),

        const SizedBox(height: 24),

        // زر فتح سجل التدقيق الكامل
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFD97706).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.security_rounded, color: Color(0xFFD97706), size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('سجل التدقيق التجاري الشامل (Commercial Audit Log)', style: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5, fontWeight: FontWeight.bold, color: c.textPrimary)),
                    Text('استعراض كافة الحركات الحساسة السابقة ومطابقة السجلات السحابية والمحلية', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => AuditLogsDialog.show(context),
                icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
                label: Text('عرض سجل التدقيق', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── التبويب 6: المظهر والنسخ الاحتياطي ──
  Widget _buildAppearanceTab(PosColors c) {
    final isEn = PosLanguageController.instance.isEnglish;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          isEn ? 'Appearance, Language & Backup' : 'المظهر والسمة البصرية والنسخ الاحتياطي',
          isEn ? 'Customize UI theme, system language and store data backup' : 'تخصيص المظهر المفضل وتصدير بيانات المطعم لضمان الأمان',
        ),
        const SizedBox(height: 20),

        // بطاقات المظهر
        Row(
          children: [
            Expanded(
              child: _buildThemeOptionCard(
                c: c,
                title: isEn ? 'Madar Pro Theme (Dark)' : 'مظهر مدار الفاخر (داكن)',
                subtitle: isEn ? 'Comfortable for long cashier shifts' : 'أداء مريح للعين أثناء العمل الطويل في الكاشير',
                icon: Icons.dark_mode_rounded,
                isSelected: PosThemeController.instance.isDark,
                onTap: () {
                  PosThemeController.instance.setDark(true);
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildThemeOptionCard(
                c: c,
                title: isEn ? 'Daylight Theme (Light)' : 'المظهر النهاري (فاتح)',
                subtitle: isEn ? 'High contrast for bright office rooms' : 'ألوان ناصعة ومتباينة للمكاتب والغرف المضيئة',
                icon: Icons.light_mode_rounded,
                isSelected: !PosThemeController.instance.isDark,
                onTap: () {
                  PosThemeController.instance.setDark(false);
                  setState(() {});
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // تبديل لغة المنظومة (Language Switcher)
        _buildLanguageSelector(c),

        const SizedBox(height: 24),

        // تخصيص لون هوية النظام (Brand Accent Color)
        _buildBrandColorSelector(c),

        const SizedBox(height: 24),

        // النسخ الاحتياطي
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF10B981), size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Instant Cloud Backup' : 'النسخ الاحتياطي السحابي الفوري',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn
                          ? 'All data is saved in Firebase Cloud Firestore with offline support'
                          : 'كافة البيانات تُحفظ في Firestore السحابي وتدعم العمل دون اتصال بالإنترنت',
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11.5, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEn ? 'Database connected and 100% synced ✅' : 'قاعدة البيانات متصلة ومزامنة بنسبة 100% ✅',
                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(isEn ? 'Check Sync' : 'فحص المزامنة', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(PosColors c) {
    final isEn = PosLanguageController.instance.isEnglish;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.language_rounded, color: Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'System Language' : 'لغة المنظومة (System Language)',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      isEn
                          ? 'Switch between English and Arabic with automatic layout direction (LTR / RTL)'
                          : 'التبديل الفوري بين الإنجليزية والعربية مع ضبط اتجاه الواجهة آلياً',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildThemeOptionCard(
                  c: c,
                  title: 'English (US)',
                  subtitle: isEn ? 'Active System Language' : 'تفعيل الإنجليزية للواجهة',
                  icon: Icons.language_rounded,
                  isSelected: isEn,
                  onTap: () {
                    PosLanguageController.instance.setLanguage('en');
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildThemeOptionCard(
                  c: c,
                  title: 'العربية (Arabic)',
                  subtitle: isEn ? 'Switch to Arabic' : 'اللغة الحالية للنظام',
                  icon: Icons.translate_rounded,
                  isSelected: !isEn,
                  onTap: () {
                    PosLanguageController.instance.setLanguage('ar');
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandColorSelector(PosColors c) {
    final currentBrand = PosThemeController.instance.brandColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: currentBrand.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.palette_rounded, color: currentBrand.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لون سمة وهوية النظام (Brand Accent Color)',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      'اختر لون البراند الذي يمثل هوية مطعمك وسيطبق فوراً على كامل الأزرار والأيقونات والمؤشرات',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11.5,
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // شبكة خيارات الألوان المتاحة
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: MadarBrandColors.all.map((brand) {
              final isSelected = brand.id == currentBrand.id;

              return InkWell(
                onTap: () {
                  PosThemeController.instance.setBrandColor(brand);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم تفعيل لون الهوية: ${brand.name} 🎨',
                        style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: brand.primary,
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? brand.primary.withValues(alpha: 0.12)
                        : c.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? brand.primary
                          : c.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: brand.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: brand.primary.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        brand.name,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? brand.primary : c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── العناصر المساعدة ───────────────────────────

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.ibmPlexSansArabic(fontSize: 16, fontWeight: FontWeight.w800, color: context.posColors.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: context.posColors.textMuted)),
      ],
    );
  }

  Widget _buildTextField({
    required PosColors c,
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.w700, color: c.textMuted)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted.withValues(alpha: 0.6)),
            prefixIcon: maxLines == 1 ? Icon(icon, size: 18, color: c.textMuted) : null,
            filled: true,
            fillColor: c.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required PosColors c,
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary)),
                Text(subtitle, style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: color,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSurgeCard({
    required PosColors c,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : c.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : c.border, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: c.textPrimary)),
                  Text(subtitle, style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: c.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerCard(PosColors c, String label, String value, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted)),
              Text(value, style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary)),
            ],
          ),
          Icon(Icons.schedule_rounded, size: 18, color: c.textMuted),
        ],
      ),
    );
  }

  Widget _buildHardwareStatusCard({
    required PosColors c,
    required String title,
    required String statusText,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, fontWeight: FontWeight.bold, color: c.textPrimary)),
          const SizedBox(height: 2),
          Text(statusText, style: GoogleFonts.ibmPlexSansArabic(fontSize: 10.5, color: c.textMuted)),
        ],
      ),
    );
  }

  Widget _buildThemeOptionCard({
    required PosColors c,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5B22).withValues(alpha: 0.1) : c.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? const Color(0xFFFF5B22) : c.border, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFFF5B22) : c.textMuted, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold, color: c.textPrimary)),
                  Text(subtitle, style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFFFF5B22), size: 20),
          ],
        ),
      ),
    );
  }
}
