import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalal_alqaim/shared/app_constants.dart';
import 'dart:math' as math;

// --- Palette requested by the user ---
const Color primaryColor = Color(0xFF26A69A);
const Color accentColor = Color(0xFF00796B);
const Color backgroundColor = Color(0xFFFFFFFF);
const Color textColor = Color(0xFF333333); // لون النص الأساسي
const Color hintColor = Color(0xFF9E9E9E); // لون النص التلميحي
const Color subTextColor = Color(0xFF757575); // لون النص الثانوي
const Color surfaceColor = Color(0xFFF8F9FA); // لون السطح

// Dark Mode Palette
const Color darkBackground = Color(0xFF07191A);
const Color darkSurface = Color(0xFF0F2323);
const Color darkCard = Color(0xFF113033);
const Color darkText = Color(0xFFE0F2F1);
const Color darkSubText = Color(0xFF80CBC4);
const Color darkHint = Color(0xFF4DB6AC);

class ItemDetailsPage extends StatefulWidget {
  final String sectionId;
  final String itemId;
  final String sectionLabel;
  final IconData sectionIcon;
  final Color sectionColor;
  final String? pageId;

  const ItemDetailsPage({
    super.key,
    required this.sectionId,
    required this.itemId,
    required this.sectionLabel,
    required this.sectionIcon,
    required this.sectionColor,
    this.pageId,
  });

  @override
  State<ItemDetailsPage> createState() => _ItemDetailsPageState();
}

