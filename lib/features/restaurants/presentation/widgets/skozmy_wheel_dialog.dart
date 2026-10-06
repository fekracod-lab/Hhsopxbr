import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../pages/restaurant_details_page.dart';
import 'confetti_overlay_widget.dart';

// ─── Wheel Painter ─────────────────────────────────────────────────────────────
class WheelPainter extends CustomPainter {
  final List<String> sectors;
  final double rotation;

  WheelPainter({required this.sectors, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius - 10);
    final sectorAngle = 2 * math.pi / sectors.length;

    final paint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final shadowPaint = Paint()
      ..color = Colors.black38
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 12);

    canvas.drawCircle(center, radius - 10, shadowPaint);

    final colors = [
      const Color(0xFF26A69A),
      const Color(0xFFFF7043),
      const Color(0xFF00796B),
      const Color(0xFFE65100),
      const Color(0xFF004D40),
      const Color(0xFFFFB300),
      const Color(0xFF00695C),
      const Color(0xFFD84315),
    ];

    for (int i = 0; i < sectors.length; i++) {
      paint.color = colors[i % colors.length];
      final startAngle = rotation + i * sectorAngle;
      canvas.drawArc(rect, startAngle, sectorAngle, true, paint);
      canvas.drawArc(rect, startAngle, sectorAngle, true, linePaint);

      final glossPaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.18), Colors.transparent],
          center: Alignment.center,
          radius: 0.85,
        ).createShader(rect);
      canvas.drawArc(rect, startAngle, sectorAngle, true, glossPaint);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle + sectorAngle / 2);

      final textSpan = TextSpan(
        text: sectors[i],
        style: TextStyle(
          fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(
              blurRadius: 4.0,
              color: Colors.black45,
              offset: Offset(1.0, 1.0),
            ),
          ],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.rtl,
      );
      textPainter.layout();
      final xOffset = radius * 0.48 - textPainter.width / 2;
      final yOffset = -textPainter.height / 2;
      canvas.translate(xOffset, yOffset);
      textPainter.paint(canvas, Offset.zero);

      canvas.restore();
    }

    final outerRingPaint = Paint()
      ..color = const Color(0xFFFFB74D)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 5, outerRingPaint);

    final lightPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 16; i++) {
      final angle = rotation + i * (2 * math.pi / 16);
      final lightCenter = Offset(
        center.dx + (radius - 5) * math.cos(angle),
        center.dy + (radius - 5) * math.sin(angle),
      );
      lightPaint.color = i % 2 == 0 ? Colors.yellow : Colors.white;
      canvas.drawCircle(lightCenter, 2.5, lightPaint);
    }

    final centerPinPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 22, centerPinPaint);

    final centerPinBorder = Paint()
      ..color = const Color(0xFFFF7043)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 22, centerPinBorder);

    final iconData = Icons.toys_rounded;
    final textSpan = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: 24,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: const Color(0xFFFF7043),
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant WheelPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}

/// نافذة عجلة حظ مدار التفاعلية (Skozmy Wheel Dialog)
class SkozmyWheelDialog extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> mealsFuture;
  final Function(String) onSearch;

  const SkozmyWheelDialog({
    super.key,
    required this.mealsFuture,
    required this.onSearch,
  });

  @override
  State<SkozmyWheelDialog> createState() => _SkozmyWheelDialogState();
}

