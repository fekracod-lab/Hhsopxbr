import 'package:flutter/material.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/mersal_request_page.dart';
import 'package:dalal_alqaim/features/delivery/presentation/widgets/mersal_tracking_widget.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late AnimationController _cardsCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _cardsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut));

    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _cardsCtrl.forward();
    });
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _cardsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6F9);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            // ── خلفية ديكورية ناعمة ──
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00BFA5).withValues(alpha: 0.15),
                      const Color(0xFF00BFA5).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.amber.withValues(alpha: 0.1),
                      Colors.amber.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // ── المحتوى الرئيسي ──
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(isDark)),
                // ── تتبع الشحنات المباشرة الحية ──
                const SliverToBoxAdapter(child: MersalTrackingWidget()),
                SliverToBoxAdapter(child: _buildHeroCard(isDark)),
                SliverToBoxAdapter(child: _buildBentoServices(isDark)),
                SliverToBoxAdapter(child: _buildHowItWorks(isDark)),
                SliverToBoxAdapter(child: _buildTrustSection(isDark)),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 1. الهيدر الفخم باللهجة العراقية
  // ═══════════════════════════════════════════
  Widget _buildHeader(bool isDark) {
    return SlideTransition(
      position: _headerSlide,
      child: FadeTransition(
        opacity: _headerFade,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // زر الرجوع
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E676),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'مناديب مدار جاهزين هسة',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF00E676) : const Color(0xFF00897B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'مِـرسال مَــدار',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // أيقونة مرسال المميزة بشعار مدار
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00BFA5), Color(0xFF004D40)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00BFA5).withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'شتريد نوصلك اليوم؟ أمر تدلل، غراضك تجيك للباب',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 2. البطاقة الرئيسية (Hero Card - خدمة مرسال القائم)
  // ═══════════════════════════════════════════
  Widget _buildHeroCard(bool isDark) {
    return _animatedCard(
      index: 0,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MersalRequestPage()),
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 6, 20, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF00BFA5), Color(0xFF00897B), Color(0xFF004D40)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00BFA5).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                left: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 12,
                child: Icon(
                  Icons.electric_moped_rounded,
                  size: 90,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.flash_on_rounded, color: Colors.amberAccent, size: 20),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'الأسرع بالقائم',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'جيبلي من أي مكان ودزه للباب',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'اكتب شنو محتاج من أي سوك، صيدلية، أو محل\nومندوب مرسال يشتري ويوصلك إياه بدقائق!',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'اطلب مرسال هسة',
                            style: TextStyle(
                              color: Color(0xFF004D40),
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_back_rounded, color: Color(0xFF004D40), size: 16),
                        ],
                      ),
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

  // ═══════════════════════════════════════════
  // 3. شبكة خدمات مرسال (Bento Grid)
  // ═══════════════════════════════════════════
  Widget _buildBentoServices(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'خدمات التوصيل والنقل المتوفرة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // البطاقة العريضة: المرسال السريع
              _animatedCard(
                index: 1,
                child: _buildWideServiceCard(
                  isDark,
                  title: 'المرسال السريع',
                  subtitle: 'مندوب يشتريلك أي شي محتاجه من القائم ويوصله لباب بيتك فوراً',
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFFFFA000),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MersalRequestPage()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // الصف الثاني: مسواك السوك + الصيدلية
              Row(
                children: [
                  Expanded(
                    child: _animatedCard(
                      index: 2,
                      child: _buildServiceCard(
                        isDark,
                        title: 'مسواك السوك',
                        subtitle: 'مخضر، فواكه، لحوم، ومواد غذائية',
                        icon: Icons.shopping_basket_rounded,
                        color: const Color(0xFFF57C00),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MersalRequestPage()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _animatedCard(
                      index: 3,
                      child: _buildServiceCard(
                        isDark,
                        title: 'علاج وصيدلية',
                        subtitle: 'أدوية وروشتات مباشرة للبيت',
                        icon: Icons.local_pharmacy_rounded,
                        color: const Color(0xFFE91E63),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MersalRequestPage()),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildWideServiceCard(
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios_new_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 135,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: color),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 4. شلون يشتغل مرسال؟ (How it works)
  // ═══════════════════════════════════════════
  Widget _buildHowItWorks(bool isDark) {
    final steps = [
      _StepInfo(Icons.my_location_rounded, '1. حدد موقعك ', 'وين تريد نوصل الغراض'),
      _StepInfo(Icons.edit_note_rounded, '2. اكتب غراضك ', 'نص، صورة أو بصمة صوتية'),
      _StepInfo(Icons.moped_rounded, '3. يوصلك للباب ', 'تتبع المندوب لحظة بلحظة'),
    ];

    return _animatedCard(
      index: 3,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFA5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.route_rounded, color: Color(0xFF00BFA5), size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'شلون يشتغل مرسال؟',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(steps.length, (i) {
                return Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildStep(isDark, steps[i])),
                      if (i < steps.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 14,
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(bool isDark, _StepInfo info) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(info.icon, color: const Color(0xFF00BFA5), size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          info.title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          info.subtitle,
          style: TextStyle(
            fontSize: 9.5,
            color: isDark ? Colors.white60 : Colors.grey.shade500,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // 5. ميزات وضمانات مرسال (Trust Section)
  // ═══════════════════════════════════════════
  Widget _buildTrustSection(bool isDark) {
    return _animatedCard(
      index: 4,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFF00BFA5).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFF00BFA5).withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTrustItem(isDark, Icons.bolt_rounded, 'توصيل سريع بطيارة'),
            _buildTrustDivider(isDark),
            _buildTrustItem(isDark, Icons.verified_user_rounded, 'مناديب معتمدين وثقة'),
            _buildTrustDivider(isDark),
            _buildTrustItem(isDark, Icons.support_agent_rounded, 'دعم ومتابعة ٢٤ ساعة'),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustItem(bool isDark, IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00BFA5).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF00BFA5), size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildTrustDivider(bool isDark) {
    return Container(
      width: 1,
      height: 32,
      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade300,
    );
  }

  Widget _animatedCard({required int index, required Widget child}) {
    return AnimatedBuilder(
      animation: _cardsCtrl,
      builder: (context, _) {
        final delay = (index * 0.12).clamp(0.0, 0.6);
        final end = (delay + 0.4).clamp(0.0, 1.0);
        final curve = Interval(delay, end, curve: Curves.easeOut);
        final value = curve.transform(_cardsCtrl.value);
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 24 * (1 - value)), child: child),
        );
      },
    );
  }
}

class _StepInfo {
  final IconData icon;
  final String title;
  final String subtitle;
  const _StepInfo(this.icon, this.title, this.subtitle);
}