class _ItemDetailsPageState extends State<ItemDetailsPage> {
  bool _isFavorite = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
    _checkIsAdmin();
  }

  Future<void> _checkIsAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = doc.data()?['role'] as String?;
      if (mounted) {
        setState(() {
          _isAdmin = (role == 'admin');
        });
      }
    } catch (_) {
      // If Firestore check fails, default to non-admin
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorites') ?? [];
    if (mounted) {
      setState(() {
        _isFavorite = favorites.contains(widget.itemId);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('favorites') ?? [];

    setState(() {
      if (_isFavorite) {
        favorites.remove(widget.itemId);
        _isFavorite = false;
      } else {
        favorites.add(widget.itemId);
        _isFavorite = true;
      }
    });

    await prefs.setStringList('favorites', favorites);
  }

  bool get isAdmin => _isAdmin;

  void _onBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // --- WhatsApp Inquiry Dialog ---
  void _showWhatsAppInquiryDialog(
    BuildContext context,
    String ownerPhone,
    String itemName,
    bool isDark,
  ) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? darkCard : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'تواصل عبر واتساب',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? darkText : textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يرجى ملء البيانات للاستفسار عن "$itemName"',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? darkSubText : subTextColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // حقل الاسم
                  _buildDialogTextField(
                    controller: nameController,
                    label: 'الاسم الكريم',
                    icon: Icons.person_outline,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // حقل رقم الهاتف
                  _buildDialogTextField(
                    controller: phoneController,
                    label: 'رقم هاتفك',
                    icon: Icons.phone_android_outlined,
                    isDark: isDark,
                    isNumber: true,
                  ),
                  const SizedBox(height: 16),

                  // حقل الملاحظات
                  _buildDialogTextField(
                    controller: notesController,
                    label: 'ملاحظات / استفسار',
                    icon: Icons.note_alt_outlined,
                    isDark: isDark,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // زر الإرسال
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (ownerPhone.isEmpty) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('رقم الواتساب غير متوفر لهذا العنصر')),
                          );
                          return;
                        }

                        // تجهيز الرسالة
                        String message =
                            "مرحباً، استفسار بخصوص: $itemName\n\n"
                            "الاسم: ${nameController.text}\n"
                            "رقم الهاتف: ${phoneController.text}\n"
                            "الملاحظات: ${notesController.text.isEmpty ? 'لا يوجد' : notesController.text}";

                        // تنسيق رقم الهاتف (إزالة الأصفار والرموز، إضافة مفتاح الدولة إذا لزم الأمر)
                        String phone = ownerPhone.replaceAll(RegExp(r'[^0-9]'), '');
                        if (!phone.startsWith('964')) phone = '964$phone'; // افتراض العراق كمثال

                        final whatsappUrl =
                            "whatsapp://send?phone=+$phone&text=${Uri.encodeComponent(message)}";

                        if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
                          await launchUrl(Uri.parse(whatsappUrl));
                          if (ctx.mounted) Navigator.pop(ctx);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(const SnackBar(content: Text('تطبيق واتساب غير مثبت')));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366), // لون واتساب
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'إرسال إلى واتساب',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      maxLines: maxLines,
      style: TextStyle(color: isDark ? darkText : textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? darkHint : hintColor),
        prefixIcon: Icon(icon, color: isDark ? darkHint : Colors.grey),
        filled: true,
        fillColor: isDark ? darkSurface : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF25D366)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentBg = isDark ? darkBackground : backgroundColor;
    final currentCardBg = isDark ? darkCard : Colors.white;
    final currentText = isDark ? darkText : textColor;
    final currentSubText = isDark ? darkSubText : subTextColor;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: currentBg,
        body: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors:
                      isDark
                          ? [darkBackground, darkSurface, darkCard]
                          : [surfaceColor, Colors.white, surfaceColor],
                ),
              ),
            ),

            // Background Pattern
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _DetailsBackgroundPainter(isDark: isDark)),
              ),
            ),

            FutureBuilder<DocumentSnapshot>(
              future:
                  widget.pageId == null
                      ? FirebaseFirestore.instance
                          .collection('sections')
                          .doc(widget.sectionId)
                          .collection('items')
                          .doc(widget.itemId)
                          .get()
                      : FirebaseFirestore.instance
                          .collection('sections')
                          .doc(widget.sectionId)
                          .collection('pages')
                          .doc(widget.pageId!)
                          .collection('items')
                          .doc(widget.itemId)
                          .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmerLoading(isDark);
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 20),
                        Text(
                          'العنصر غير موجود',
                          style: TextStyle(fontSize: 18, color: currentText),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _onBack,
                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                          child: const Text(
                            'عودة',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final imageUrl = data['imageUrl'] ?? '';
                final name = data['name'] ?? '';
                final address = data['address'] ?? '';
                final phone = data['phone'] ?? '';
                final specialty = data['specialty'] ?? '';
                final workingHours = data['workingHours'] ?? '';
                final mapUrl = data['mapUrl'] ?? '';

                return CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(imageUrl, name, isDark),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderSection(name, specialty, workingHours, currentText, isDark),
                            const SizedBox(height: 20),
                            // تم تحديث الإجراءات السريعة لتشمل زر الواتساب الجديد
                            _buildQuickActions(phone, mapUrl, name, address, isDark),
                            const SizedBox(height: 20),
                            _buildInfoSection(
                              address,
                              phone,
                              workingHours,
                              currentCardBg,
                              currentText,
                              currentSubText,
                              isDark,
                            ),
                            const SizedBox(height: 24),
                            Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey[200]),
                            const SizedBox(height: 24),

                            // --- تم حذف قسم القائمة (MenuSection) من هنا ---
                            CommentsSection(
                              sectionId: widget.sectionId,
                              itemId: widget.itemId,
                              pageId: widget.pageId,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 80), // Space for FAB if needed
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(String imageUrl, String name, bool isDark) {
    return SliverAppBar(
      expandedHeight: 300.0,
      pinned: true,
      stretch: true,
      backgroundColor: isDark ? darkSurface : primaryColor,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _onBack,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
        ),
        if (isAdmin)
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                // Handle actions
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'info',
                      child: Text('معلومات المشرف', style: TextStyle()),
                    ),
                  ],
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl.isNotEmpty
                ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(),
                )
                : _buildPlaceholderIcon(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      color: primaryColor.withValues(alpha: 0.2),
      child: Center(child: Icon(widget.sectionIcon, size: 80, color: primaryColor)),
    );
  }

  Widget _buildHeaderSection(
    String name,
    String specialty,
    String workingHours,
    Color textColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (specialty.isNotEmpty)
              _buildTag(
                specialty,
                isDark ? primaryColor.withValues(alpha: 0.2) : Colors.blue.shade50,
                isDark ? darkText : Colors.blue,
              ),
            if (workingHours.isNotEmpty)
              _buildTag(
                'مفتوح الآن',
                isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade50,
                Colors.green,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildQuickActions(String phone, String mapUrl, String name, String address, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.call,
          label: 'اتصال',
          color: Colors.green,
          isDark: isDark,
          onTap: () async {
            if (phone.isNotEmpty) {
              final Uri launchUri = Uri(scheme: 'tel', path: phone);
              await launchUrl(launchUri);
            } else {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('رقم الهاتف غير متوفر')));
            }
          },
        ),
        _buildActionButton(
          icon: Icons.map,
          label: 'الخريطة',
          color: Colors.blue,
          isDark: isDark,
          onTap: () async {
            if (mapUrl.isNotEmpty) {
              await launchUrl(Uri.parse(mapUrl), mode: LaunchMode.externalApplication);
            } else {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('الموقع غير متوفر')));
            }
          },
        ),
        _buildActionButton(
          icon: Icons.share,
          label: 'مشاركة',
          color: Colors.orange,
          isDark: isDark,
          onTap: () {
            Share.share('اكتشف $name في تطبيق ${AppConstants.appName}!\n$address\n$phone');
          },
        ),
        // زر واتساب المعدل
        _buildActionButton(
          icon: Icons.chat,
          label: 'واتساب',
          color: const Color(0xFF25D366),
          isDark: isDark,
          onTap: () {
            // فتح النافذة المنبثقة بدلاً من الواتساب مباشرة
            _showWhatsAppInquiryDialog(context, phone, name, isDark);
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? darkText : const Color(0xFF2D2D2D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    String address,
    String phone,
    String workingHours,
    Color cardBg,
    Color textColor,
    Color subTextColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
      ),
      child: Column(
        children: [
          if (address.isNotEmpty)
            _buildInfoRow(
              Icons.location_on_outlined,
              'العنوان',
              address,
              textColor,
              subTextColor,
              isDark,
            ),
          if (address.isNotEmpty && (phone.isNotEmpty || workingHours.isNotEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
            ),
          if (phone.isNotEmpty)
            _buildInfoRow(
              Icons.phone_outlined,
              'رقم الهاتف',
              phone,
              textColor,
              subTextColor,
              isDark,
            ),
          if (phone.isNotEmpty && workingHours.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
            ),
          if (workingHours.isNotEmpty)
            _buildInfoRow(
              Icons.access_time,
              'أوقات العمل',
              workingHours,
              textColor,
              subTextColor,
              isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color textColor,
    Color subTextColor,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: subTextColor)),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 300, color: Colors.white),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(height: 30, width: 200, color: Colors.white),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      4,
                      (index) => Container(height: 70, width: 70, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(height: 150, width: double.infinity, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MenuSection تم حذفه بالكامل حسب الطلب ---

class CommentsSection extends StatefulWidget {
  final String sectionId;
  final String itemId;
  final String? pageId;
  final bool isDark;

  const CommentsSection({
    super.key,
    required this.sectionId,
    required this.itemId,
    this.pageId,
    required this.isDark,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final TextEditingController _commentController = TextEditingController();

  CollectionReference get commentsRef {
    if (widget.pageId == null) {
      return FirebaseFirestore.instance
          .collection('sections')
          .doc(widget.sectionId)
          .collection('items')
          .doc(widget.itemId)
          .collection('comments');
    } else {
      return FirebaseFirestore.instance
          .collection('sections')
          .doc(widget.sectionId)
          .collection('pages')
          .doc(widget.pageId!)
          .collection('items')
          .doc(widget.itemId)
          .collection('comments');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTextColor = widget.isDark ? darkText : textColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التعليقات',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: currentTextColor,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                style: TextStyle(color: currentTextColor),
                decoration: InputDecoration(
                  hintText: 'أضف تعليقاً...',
                  hintStyle: TextStyle(
                    color: widget.isDark ? darkHint : hintColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: widget.isDark ? darkCard : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () async {
                  if (_commentController.text.isNotEmpty) {
                    final user = FirebaseAuth.instance.currentUser;
                    await commentsRef.add({
                      'text': _commentController.text,
                      'userName': user?.displayName ?? 'مستخدم',
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    _commentController.clear();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: commentsRef.orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();

            final docs = snapshot.data!.docs;
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDark ? darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.isDark ? Colors.white10 : Colors.transparent),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: primaryColor.withValues(alpha: 0.2),
                            child: Icon(Icons.person, size: 14, color: primaryColor),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            data['userName'] ?? 'مستخدم',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: currentTextColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['text'] ?? '',
                        style: TextStyle(
                          color: widget.isDark ? darkSubText : subTextColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _DetailsBackgroundPainter extends CustomPainter {
  final bool isDark;

  _DetailsBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.fill
          ..strokeCap = StrokeCap.round;

    final path = Path();

    // Wave 1
    paint.color =
        isDark ? primaryColor.withValues(alpha: 0.05) : primaryColor.withValues(alpha: 0.03);
    path.moveTo(0, size.height * 0.1);
    path.quadraticBezierTo(size.width * 0.5, size.height * 0.15, size.width, size.height * 0.05);
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();
    canvas.drawPath(path, paint);

    // Wave 2
    path.reset();
    paint.color =
        isDark ? accentColor.withValues(alpha: 0.05) : accentColor.withValues(alpha: 0.02);
    path.moveTo(0, size.height * 0.85);
    path.quadraticBezierTo(size.width * 0.5, size.height * 0.8, size.width, size.height * 0.9);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);

    // Decorative circles
    if (isDark) {
      final starPaint =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.05)
            ..style = PaintingStyle.fill;

      final random = math.Random(123);
      for (int i = 0; i < 15; i++) {
        canvas.drawCircle(
          Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
          random.nextDouble() * 2 + 1,
          starPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