class _SkozmyWheelDialogState extends State<SkozmyWheelDialog>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _sectorsData = [];
  List<String> _sectors = [];
  bool _isLoading = true;
  String _filterType = 'الكل';
  int _luckScore = 95;

  late AnimationController _controller;
  late Animation<double> _animation;
  double _rotation = 0;
  bool _isSpinning = false;
  String? _result;
  int _lastTickedSector = -1;

  final List<Particle> _wheelConfetti = [];

  String _currentMode = 'food';
  bool _hasSpunToday = false;
  List<String> _wonCoupons = [];
  bool _hapticsEnabled = true;
  bool _soundEnabled = true;
  bool _showSettings = false;
  bool _showHistory = false;
  Duration _timeToMidnight = Duration.zero;
  Timer? _countdownTimer;

  final List<Map<String, dynamic>> _couponsList = [
    {'mealName': 'توصيل بلاش', 'couponCode': 'FREE_DELIVERY', 'description': 'توصيل بلاش لطلبك الجاي من القائم!'},
    {'mealName': 'خصم 10%', 'couponCode': 'DALAL10', 'description': 'خصم 10% على إجمالي قيمة طلبك!'},
    {'mealName': 'خصم 2,000 د.ع', 'couponCode': 'ALQAIM2K', 'description': 'خصم بقيمة ألفين دينار عراقي!'},
    {'mealName': 'كوبون حظ 50%', 'couponCode': 'LUCKY50', 'description': 'خصم 50% على أجور التوصيل!'},
    {'mealName': 'مشروب بلاش', 'couponCode': 'FREE_DRINK', 'description': 'كوبون مشروب بارد بلاش ويا وجبتك!'},
    {'mealName': 'تحلية بلاش', 'couponCode': 'FREE_SWEET', 'description': 'كوبون تحلية بلاش ويا طلبك!'},
    {'mealName': 'خصم 1,500 د.ع', 'couponCode': 'DALAL1.5', 'description': 'خصم بقيمة 1,500 دينار عراقي!'},
    {'mealName': 'حظ أوفر', 'couponCode': 'TRY_AGAIN', 'description': 'حظ أوفر المرة الجاية عيوني!'},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        if (!mounted) return;
        setState(() {
          _rotation = _animation.value;

          if (_sectors.isNotEmpty) {
            final sectorAngle = 2 * math.pi / _sectors.length;
            final currentAngle = _rotation % (2 * math.pi);
            final currentSector = (currentAngle / sectorAngle).floor();
            if (currentSector != _lastTickedSector) {
              _lastTickedSector = currentSector;
              if (_hapticsEnabled) {
                HapticFeedback.lightImpact();
              }
            }
          }
        });
      });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _sectors.isNotEmpty) {
        final sectorAngle = 2 * math.pi / _sectors.length;
        double winningAngle = (1.5 * math.pi - (_rotation % (2 * math.pi))) % (2 * math.pi);
        if (winningAngle < 0) winningAngle += 2 * math.pi;
        int winnerIndex = (winningAngle / sectorAngle).floor() % _sectors.length;

        final winningSector = _sectors[winnerIndex];

        setState(() {
          _result = winningSector;
          _isSpinning = false;
        });

        _triggerDialogConfetti();
        if (_hapticsEnabled) {
          HapticFeedback.vibrate();
        }

        if (_currentMode == 'coupon') {
          final coupon = _couponsList.firstWhere(
            (c) => c['mealName'] == winningSector,
            orElse: () => {'couponCode': 'TRY_AGAIN'},
          );
          _saveSpinAndCoupon(winningSector, coupon['couponCode']);
        } else {
          _saveSpinAndCoupon(winningSector, 'FOOD_REC');
        }
      }
    });

    _luckScore = _getDailyLuckScore();
    _loadSettingsAndHistory();
    _loadDailyMeals();
  }

  int _getDailyLuckScore() {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day + 7;
    final random = math.Random(seed);
    return 80 + random.nextInt(20);
  }

  Future<void> _loadSettingsAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final lastSpin = prefs.getString('last_spin_date') ?? '';

    setState(() {
      _hasSpunToday = lastSpin == todayStr;
      _wonCoupons = prefs.getStringList('won_coupons_list') ?? [];
      _hapticsEnabled = prefs.getBool('wheel_haptics_enabled') ?? true;
      _soundEnabled = prefs.getBool('wheel_sound_enabled') ?? true;
    });

    if (_hasSpunToday) {
      _startCountdown();
    }
  }

  Future<void> _saveSpinAndCoupon(String prizeName, String couponCode) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('last_spin_date', todayStr);

    if (couponCode != 'TRY_AGAIN' && couponCode != 'FOOD_REC') {
      final entry = '$couponCode:$prizeName';
      if (!_wonCoupons.contains(entry)) {
        _wonCoupons.add(entry);
        await prefs.setStringList('won_coupons_list', _wonCoupons);
      }
    }

    setState(() {
      _hasSpunToday = true;
    });
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day + 1);
      if (mounted) {
        setState(() {
          _timeToMidnight = midnight.difference(now);
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _shareApp() {
    Share.share('جربت عجلة حظ مدار اليوم؟ تفوتك الوجبات والخصومات اليومية! حمل التطبيق وهلا بيك بالقائم');
    setState(() {
      _hasSpunToday = false;
    });
    _countdownTimer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'حصلت على فرصة إضافية وتدلل يا غالي!',
          style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily),
        ),
        backgroundColor: const Color(0xFF26A69A),
      ),
    );
  }

  void _loadDailyMeals() {
    if (_currentMode == 'coupon') {
      setState(() {
        _sectorsData = _couponsList;
        _sectors = _couponsList.map((m) => m['mealName'] as String).toList();
        _isLoading = false;
      });
    } else {
      widget.mealsFuture.then((allMeals) {
        if (!mounted) return;
        final dailyMeals = _getDailyMeals(allMeals);
        setState(() {
          _sectorsData = dailyMeals;
          _sectors = dailyMeals.map((m) => m['mealName'] as String).toList();
          _isLoading = false;
        });
      }).catchError((err) {
        if (!mounted) return;
        setState(() {
          _sectorsData = [];
          _sectors = [];
          _isLoading = false;
        });
      });
    }
  }

  List<Map<String, dynamic>> _getDailyMeals(List<Map<String, dynamic>> allMeals) {
    if (allMeals.isEmpty) {
      return [];
    }

    final validMeals = allMeals.where((m) {
      final name = m['mealName']?.toString();
      final restId = m['restaurantId']?.toString();
      final restName = m['restaurantName']?.toString();
      final price = m['mealPrice'];
      return name != null &&
          name.trim().isNotEmpty &&
          restId != null &&
          restId.trim().isNotEmpty &&
          restName != null &&
          restName.trim().isNotEmpty &&
          price != null;
    }).toList();

    if (validMeals.length < 8) {
      return [];
    }

    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final random = math.Random(seed);

    List<Map<String, dynamic>> sourceMeals = validMeals;

    if (_filterType != 'الكل') {
      final filtered = sourceMeals.where((m) {
        final cat = m['category']?.toString() ?? 'المطاعم';
        if (_filterType == 'وجبات') return cat == 'المطاعم' || cat == 'المنزلية';
        if (_filterType == 'حلويات') return cat == 'الحلويات';
        if (_filterType == 'عصائر') return cat == 'العصائر';
        return true;
      }).toList();

      if (filtered.length >= 8) {
        sourceMeals = filtered;
      }
    }

    final copy = List<Map<String, dynamic>>.from(sourceMeals);
    copy.shuffle(random);

    final selected = copy.take(8).toList();
    if (selected.length < 8) {
      return [];
    }

    return selected;
  }

  Map<String, dynamic>? _getSelectedMealData() {
    if (_result == null) return null;
    return _sectorsData.firstWhere(
      (m) => m['mealName'] == _result,
      orElse: () => {},
    );
  }

  void _triggerDialogConfetti() {
    final random = math.Random();
    final colors = [
      const Color(0xFF26A69A),
      const Color(0xFF00796B),
      const Color(0xFFFF7043),
      const Color(0xFFFFB74D),
      Colors.white,
    ];
    setState(() {
      _wheelConfetti.clear();
      for (int i = 0; i < 40; i++) {
        _wheelConfetti.add(Particle(
          x: 0.5 + (random.nextDouble() - 0.5) * 0.2,
          y: 0.4 + (random.nextDouble() - 0.5) * 0.2,
          vx: (random.nextDouble() - 0.5) * 0.03,
          vy: (random.nextDouble() - 0.7) * 0.03,
          size: random.nextDouble() * 6 + 3,
          color: colors[random.nextInt(colors.length)],
          rotation: random.nextDouble() * 360,
          rotationSpeed: (random.nextDouble() - 0.5) * 10,
        ));
      }
    });

    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || _wheelConfetti.isEmpty) {
        timer.cancel();
        return;
      }
      setState(() {
        for (final p in _wheelConfetti) {
          p.x += p.vx;
          p.y += p.vy;
          p.vy += 0.001;
          p.rotation += p.rotationSpeed;
        }
        _wheelConfetti.removeWhere((p) => p.y > 1.0 || p.x < 0.0 || p.x > 1.0);
      });
    });
  }

  void _spin() {
    if (_isSpinning || _isLoading || _sectors.isEmpty) return;
    if (_hasSpunToday) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'لقد قمت بلف العجلة اليوم عيوني! شارك التطبيق واكسب فرصة ثانية',
            style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily),
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (_hapticsEnabled) {
      HapticFeedback.mediumImpact();
    }
    if (_soundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }

    final random = math.Random();
    final targetSpin = (4 + random.nextInt(3)) * 2 * math.pi + random.nextDouble() * 2 * math.pi;

    _controller.reset();
    _animation = Tween<double>(begin: _rotation % (2 * math.pi), end: _rotation + targetSpin).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    setState(() {
      _isSpinning = true;
      _result = null;
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Widget _buildTypeChip(String label) {
    final cleanLabel = label.split(' ')[0];
    final isSelected = _filterType == cleanLabel;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (_isSpinning) return;
        HapticFeedback.lightImpact();
        setState(() {
          _filterType = cleanLabel;
          _isLoading = true;
        });
        _loadDailyMeals();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF26A69A) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? Colors.transparent : (isDark ? Colors.white24 : Colors.grey[300]!),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
            fontSize: 10.5.sp,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  String _getCouponWinDescription(String couponName) {
    switch (couponName) {
      case 'توصيل بلاش':
        return 'ألف مبروك! حصلت على توصيل بلاش لطلبك القادم من القائم';
      case 'خصم 10%':
        return 'مبروك! خصم 10% على طلبك القادم';
      case 'خصم 2,000 د.ع':
        return 'كفو! خصم 2,000 دينار عراقي يخصم مباشرة من طلبك القادم';
      case 'كوبون حظ 50%':
        return 'يا عيني! خصم 50% على رسوم التوصيل لجميع مناطق القائم';
      case 'مشروب بلاش':
        return 'صحتين وهنا! مشروب بارد بلاش ويا وجبتك القادمة';
      case 'تحلية بلاش':
        return 'حلي يومك! قطعة تحلية بلاش كهدية ويا طلبك القادم';
      case 'خصم 1,500 د.ع':
        return 'يا هلا! خصم بقيمة 1,500 دينار عراقي لطلبك القادم';
      case 'حظ أوفر':
        return 'حظ أوفر المرة الجاية عيوني! باجر فرصة جديدة وربح أكيد';
      default:
        return 'كوبون جائزة مميزة بقيمة رائعة من مدار!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeBg = isDark ? const Color(0xFF0F2323) : Colors.white;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        child: Stack(
          alignment: Alignment.center,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  color: themeBg.withValues(alpha: isDark ? 0.85 : 0.95),
                  borderRadius: BorderRadius.circular(30.r),
                  border: Border.all(
                    color: const Color(0xFF26A69A).withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_isSpinning) return;
                            HapticFeedback.lightImpact();
                            setState(() {
                              _showHistory = !_showHistory;
                              _showSettings = false;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(6.r),
                            decoration: BoxDecoration(
                              color: _showHistory ? const Color(0xFF26A69A).withValues(alpha: 0.2) : (isDark ? Colors.white10 : Colors.grey[200]),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.emoji_events_rounded,
                              size: 18.r,
                              color: _showHistory ? const Color(0xFF26A69A) : (isDark ? const Color(0xFF80CBC4) : const Color(0xFF616161)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            child: Text(
                              _showSettings 
                                  ? 'إعدادات العجلة' 
                                  : (_showHistory ? 'جوائزي وكوبوناتي' : 'عجلة حظ مدار'),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w900,
                                color: isDark ? const Color(0xFFE0F2F1) : const Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_isSpinning) return;
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _showSettings = !_showSettings;
                                  _showHistory = false;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(6.r),
                                decoration: BoxDecoration(
                                  color: _showSettings ? const Color(0xFF26A69A).withValues(alpha: 0.2) : (isDark ? Colors.white10 : Colors.grey[200]),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  size: 18.r,
                                  color: _showSettings ? const Color(0xFF26A69A) : (isDark ? const Color(0xFF80CBC4) : const Color(0xFF616161)),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: EdgeInsets.all(6.r),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.grey[200],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18.r,
                                  color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF616161),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),

                    if (_showSettings) ...[
                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              activeTrackColor: const Color(0xFF26A69A),
                              title: Text('أصوات العجلة التفاعلية', style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily, fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: Text('تشغيل المؤثرات الصوتية عند نقر العجلة ودورانها', style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily, fontSize: 10.5)),
                              value: _soundEnabled,
                              onChanged: (val) async {
                                final prefs = await SharedPreferences.getInstance();
                                setState(() => _soundEnabled = val);
                                await prefs.setBool('wheel_sound_enabled', val);
                              },
                            ),
                            const Divider(height: 24),
                            SwitchListTile(
                              activeTrackColor: const Color(0xFF26A69A),
                              title: Text('الاهتزاز اللمسي الذكي', style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily, fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: Text('تفعيل نقرات الاهتزاز أثناء حركة العجلة وتدلل عيوني', style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily, fontSize: 10.5)),
                              value: _hapticsEnabled,
                              onChanged: (val) async {
                                final prefs = await SharedPreferences.getInstance();
                                setState(() => _hapticsEnabled = val);
                                await prefs.setBool('wheel_haptics_enabled', val);
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),
                      ElevatedButton(
                        onPressed: () => setState(() => _showSettings = false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF26A69A),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 12.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                        child: Text('حفظ وإغلاق', style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily, fontWeight: FontWeight.bold)),
                      ),
                    ] else if (_showHistory) ...[
                      Container(
                        constraints: BoxConstraints(maxHeight: 280.h),
                        width: double.infinity,
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                        ),
                        child: _wonCoupons.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40.h),
                                  child: Column(
                                    children: [
                                      Icon(Icons.stars_rounded, color: Colors.grey[400], size: 44.r),
                                      SizedBox(height: 10.h),
                                      Text(
                                        'ماكو جوائز مسجلة بعد عيوني! \nافر العجلة وجرب حظك اليوم بالفوز بكوبون خصم.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily, fontSize: 11.5, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: _wonCoupons.length,
                                separatorBuilder: (_, __) => SizedBox(height: 8.h),
                                itemBuilder: (context, idx) {
                                  final parts = _wonCoupons[idx].split(':');
                                  final code = parts[0];
                                  final name = parts.length > 1 ? parts[1] : code;

                                  return Container(
                                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E2E2E) : Colors.white,
                                      borderRadius: BorderRadius.circular(14.r),
                                      border: Border.all(color: const Color(0xFF26A69A).withValues(alpha: 0.15)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8.r),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF26A69A).withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.redeem_rounded, color: Color(0xFF26A69A), size: 16),
                                        ),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(name, style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily, fontSize: 12, fontWeight: FontWeight.bold)),
                                              SizedBox(height: 2.h),
                                              Text('الرمز: $code', style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily, fontSize: 10.5, color: isDark ? Colors.white70 : Colors.grey[600])),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: code));
                                            HapticFeedback.mediumImpact();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('نسخنا الرمز $code وتدلل!', style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily)),
                                                backgroundColor: const Color(0xFF26A69A),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF26A69A),
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                            elevation: 0,
                                          ),
                                          child: Text('انسخ الكود', style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily, fontSize: 10, fontWeight: FontWeight.bold)),
                                        )
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                        onPressed: () => setState(() => _showHistory = false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF26A69A),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 12.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                        child: Text('رجوع', style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily, fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      Container(
                        height: 38.h,
                        margin: EdgeInsets.only(bottom: 10.h),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_isSpinning) return;
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _currentMode = 'food';
                                    _isLoading = true;
                                    _result = null;
                                  });
                                  _loadDailyMeals();
                                },
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _currentMode == 'food' ? const Color(0xFF26A69A) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                  child: Text(
                                    'حاير شتاكل؟',
                                    style: TextStyle(
                                      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                      color: _currentMode == 'food' ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_isSpinning) return;
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _currentMode = 'coupon';
                                    _isLoading = true;
                                    _result = null;
                                  });
                                  _loadDailyMeals();
                                },
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _currentMode == 'coupon' ? const Color(0xFF26A69A) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                  child: Text(
                                    'كوبونات وخصومات',
                                    style: TextStyle(
                                      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.bold,
                                      color: _currentMode == 'coupon' ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        margin: EdgeInsets.symmetric(vertical: 8.h),
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF26A69A).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, color: Colors.yellow, size: 16.r),
                            SizedBox(width: 6.w),
                            Flexible(
                              child: Text(
                                _currentMode == 'coupon'
                                    ? 'افر العجلة واربح كوبونات وجوائز حلوة اليوم!'
                                    : 'نسبة حظك اليوم بالاختيار: %',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                  fontSize: 10.5.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_currentMode == 'food') ...[
                        Container(
                          height: 34.h,
                          margin: EdgeInsets.symmetric(vertical: 12.h),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildTypeChip('الكل'),
                                SizedBox(width: 8.w),
                                _buildTypeChip('وجبات'),
                                SizedBox(width: 8.w),
                                _buildTypeChip('حلويات'),
                                SizedBox(width: 8.w),
                                _buildTypeChip('عصائر'),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        SizedBox(height: 12.h),
                      ],

                      if (_isLoading)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 60.h),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: Color(0xFF26A69A),
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                'جاي نجهزلك عجلة الحظ...',
                                style: TextStyle(
                                  fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF616161),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_sectors.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 16.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.restaurant_menu_rounded,
                                size: 48.r,
                                color: isDark ? const Color(0xFF80CBC4) : Colors.grey,
                              ),
                              SizedBox(height: 14.h),
                              Text(
                                'عذراً، لا تتوفر وجبات كافية لتشغيل عجلة الحظ حالياً',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF616161),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            GestureDetector(
                              onTap: _spin,
                              child: AnimatedBuilder(
                                animation: _animation,
                                builder: (context, child) {
                                  return Transform.rotate(
                                    angle: _rotation,
                                    child: Container(
                                      width: 250.r,
                                      height: 250.r,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                      ),
                                      child: CustomPaint(
                                        painter: WheelPainter(
                                          sectors: _sectors,
                                          rotation: _rotation,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 0,
                              child: Container(
                                transform: Matrix4.translationValues(0, -8, 0),
                                child: Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: const Color(0xFFFF7043),
                                  size: 40.r,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16.h),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: _result != null
                              ? Column(
                                  key: ValueKey<String>(_result!),
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(14.r),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF26A69A).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(16.r),
                                        border: Border.all(color: const Color(0xFF26A69A).withValues(alpha: 0.2)),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            _currentMode == 'coupon' ? 'مبروك! فزت بكوبون:' : 'مدار يرشحلك اليوم:',
                                            style: TextStyle(
                                              fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                              fontSize: 11.sp,
                                              color: const Color(0xFF26A69A),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 6.h),
                                          Text(
                                            _currentMode == 'coupon'
                                                ? _getCouponWinDescription(_result!)
                                                : _getIraqiRecommendation(_result!),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                              fontSize: 12.5.sp,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? const Color(0xFFE0F2F1) : const Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          if (_currentMode == 'food' && _getSelectedMealData()?['restaurantId'] != null) ...[
                                            SizedBox(height: 8.h),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.storefront_rounded, color: const Color(0xFFFF7043), size: 14.r),
                                                SizedBox(width: 4.w),
                                                Text(
                                                  'من مطعم: ${_getSelectedMealData()?['restaurantName']}',
                                                  style: TextStyle(
                                                    fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                                    fontSize: 11.5.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFFFF7043),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (_getSelectedMealData()?['mealPrice'] != null && _getSelectedMealData()?['mealPrice'] > 0) ...[
                                              SizedBox(height: 4.h),
                                              Text(
                                                'السعر: ${(_getSelectedMealData()?['mealPrice'] as double).toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")} د.ع',
                                                style: TextStyle(
                                                  fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w900,
                                                  color: const Color(0xFF26A69A),
                                                ),
                                              ),
                                            ],
                                          ] else if (_currentMode == 'coupon') ...[
                                            SizedBox(height: 8.h),
                                            if (_result != 'حظ أوفر') ...[
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFF7043).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(10.r),
                                                  border: Border.all(color: const Color(0xFFFF7043).withValues(alpha: 0.3)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'كوبون: ${_couponsList.firstWhere((c) => c['mealName'] == _result, orElse: () => {'couponCode': 'DALAL'})['couponCode']}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w900,
                                                        color: Color(0xFFFF7043),
                                                      ),
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Icon(Icons.copy_rounded, color: const Color(0xFFFF7043), size: 14.r),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ]
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 16.h),
                                    if (_currentMode == 'food') ...[
                                      _getSelectedMealData()?['restaurantId'] != null
                                          ? ElevatedButton.icon(
                                              onPressed: () {
                                                HapticFeedback.mediumImpact();
                                                Navigator.pop(context);
                                                final mealData = _getSelectedMealData()!;
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => RestaurantDetailsPage(
                                                      restaurantId: mealData['restaurantId']?.toString() ?? '',
                                                      restaurantName: mealData['restaurantName']?.toString() ?? '',
                                                      imageUrl: mealData['restaurantImageUrl']?.toString() ?? '',
                                                    ),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(Icons.restaurant_menu_rounded, color: Colors.white),
                                              label: Text(
                                                'اطلبها من ${_getSelectedMealData()?['restaurantName']} ',
                                                style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily, fontWeight: FontWeight.bold),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFFF7043),
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16.r),
                                                ),
                                                elevation: 3,
                                              ),
                                            )
                                          : ElevatedButton.icon(
                                              onPressed: () {
                                                HapticFeedback.mediumImpact();
                                                Navigator.pop(context);
                                                widget.onSearch(_result!.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '').trim());
                                              },
                                              icon: const Icon(Icons.search_rounded, color: Colors.white),
                                              label: Text(
                                                'دوّر على هالأكلة بالقائم',
                                                style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily, fontWeight: FontWeight.bold),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF26A69A),
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16.r),
                                                ),
                                                elevation: 2,
                                              ),
                                            ),
                                    ] else ...[
                                      if (_result != 'حظ أوفر') ...[
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            HapticFeedback.mediumImpact();
                                            final code = _couponsList.firstWhere((c) => c['mealName'] == _result, orElse: () => {'couponCode': 'DALAL'})['couponCode'];
                                            Clipboard.setData(ClipboardData(text: code));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('نسخنا رمز الكوبون $code وتدلل!', style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily)),
                                                backgroundColor: const Color(0xFF26A69A),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.copy_rounded, color: Colors.white),
                                          label: Text('انسخ رمز الكوبون واطلب', style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFF7043),
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                                            elevation: 3,
                                          ),
                                        ),
                                      ] else ...[
                                        Text(
                                          'حظ أوفر باجر عيوني! الربح أكيد غداً',
                                          style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily, fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.grey),
                                        ),
                                      ]
                                    ],
                                  ],
                                )
                              : (_hasSpunToday
                                  ? Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(14.r),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(16.r),
                                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.15)),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.lock_clock_rounded, color: Colors.redAccent, size: 20),
                                              SizedBox(width: 8.w),
                                              Text(
                                                'خلصت فرصة اليوم يا غالي!',
                                                style: TextStyle(
                                                  fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                                  fontSize: 12.5.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8.h),
                                          Text(
                                            'تتجدد المحاولة تلقائياً بعد: ${_timeToMidnight.inHours.toString().padLeft(2,'0')}:${(_timeToMidnight.inMinutes % 60).toString().padLeft(2, '0')}:${(_timeToMidnight.inSeconds % 60).toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                          SizedBox(height: 12.h),
                                          ElevatedButton.icon(
                                            onPressed: _shareApp,
                                            icon: const Icon(Icons.share_rounded, color: Colors.white),
                                            label: Text(
                                              'شارك التطبيق وافرها مرة ثانية',
                                              style: TextStyle(fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily, fontWeight: FontWeight.bold),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF26A69A),
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12.r),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        Text(
                                          _isSpinning ? 'جاي تفتر وندورلك أطيب أكلة...' : 'اضغط على العجلة وافرها!',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                            fontSize: 12.5.sp,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF616161),
                                          ),
                                        ),
                                        SizedBox(height: 14.h),
                                        ElevatedButton(
                                          onPressed: (_sectors.isEmpty || _isSpinning) ? null : _spin,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFF7043),
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16.r),
                                            ),
                                            elevation: 4,
                                          ),
                                          child: Text(
                                            _isSpinning ? 'يارب تطلع أكلة طيبة...' : 'افر العجلة',
                                            style: TextStyle(
                                              fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            if (_wheelConfetti.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: ConfettiPainter(particles: _wheelConfetti),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getIraqiRecommendation(String food) {
    switch (food) {
      case 'قوزي عراقي':
        return 'قوزي عراقي معدل! يذوب بحلكك ويسر خاطر كلبك اليوم';
      case 'برجر فحم':
        return 'برجر على الفحم! جبنة سايحة وطعم يفوتك اليوم عيوني';
      case 'شاورما دجاج':
        return 'لفة شاورما دجاج ويا الثومية المظبوطة! تغسل الكلب غسل';
      case 'كباب عراقي':
        return 'كباب عراقي حار ويا الخبز الحار والبصل! طعم الأصالة';
      case 'بيتزا إيطالية':
        return 'بيتزا إيطالية مليانة جبنة ومكسبات طعم خرافية اليوم';
      case 'فلافل مشكل':
        return 'لفة فلافل مشكل دافية من قلب القائم! رخيصة وطيبة ولذيذة';
      case 'سمك مسكوف':
        return 'سمك مسكوف عراقي مشوي على الحطب! فد شي فاخر';
      case 'منسف لحم':
        return 'منسف لحم أردني وعراقي فاخر! يعبي الراس والمعدة';
      case 'كنافة نابلسية':
        return 'كنافة نابلسية دافية وطعم جبنة خيالي يذوب بالقلب';
      case 'كريب نوتيلا':
        return 'كريب مليان نوتيلا غنية وفواكه طازجة تسعد يومك';
      case 'وافل فواكه':
        return 'وافل مقرمش ومغطى بالكراميل والشوكولاتة مع الفواكه';
      case 'كيكة الشوكولاتة':
        return 'قطعة كيكة الشوكولاتة الهشة والغنية لعشاق السعادة';
      case 'عصير كوكتيل':
        return 'كوب عصير كوكتيل طازج ومنعش يروي عطشك اليوم';
      case 'موهيتو رمان':
        return 'موهيتو رمان مثلج وبارد مع النعناع والليمون المنعش';
      case 'عصير مانجو طبيعي':
        return 'عصير مانجو طبيعي مكثف وبارد يملأ يومك بالانتعاش';
      case 'ميلك شيك أوريو':
        return 'ميلك شيك أوريو بالكريمة والشوكولاتة لعشاق اللذاذة';
      default:
        return 'أكلة $food طيبة ولذيذة من القائم! جربها اليوم وتدلل عيوني';
    }
  }
}
