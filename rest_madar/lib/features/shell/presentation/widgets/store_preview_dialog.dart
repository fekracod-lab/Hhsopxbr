import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../../../services/thermal_printer_service.dart';

/// نافذة معاينة وعرض المتجر للعملاء في منصة مدار:
/// تتيح للمطعم معاينة المنيو كما يراه الزبون مباشرة،
/// مع إمكانية فتح الرابط في المتصفح، نسخه، أو عرض رمز الاستجابة السريعة (QR Code).
class StorePreviewDialog extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final String? logoUrl;
  final String location;
  final bool isOpen;
  final int prepTimeMinutes;
  final VoidCallback? onOpenMenuSettings;

  const StorePreviewDialog({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    this.logoUrl,
    required this.location,
    this.isOpen = true,
    this.prepTimeMinutes = 20,
    this.onOpenMenuSettings,
  });

  /// فتح نافذة عرض المتجر
  static Future<void> show(
    BuildContext context, {
    required String restaurantId,
    required String restaurantName,
    String? logoUrl,
    required String location,
    bool isOpen = true,
    int prepTimeMinutes = 20,
    VoidCallback? onOpenMenuSettings,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => StorePreviewDialog(
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        logoUrl: logoUrl,
        location: location,
        isOpen: isOpen,
        prepTimeMinutes: prepTimeMinutes,
        onOpenMenuSettings: onOpenMenuSettings,
      ),
    );
  }

  @override
  State<StorePreviewDialog> createState() => _StorePreviewDialogState();
}

class _StorePreviewDialogState extends State<StorePreviewDialog> {
  String _selectedCategory = 'الكل';
  String _searchQuery = '';
  bool _showQrCodePanel = false;
  final List<Map<String, dynamic>> _simulatedCart = [];

  String get _storeWebUrl =>
      'https://madar-iq.web.app/menu?restaurantId=${widget.restaurantId}';

  String get _qrImageUrl =>
      'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(_storeWebUrl)}';

  double get _cartTotal => _simulatedCart.fold(
        0.0,
        (accum, item) => accum + ((item['price'] ?? 0) as num).toDouble() * ((item['qty'] ?? 1) as num).toInt(),
      );

  int get _cartItemsCount => _simulatedCart.fold(
        0,
        (accum, item) => accum + ((item['qty'] ?? 1) as num).toInt(),
      );

