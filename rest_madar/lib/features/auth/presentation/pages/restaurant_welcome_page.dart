import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/restaurant_categories.dart';
import '../../../../core/localization/pos_language_controller.dart';
import 'restaurant_login_page.dart';
import '../../../shell/presentation/desktop_shell_page.dart';

class RestaurantWelcomePage extends StatefulWidget {
  const RestaurantWelcomePage({super.key});

  @override
  State<RestaurantWelcomePage> createState() => _RestaurantWelcomePageState();
}

class _RestaurantWelcomePageState extends State<RestaurantWelcomePage>
    with SingleTickerProviderStateMixin {
  int _activeFeatureIndex = 0;
  final PageController _pageController = PageController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, dynamic>> _features = [
    {
      'title': 'طباعة فواتير مباشرة وصامتة بدون دوخة',
      'titleEn': 'Silent ESC/POS Receipt Printing',
      'subtitle': 'طابعة الكاشير والمطبخ',
      'subtitleEn': 'Cashier & Kitchen Printers',
      'desc':
          'اطبع بونات الطلب وفاتورة الزبون بلحظتها وبدون أي نوافذ منبثقة أو تأخير. يدعم جميع الطابعات الحرارية (USB, LAN, Network) مع كود QR للتحقق وشعار مدار.',
      'descEn':
          'Print kitchen tickets and customer receipts instantly with no popups or delays. Supports USB, LAN, Network thermal printers with QR validation.',
      'icon': Icons.print_rounded,
      'color': const Color(0xFF00BFA5),
      'tag': 'طابعات ESC/POS',
      'tagEn': 'ESC/POS Printers',
    },
    {
      'title': 'منيو إلكتروني وباركود QR لكل ميز وطاولة',
      'titleEn': 'Smart QR Menu for Tables',
      'subtitle': 'طلبات الطاولات الذكية',
      'subtitleEn': 'Smart Dine-In Orders',
      'desc':
          'كل طاولة بمطعمك الها باركود خاص.. الزبون يكعد، يوجّه كاميرته ويفتح المنيو بالصور والأسعار ويطلب، والطلب ينزل كدامك بالسيستم برقم طاولته فوراً!',
      'descEn':
          'Every table has a dedicated QR barcode. Guests scan, view menus with photos/prices, and submit orders directly to your terminal.',
      'icon': Icons.qr_code_2_rounded,
      'color': const Color(0xFFFFB300),
      'tag': 'منيو QR ذكي',
      'tagEn': 'Smart QR Menu',
    },
    {
      'title': 'شاشة المطبخ الحية (KDS) بدون صياح ولخبطة',
      'titleEn': 'Live Kitchen Display System (KDS)',
      'subtitle': 'تنظيم شيف المطبخ',
      'subtitleEn': 'Kitchen Chef Display',
      'desc':
          'الطلبات توصل شاشة المطبخ أول بأول مع صوت تنبيه عالي وتوقيت التحضير. الشيف يضغط تم التحضير والكاشير والسائق يعرفون فوراً.',
      'descEn':
          'Orders arrive in the kitchen with audio alerts and preparation timers. Once ready, cashiers and dispatchers are notified immediately.',
      'icon': Icons.soup_kitchen_rounded,
      'color': const Color(0xFFFF7043),
      'tag': 'نظام KDS',
      'tagEn': 'KDS Display',
    },
    {
      'title': 'ربط مباشر ويا تطبيق مدار وزباين القائم',
      'titleEn': 'Madar Customer Network Integration',
      'subtitle': 'زيادة مبيعاتك وتوصيلك',
      'subtitleEn': 'Sales & Delivery Boost',
      'desc':
          'مطعمك يظهر لآلاف الزباين بتطبيق مدار الرئيسي. تستلم طلبات التوصيل والتسليم الخارجي مباشرة عالشاشة مع تتبع الكباتن خطوة بخطوة.',
      'descEn':
          'Your restaurant is listed to thousands of local customers. Receive delivery and takeaway orders on-screen with real-time driver tracking.',
      'icon': Icons.storefront_rounded,
      'color': const Color(0xFF26A69A),
      'tag': 'شبكة مدار',
      'tagEn': 'Madar Network',
    },
    {
      'title': 'شغال أوفلاين.. حتى لو طفى النت!',
      'titleEn': '100% Offline-First Architecture',
      'subtitle': 'كاشير SQLite مدمج',
      'subtitleEn': 'Built-in SQLite Cashier',
      'desc':
          'حتى لو انقطع النت بمطعمك، استمر بيع واطبع وصولاتك بدون توقف. وأول ما يرجع النت، النظام يرفع ويزامن كل الفواتير سحابياً تلقائياً.',
      'descEn':
          'Never stop selling even during internet outages. All offline receipts and transactions sync automatically once reconnected.',
      'icon': Icons.offline_bolt_rounded,
      'color': const Color(0xFF42A5F5),
      'tag': '100% Offline-First',
      'tagEn': '100% Offline-First',
    },
    {
      'title': 'حسابات الصندوق وإغلاق الشيفتات بدقة',
      'titleEn': 'Shift Reconciliation & Financial Audits',
      'subtitle': 'جرد وأرباح يومية',
      'subtitleEn': 'Daily Profit & Stock Logs',
      'desc':
          'معرفة وارد كل شفت، حساب الكاش والبطاقات، وسحب تقرير نهاية اليوم (Z-Report) مفصل مع جرد حركة المواد الأكثر مبيعاً.',
      'descEn':
          'Track shift revenues, cash drawer counts, and print detailed end-of-day Z-Reports with top-selling dish breakdowns.',
      'icon': Icons.query_stats_rounded,
      'color': const Color(0xFFAB47BC),
      'tag': 'تقارير مالية',
      'tagEn': 'Financial Reports',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('madar_welcome_seen', true);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    return ListenableBuilder(
      listenable: PosLanguageController.instance,
      builder: (context, _) {
        final isEn = PosLanguageController.instance.isEnglish;

        return Directionality(
          textDirection: PosLanguageController.instance.textDirection,
          child: Scaffold(
            backgroundColor: PosTheme.bgDark,
            body: Stack(
              children: [
                // Ambient glowing background
                Positioned(
                  top: -120,
                  right: -100,
                  child: Container(
                    width: 450,
                    height: 450,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PosTheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -150,
                  left: -100,
                  child: Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PosTheme.accent.withValues(alpha: 0.1),
                    ),
                  ),
                ),

                SafeArea(
                  child: isDesktop ? _buildDesktopLayout(isEn) : _buildMobileLayout(isEn),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout(bool isEn) {
    return Row(
      children: [
        // Right side: Branding & Story
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBar(isEn),
                const SizedBox(height: 32),
                _buildMainHeadline(isEn),
                const SizedBox(height: 24),
                _buildCategoriesPreviewRow(isEn),
                const Spacer(),
                _buildActionButtonsRow(isEn),
              ],
            ),
          ),
        ),

        // Left side: Interactive Feature Cards
        Expanded(
          flex: 5,
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: PosTheme.surfaceDark.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: PosTheme.borderDark),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEn ? 'Key Features of Madar POS' : 'أهم مزايا نظام مدار للمطاعم',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: PosTheme.textLight,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: PosTheme.primaryDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: PosTheme.accent.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        isEn ? 'Enterprise Edition' : 'الإصدار الاحترافي',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: PosTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: _features.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final f = _features[index];
                      final isSelected = _activeFeatureIndex == index;
                      final subtitle = (isEn ? (f['subtitleEn'] ?? f['subtitle']) : f['subtitle']) as String;
                      final tag = (isEn ? (f['tagEn'] ?? f['tag']) : f['tag']) as String;
                      final desc = (isEn ? (f['descEn'] ?? f['desc']) : f['desc']) as String;

                      return InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _activeFeatureIndex = index);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (f['color'] as Color).withValues(alpha: 0.12)
                                : PosTheme.cardDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? (f['color'] as Color)
                                  : PosTheme.borderDark,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: (f['color'] as Color).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(f['icon'] as IconData, color: f['color'] as Color, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          subtitle,
                                          style: GoogleFonts.ibmPlexSansArabic(
                                            color: PosTheme.textLight,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (f['color'] as Color).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            tag,
                                            style: TextStyle(
                                              color: f['color'] as Color,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      desc,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: PosTheme.textMuted,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isEn) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBar(isEn),
          const SizedBox(height: 24),
          _buildMainHeadline(isEn),
          const SizedBox(height: 20),
          _buildCategoriesPreviewRow(isEn),
          const SizedBox(height: 28),
          Text(
            isEn ? 'POS Features for Your Restaurant:' : 'ميزات النظام لمطعمك:',
            style: GoogleFonts.ibmPlexSansArabic(
              color: PosTheme.textLight,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          ..._features.map((f) {
            final subtitle = (isEn ? (f['subtitleEn'] ?? f['subtitle']) : f['subtitle']) as String;
            final desc = (isEn ? (f['descEn'] ?? f['desc']) : f['desc']) as String;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PosTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PosTheme.borderDark),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (f['color'] as Color).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(f['icon'] as IconData, color: f['color'] as Color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subtitle,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: PosTheme.textLight,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          desc,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: PosTheme.textMuted,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          _buildActionButtonsRow(isEn),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(bool isEn) {
    return Row(
      children: [
        // زر رجوع — يظهر فقط عندما تكون الشاشة مفتوحة من شاشة الدخول
        if (Navigator.canPop(context)) ...[
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: isEn ? 'Back' : 'رجوع',
            icon: Icon(
              isEn ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 4),
        ],
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: PosTheme.surfaceDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PosTheme.accent.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: PosTheme.primary.withValues(alpha: 0.2),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Image.asset(
              'assets/logo.png',
              errorBuilder: (_, _, _) => const Icon(
                Icons.restaurant_rounded,
                color: PosTheme.accent,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'MADAR POS SYSTEM',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: PosTheme.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: PosTheme.gold.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    isEn ? 'POS Enterprise' : 'نظام المطاعم',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: PosTheme.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              isEn
                  ? 'Cashier POS, QR Tables, & Cloud Thermal Printing'
                  : 'منظومة كاشير، طاولات QR، وطباعة حرارية سحابية',
              style: GoogleFonts.ibmPlexSansArabic(
                color: PosTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Language Toggle Button
        Tooltip(
          message: isEn ? 'Switch to Arabic' : 'التحويل إلى الإنجليزية',
          child: InkWell(
            onTap: () => PosLanguageController.instance.toggle(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: PosTheme.surfaceDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PosTheme.borderDark),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.language_rounded, size: 15, color: PosTheme.accent),
                  const SizedBox(width: 5),
                  Text(
                    isEn ? 'EN' : 'عربي',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: PosTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainHeadline(bool isEn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: PosTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PosTheme.primaryLight.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, color: PosTheme.accent, size: 16),
              const SizedBox(width: 6),
              Text(
                isEn
                    ? 'Official Restaurant Operating System'
                    : 'نظام تشغيل المطاعم المعتمد في القائم والعراق',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: PosTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          isEn
              ? 'Welcome Restaurant Owner!\nMadar organizes your business from A to Z'
              : 'يا هلا بيك بصاحب المطعم!\nنظام مدار يرتّب شغلك من الألف للياء',
          style: GoogleFonts.ibmPlexSansArabic(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isEn
              ? 'Streamline your operations effortlessly. Madar connects your dine-in tables, cashier, kitchen, and customers into one unified system that works seamlessly offline.'
              : 'ريّح بالك من الدفاتر ولخبطة الطلبات.. مدار يربط طاولاتك، كاشيرك، مطبخك، وزباينك بنظام واحد سريع وسهل يشتغل حتى بدون إنترنت.',
          style: GoogleFonts.ibmPlexSansArabic(
            color: PosTheme.textMuted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesPreviewRow(bool isEn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEn
              ? 'Restaurant Categories Supported in Madar:'
              : 'مجموعات وتصنيفات المطاعم المدعومة بمدار:',
          style: GoogleFonts.ibmPlexSansArabic(
            color: PosTheme.textLight,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: MadarRestaurantCategories.all.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final cat = MadarRestaurantCategories.all[idx];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: PosTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cat.accentColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(cat.icon, color: cat.accentColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _categoryTitle(cat, isEn),
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: PosTheme.textLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _categoryTitle(RestaurantCategoryItem cat, bool isEn) {
    if (!isEn) return cat.title;
    switch (cat.id) {
      case 'مشويات وكباب عراقي':
        return 'Grills & Kebab';
      case 'وجبات سريعة وبرغر':
        return 'Fast Food & Burgers';
      case 'بيتزا ومعجنات إيطالية':
        return 'Pizza & Pastries';
      case 'دجاج ومقرمشات':
        return 'Crispy Chicken';
      case 'مأكولات عراقية وشرقية':
        return 'Oriental Cuisine';
      case 'شاورما وقص':
        return 'Shawarma & Doner';
      case 'حلويات وكنافـة وكافيه':
        return 'Desserts & Sweets';
      case 'عصائر ومشروبات طبيعية':
        return 'Fresh Juices & Drinks';
      case 'مأكولات بحرية وسمك':
        return 'Seafood & Fish';
      default:
        return 'Restaurant & Cafe';
    }
  }

  Widget _buildActionButtonsRow(bool isEn) {
    return Column(
      children: [
        Row(
          children: [
            // Primary Login Button
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _completeWelcome();
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const RestaurantLoginPage()),
                  );
                },
                icon: const Icon(Icons.login_rounded, color: Colors.black),
                label: Text(
                  isEn ? 'Sign In to Restaurant' : 'سجّل دخول لمطعمك',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PosTheme.accent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Quick POS Demo Offline Access
        TextButton.icon(
          onPressed: () async {
            await _completeWelcome();
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DesktopShellPage()),
            );
          },
          icon: const Icon(Icons.play_circle_outline_rounded, color: PosTheme.textMuted, size: 18),
          label: Text(
            isEn ? 'Quick POS Demo (Offline Mode)' : 'تجربة الكاشير التجريبي السريع (Quick Demo Offline)',
            style: GoogleFonts.ibmPlexSansArabic(
              color: PosTheme.textMuted,
              fontSize: 12,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}