  Future<void> _launchInBrowser() async {
    final uri = Uri.parse(_storeWebUrl);
    HapticFeedback.lightImpact();
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _copyLinkToClipboard(showBrowserFallbackNotice: true);
      }
    } catch (_) {
      if (mounted) {
        _copyLinkToClipboard(showBrowserFallbackNotice: true);
      }
    }
  }

  void _copyLinkToClipboard({bool showBrowserFallbackNotice = false}) {
    Clipboard.setData(ClipboardData(text: _storeWebUrl));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    final c = context.posColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                showBrowserFallbackNotice
                    ? 'تعذر فتح المتصفح تلقائياً — تم نسخ رابط المتجر إلى الحافظة بنجاح!'
                    : 'تم نسخ رابط المتجر المباشر إلى الحافظة بنجاح! 📋',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: c.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _printStoreQr() async {
    HapticFeedback.mediumImpact();
    try {
      final success = await ThermalPrinterService.printTableQrSticker(
        tableNumber: 'المتجر العام',
        restaurantName: widget.restaurantName,
        qrUrl: _storeWebUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'تم إرسال باركود المتجر للطباعة الحرارية بنجاح! 🖨️'
                : 'تأكد من توصيل الطابعة الحرارية وتثبيت برامج التشغيل',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
          ),
          backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء الطباعة: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _addToSimulatedCart(Map<String, dynamic> product) {
    HapticFeedback.selectionClick();
    setState(() {
      final id = product['id'];
      final idx = _simulatedCart.indexWhere((it) => it['id'] == id);
      if (idx >= 0) {
        _simulatedCart[idx]['qty'] = (_simulatedCart[idx]['qty'] as int) + 1;
      } else {
        _simulatedCart.add({
          'id': id,
          'name': product['name'] ?? 'وجبة',
          'price': (product['price'] as num?)?.toDouble() ?? 0.0,
          'qty': 1,
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.78).clamp(700.0, 1080.0);
    final dialogHeight = (size.height * 0.88).clamp(580.0, 860.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        backgroundColor: c.background,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: c.border, width: 1.2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Column(
              children: [
                // 1. الشريط العلوي مع بيانات المتجر وأزرار الإجراءات
                _buildTopHeader(c),

                // 2. المحتوى الرئيسي للمعاينة
                Expanded(
                  child: Row(
                    children: [
                      // شبكة عرض المتجر والوجبات
                      Expanded(
                        child: Column(
                          children: [
                            // شريط البحث وفلتر التصنيفات
                            _buildFilterBar(c),

                            // شبكة الوجبات الحية
                            Expanded(child: _buildLiveProductsGrid(c)),

                            // سلة تجربة الزبون السفلية
                            if (_simulatedCart.isNotEmpty) _buildSimulatedCartBar(c),
                          ],
                        ),
                      ),

                      // لوحة QR Code الجانبية عند تفعيلها
                      if (_showQrCodePanel) _buildQrSidePanel(c),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── 1. الترويسة العلوية ───────────────────────────

  Widget _buildTopHeader(PosColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          // شعار وصورة المتجر
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: c.card,
              border: Border.all(color: c.primary.withValues(alpha: 0.3), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: widget.logoUrl != null && widget.logoUrl!.isNotEmpty
                  ? Image.network(
                      widget.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(Icons.storefront_rounded, color: c.primary, size: 24),
                    )
                  : Icon(Icons.storefront_rounded, color: c.primary, size: 24),
            ),
          ),
          const SizedBox(width: 14),

          // الاسم والمعلومات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.restaurantName,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.isOpen
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            widget.isOpen ? 'مفتوح للطلبات' : 'مغلق مؤقتاً',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: widget.isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 12, color: c.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '~${widget.prepTimeMinutes} دقيقة تجهيز',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 10,
                              color: c.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 12, color: c.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      widget.location,
                      style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.visibility_outlined, size: 12, color: c.primary),
                    const SizedBox(width: 4),
                    Text(
                      'معاينة مباشرة للمتجر كما يظهر للزبائن في التطبيق والويب',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color: c.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // أزرار التحكم: المتصفح + نسخ + QR + إغلاق
          Row(
            children: [
              // زر فتح في المتصفح الخارجي
              ElevatedButton.icon(
                onPressed: _launchInBrowser,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(
                  'فتح بالمتصفح 🌐',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 8),

              // زر نسخ رابط المتجر
              OutlinedButton.icon(
                onPressed: () => _copyLinkToClipboard(),
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: Text(
                  'نسخ الرابط',
                  style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.textPrimary,
                  side: BorderSide(color: c.border),
                  backgroundColor: c.card,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
              ),
              const SizedBox(width: 8),

              // زر تبديل لوحة QR Code
              IconButton(
                onPressed: () => setState(() => _showQrCodePanel = !_showQrCodePanel),
                tooltip: _showQrCodePanel ? 'إخفاء رمز QR' : 'عرض رمز QR للمتجر',
                icon: Icon(
                  Icons.qr_code_2_rounded,
                  color: _showQrCodePanel ? c.primary : c.textMuted,
                  size: 22,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: _showQrCodePanel ? c.primary.withValues(alpha: 0.15) : c.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                    side: BorderSide(color: _showQrCodePanel ? c.primary : c.border),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // زر إغلاق
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'إغلاق',
                icon: const Icon(Icons.close_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: c.card,
                  foregroundColor: c.textMuted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── 2. شريط البحث والتصنيفات ───────────────────────────

  Widget _buildFilterBar(PosColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // مربع البحث بالوجبات
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.border),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: c.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'ابحث في قائمة وجبات المتجر...',
                      hintStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: c.textMuted),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // زر التوجه لقسم المنيو لتعديل المواد
              if (widget.onOpenMenuSettings != null)
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onOpenMenuSettings!();
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 17),
                  label: Text(
                    'تعديل قائمة الوجبات',
                    style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(foregroundColor: c.primary),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // شريط التصنيفات الأفقية
          SizedBox(
            height: 34,
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('restaurants')
                  .doc(widget.restaurantId)
                  .snapshots(),
              builder: (context, snap) {
                final List<String> categories = ['الكل'];
                if (snap.hasData && snap.data?.data() != null) {
                  final data = snap.data!.data() as Map<String, dynamic>;
                  if (data['categories'] is List) {
                    for (var item in data['categories']) {
                      final s = item.toString().trim();
                      if (s.isNotEmpty && !categories.contains(s)) categories.add(s);
                    }
                  }
                }
                if (categories.length == 1) {
                  categories.addAll(['وجبات رئيسية', 'برجر', 'شاورما', 'مشاوي', 'مقبلات', 'مشروبات', 'حلويات']);
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final cat = categories[i];
                    final isSel = _selectedCategory == cat;
                    final icon = CategoryIconHelper.getIconForCategory(cat);

                    return InkWell(
                      onTap: () => setState(() => _selectedCategory = cat),
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? c.primary : c.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSel ? c.primary : c.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: isSel ? Colors.white : c.textMuted),
                            const SizedBox(width: 6),
                            Text(
                              cat,
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11.5,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                color: isSel ? Colors.white : c.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── 3. شبكة الوجبات الحية ───────────────────────────

  Widget _buildLiveProductsGrid(PosColors c) {
    // جلب من مجموعتي merchant_products و restaurants/{id}/menu
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('merchant_products')
          .doc(widget.restaurantId)
          .collection('products')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: c.primary, strokeWidth: 2.5),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final items = docs.map((d) {
          final data = Map<String, dynamic>.from(d.data() as Map);
          data['id'] = d.id;
          return data;
        }).where((item) {
          final name = (item['name'] ?? item['title'] ?? '').toString().toLowerCase();
          final category = (item['category'] ?? '').toString();
          final desc = (item['description'] ?? '').toString().toLowerCase();

          final matchesSearch = _searchQuery.isEmpty ||
              name.contains(_searchQuery) ||
              category.toLowerCase().contains(_searchQuery) ||
              desc.contains(_searchQuery);

          final matchesCat = _selectedCategory == 'الكل' || category == _selectedCategory;

          return matchesSearch && matchesCat;
        }).toList();

        if (items.isEmpty) {
          return _buildEmptyMenuState(c, hasTotalProducts: docs.isNotEmpty);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = (constraints.maxWidth / 220).floor().clamp(2, 5);

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final product = items[i];
                return _buildProductCard(c, product);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProductCard(PosColors c, Map<String, dynamic> product) {
    final name = product['name'] ?? product['title'] ?? 'وجبة';
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final isAvailable = product['isAvailable'] as bool? ?? true;
    final imageUrl = (product['imageUrl'] ?? product['image'] ?? product['photoUrl'])?.toString();
    final description = product['description']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // صورة الوجبة
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(c),
                        )
                      : _buildPlaceholderImage(c),
                ),
                // شارة الحالة (متوفر / غير متوفر)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? const Color(0xFF10B981).withValues(alpha: 0.9)
                          : const Color(0xFFEF4444).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isAvailable ? 'متوفر' : 'غير متوفر',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // تفاصيل الوجبة
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: c.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${NumberFormat('#,###').format(price)} د.ع',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: c.primary,
                        ),
                      ),
                      // زر تجربة الإضافة لسلة المحاكاة
                      InkWell(
                        onTap: isAvailable ? () => _addToSimulatedCart(product) : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAvailable ? c.primary.withValues(alpha: 0.12) : c.card,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isAvailable ? c.primary : c.border,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_shopping_cart_rounded,
                                size: 13,
                                color: isAvailable ? c.primary : c.textDisabled,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'إضافة',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isAvailable ? c.primary : c.textDisabled,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage(PosColors c) {
    return Container(
      color: c.card,
      child: Center(
        child: Icon(Icons.fastfood_rounded, size: 36, color: c.textDisabled),
      ),
    );
  }

  Widget _buildEmptyMenuState(PosColors c, {required bool hasTotalProducts}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasTotalProducts ? Icons.search_off_rounded : Icons.restaurant_menu_rounded,
                size: 38,
                color: c.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasTotalProducts
                  ? 'لا توجد وجبات تطابق معايير البحث أو القسم'
                  : 'لم يتم إضافة وجبات في متجر المطعم حتى الآن',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasTotalProducts
                  ? 'جرب البحث بكلمات أخرى أو اختر قسماً آخر'
                  : 'أضف وجباتك ومشروباتك من شاشة (قائمة الطعام) وستظهر هنا وفي التطبيق فورياً.',
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12.5, color: c.textMuted),
            ),
            if (!hasTotalProducts && widget.onOpenMenuSettings != null) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onOpenMenuSettings!();
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'إضافة وجبات للمنيو الآن',
                  style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── 4. سلة المحاكاة السفلية ───────────────────────────

  Widget _buildSimulatedCartBar(PosColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.shopping_bag_rounded, color: c.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'سلة تجربة الزبون ($_cartItemsCount عنصر)',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'محاكاة للتاجر',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 9.5,
                        color: const Color(0xFFF59E0B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'المجموع التجريبي: ${NumberFormat('#,###').format(_cartTotal)} د.ع',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: c.primary,
                ),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _simulatedCart.clear()),
            child: Text(
              'تفريغ السلة',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: const Color(0xFFEF4444)),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _launchInBrowser,
            icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 16),
            label: Text(
              'تجربة الطلب الفعلي في الويب 🌐',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── 5. لوحة QR Code الجانبية ───────────────────────────

  Widget _buildQrSidePanel(PosColors c) {
    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_scanner_rounded, size: 20, color: c.primary),
                const SizedBox(width: 8),
                Text(
                  'رمز المتجر الذكي',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'يمكن لزبائنك مسح هذا الرمز بكاميرا هواتفهم لفتح المنيو والطلب مباشرة.',
              style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: c.textMuted),
            ),
            const SizedBox(height: 16),

            // صورة الـ QR
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    _qrImageUrl,
                    width: 170,
                    height: 170,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(
                      width: 170,
                      height: 170,
                      child: Center(child: Icon(Icons.error_outline_rounded, size: 40, color: Colors.grey)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // الرابط المباشر
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border),
              ),
              child: Text(
                _storeWebUrl,
                style: const TextStyle(fontSize: 10, color: Colors.blueAccent),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
              ),
            ),
            const SizedBox(height: 14),

            // زر نسخ الرابط
            OutlinedButton.icon(
              onPressed: () => _copyLinkToClipboard(),
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: Text(
                'نسخ الرابط',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.textPrimary,
                side: BorderSide(color: c.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),

            // زر طباعة الستيكر
            ElevatedButton.icon(
              onPressed: _printStoreQr,
              icon: const Icon(Icons.print_rounded, size: 16),
              label: Text(
                'طباعة ستيكر QR 🖨️',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
