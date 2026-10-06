import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'smart_assistant_service.dart';
import 'smart_assistant_config.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'smart_assistant_overlay.dart';
import 'package:dalal_alqaim/pages/cart_page.dart';
import 'ui_scanner.dart';
import 'package:dalal_alqaim/core/app_globals.dart';

// ─────────────────────────────────────────────────
// فئة السمات اللونية الديناميكية المخصصة لكل صفحة
// ─────────────────────────────────────────────────
class SmartAssistantTheme {
  final List<Color> gradientColors;
  final Color glowColor;
  final IconData icon;
  final String label;
  final List<Color> sheetGradient;
  final String title;
  final String subtitle;

  const SmartAssistantTheme({
    required this.gradientColors,
    required this.glowColor,
    required this.icon,
    required this.label,
    required this.sheetGradient,
    required this.title,
    required this.subtitle,
  });

  static SmartAssistantTheme getThemeForRoute(String? route) {
    switch (route) {
      case '/real_estate':
        return const SmartAssistantTheme(
          gradientColors: [Color(0xFFFFB300), Color(0xFFE65100)],
          glowColor: Color(0xFFFFD54F),
          icon: Icons.home_work_rounded,
          label: "سكوزمي العقاري",
          sheetGradient: [Color(0xFF2E1A05), Color(0xFF190D02)],
          title: "سكوزمي العقاري",
          subtitle: "مساعد العقارات الذكي لمدار",
        );
      case '/restaurants':
        return const SmartAssistantTheme(
          gradientColors: [Color(0xFFFF7043), Color(0xFFD84315)],
          glowColor: Color(0xFFFF8A65),
          icon: Icons.restaurant_menu_rounded,
          label: "سكوزمي المطاعم",
          sheetGradient: [Color(0xFF2C0C07), Color(0xFF180503)],
          title: "سكوزمي المطاعم",
          subtitle: "دليلك لأشهى الأكلات والوجبات",
        );
      case '/complaints':
        return const SmartAssistantTheme(
          gradientColors: [Color(0xFFEF5350), Color(0xFFC62828)],
          glowColor: Color(0xFFE57373),
          icon: Icons.feedback_rounded,
          label: "سكوزمي للمساعدة",
          sheetGradient: [Color(0xFF2E0909), Color(0xFF1A0404)],
          title: "سكوزمي للمساعدة",
          subtitle: "صوتك مسموع - هنا للشكاوى والاقتراحات",
        );
      case '/studios':
        return const SmartAssistantTheme(
          gradientColors: [Color(0xFFAB47BC), Color(0xFF6A1B9A)],
          glowColor: Color(0xFFBA68C8),
          icon: Icons.photo_camera_rounded,
          label: "سكوزمي الاستوديو",
          sheetGradient: [Color(0xFF250D2E), Color(0xFF130519)],
          title: "سكوزمي استوديوهات",
          subtitle: "توثيق أجمل لحظاتك مع أفضل المصورين",
        );
      case '/vacancies':
        return const SmartAssistantTheme(
          gradientColors: [Color(0xFF26A69A), Color(0xFF00695C)],
          glowColor: Color(0xFF4DB6AC),
          icon: Icons.business_center_rounded,
          label: "سكوزمي للوظائف",
          sheetGradient: [Color(0xFF071F1E), Color(0xFF03100F)],
          title: "سكوزمي للوظائف",
          subtitle: "مساعدك الذكي لإيجاد ونشر الفرص",
        );
      default:
        return const SmartAssistantTheme(
          gradientColors: [Color(0xFF26A69A), Color(0xFF00796B)],
          glowColor: Color(0xFF4ECCA3),
          icon: Icons.smart_toy_rounded,
          label: "سكوزمي المساعد",
          sheetGradient: [Color(0xFF0A1F20), Color(0xFF071516)],
          title: "سكوزمي",
          subtitle: "مساعد مدار الذكي الشامل",
        );
    }
  }
}

// ─────────────────────────────────────────────────
// زر سكوزمي العائم المطور - زجاجي ومتفاعل مع كل صفحة
// ─────────────────────────────────────────────────
class SmartAssistantFAB extends StatefulWidget {
  const SmartAssistantFAB({super.key});

  /// فتح المساعد الذكي مباشرة مع استعلام أولي اختياري
  static void openAssistant(BuildContext context, {String? initialQuery, bool startVoice = false}) {
    final route = ModalRoute.of(context)?.settings.name;
    final theme = SmartAssistantTheme.getThemeForRoute(route);
    final service = SmartAssistantService();
    
    service.currentRoute = route ?? '/home';

    service.onNavigate = (String targetRoute) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      Future.delayed(const Duration(milliseconds: 280), () {
        final navState = appNavigatorKey.currentState;
        if (navState == null) return;
        
        final current = service.currentRoute;
        
        if (targetRoute == '/home') {
          if (current != '/home' && current != '/' && navState.canPop()) {
            navState.pop();
          }
        } else {
          if (current != '/home' && current != '/' && navState.canPop()) {
            navState.pop();
            Future.delayed(const Duration(milliseconds: 100), () {
              if (targetRoute == '/cart') {
                navState.push(MaterialPageRoute(builder: (context) => const CartPage()));
              } else {
                navState.pushNamed(targetRoute);
              }
            });
          } else {
            if (targetRoute == '/cart') {
              navState.push(MaterialPageRoute(builder: (context) => const CartPage()));
            } else {
              navState.pushNamed(targetRoute);
            }
          }
        }
      });
    };

    if (initialQuery != null && initialQuery.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (context.mounted) {
          service.sendMessage(context, initialQuery);
        }
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => _ExcuseMeChatSheet(
        service: service,
        parentContext: context,
        theme: theme,
        startVoice: startVoice,
      ),
    );
  }

  @override
  State<SmartAssistantFAB> createState() => _SmartAssistantFABState();
}

class _SmartAssistantFABState extends State<SmartAssistantFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  bool _showBadge = false;

  // الإرشادات الترحيبية الدوارة لجذب المستخدمين بشكل تفاعلي
  int _greetingIndex = 0;
  final List<String> _greetings = [
    "سكوزمي المساعد",
    "شلون تسجل مطعمك؟",
    "تحتاج تكسي مدار؟",
    "تبي تشتغل كابتن؟",
    "شنو دروب شوبينج؟",
    "تواصل مع الإدارة",
  ];
  Timer? _greetingTimer;
  Timer? _initialBadgeTimer;
  Timer? _initialHideTimer;
  Timer? _periodicHideTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // تفعيل الملصق الترحيبي المنزلق التلقائي بعد 600 مللي ثانية، وإخفاؤه بعد 4 ثوانٍ
    _initialBadgeTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showBadge = true;
        });
      }
    });

    _initialHideTimer = Timer(const Duration(milliseconds: 4600), () {
      if (mounted) {
        setState(() {
          _showBadge = false;
        });
      }
    });

    // تبديل دوري ذكي للإرشادات التفاعلية كل 12 ثانية
    _greetingTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (mounted) {
        setState(() {
          _greetingIndex = (_greetingIndex + 1) % _greetings.length;
          _showBadge = true;
        });
        _periodicHideTimer?.cancel();
        _periodicHideTimer = Timer(const Duration(milliseconds: 4500), () {
          if (mounted) {
            setState(() {
              _showBadge = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _initialBadgeTimer?.cancel();
    _initialHideTimer?.cancel();
    _periodicHideTimer?.cancel();
    _greetingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name;
    final theme = SmartAssistantTheme.getThemeForRoute(route);

    // اختيار الإرشادات المناسبة حسب الصفحة الحالية لجعلها شديدة الذكاء والتخصص
    List<String> currentGreetings = _greetings;
    if (route == '/restaurants') {
      currentGreetings = [
        "سكوزمي المطاعم",
        "ابحث عن برجر لحم",
        "تصفح قسم الحلويات",
        "تصفح قسم العصائر",
      ];
    } else if (route == '/vacancies') {
      currentGreetings = [
        "سكوزمي للوظائف",
        "عرض وظائف تقنية",
        "عرض وظائف تعليمية",
        "انشر وظيفة جديدة",
      ];
    } else if (route == '/complaints') {
      currentGreetings = [
        "سكوزمي للمساعدة",
        "تقديم شكوى جديدة",
        "تقديم اقتراح للتطوير",
      ];
    }

    final displayGreeting = currentGreetings[_greetingIndex % currentGreetings.length];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // الملصق الترحيبي المنزلق الجذاب
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.only(left: _showBadge ? 8 : 0),
            width: _showBadge ? 160 : 0,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.glowColor.withValues(alpha: 0.9),
                  theme.gradientColors[0].withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.glowColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showBadge ? 1.0 : 0.0,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      displayGreeting,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // زر سكوزمي بمظهره النيوني المتوهج والمتحرك (Dynamic Glow AI Orb)
          GestureDetector(
            onTap: () => _openChat(context, theme),
            onLongPress: () {
              setState(() {
                _showBadge = !_showBadge;
              });
            },
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseAnim.value * 0.06),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // AI Neon Aura Glow
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              theme.glowColor.withValues(alpha: 0.35 + (_pulseAnim.value * 0.2)),
                              theme.gradientColors[0].withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                            stops: const [0.2, 0.7, 1.0],
                          ),
                        ),
                      ),
                      // Skozmy AI Mascot Asset
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Image.asset(
                            'imges/skozme.png',
                            fit: BoxFit.contain,
                            cacheWidth: 300,
                            cacheHeight: 300,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'imges/scozme.png',
                                fit: BoxFit.contain,
                                cacheWidth: 300,
                                cacheHeight: 300,
                                filterQuality: FilterQuality.medium,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.smart_toy_rounded,
                                  color: theme.glowColor,
                                  size: 48,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      // AI Sparkle Indicator badge on bottom right
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [theme.glowColor, theme.gradientColors[0]],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: theme.glowColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openChat(BuildContext ctx, SmartAssistantTheme theme) {
    SmartAssistantFAB.openAssistant(ctx);
  }
}

// ─────────────────────────────────────────────────
// لوحة محادثة سكوزمي الراقية الملونة ديناميكياً
// ─────────────────────────────────────────────────
class _ExcuseMeChatSheet extends StatefulWidget {
  final SmartAssistantService service;
  final BuildContext parentContext;
  final SmartAssistantTheme theme;
  final bool startVoice;

  const _ExcuseMeChatSheet({
    required this.service,
    required this.parentContext,
    required this.theme,
    this.startVoice = false,
  });

  @override
  State<_ExcuseMeChatSheet> createState() => _ExcuseMeChatSheetState();
}

class _ExcuseMeChatSheetState extends State<_ExcuseMeChatSheet>
    with TickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late AnimationController _typingCtrl;
  late AnimationController _rotationCtrl;

  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _lastWords = '';
  bool _ttsEnabled = true;
  ChatMessage? _lastSpokenMessage;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onUpdate);
    widget.service.onHighlightWidget = _handleWidgetHighlight;
    _inputCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _typingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _initSpeech();
    _initTts();
    _scrollToEnd();

    if (widget.startVoice) {
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) {
          _startListening();
        }
      });
    }
  }

  void _initSpeech() async {
    try {
      await _speechToText.initialize(
        onError: (val) => debugPrint('STT Error: $val'),
        onStatus: (val) => debugPrint('STT Status: $val'),
      );
    } catch (e) {
      debugPrint('Speech init failed: $e');
    }
  }

  void _initTts() async {
    try {
      await _flutterTts.setLanguage("ar");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.85);
    } catch (e) {
      debugPrint('TTS init failed: $e');
      _ttsEnabled = false;
    }
  }

  void _speak(String text) async {
    if (!_ttsEnabled) return;
    try {
      String cleanText = text.replaceAll(RegExp(r'[^\w\s\dأ-يًٌٍَُِّّْْٰٕٓٔإأآءؤئىية]'), ' ').trim();
      if (cleanText.isNotEmpty) {
        await _flutterTts.speak(cleanText);
      }
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  void _startListening() async {
    try {
      final available = await _speechToText.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _lastWords = '';
        });
        await _speechToText.listen(
          onResult: (result) {
            setState(() {
              _lastWords = result.recognizedWords;
              _inputCtrl.text = _lastWords;
            });
          },
          listenOptions: SpeechListenOptions(cancelOnError: true),
        );
      }
    } catch (e) {
      debugPrint('Start listening failed: $e');
    }
  }

  void _stopListening() async {
    try {
      await _speechToText.stop();
      setState(() {
        _isListening = false;
      });
      if (_inputCtrl.text.isNotEmpty) {
        _send();
      }
    } catch (e) {
      debugPrint('Stop listening failed: $e');
    }
  }

  void _handleWidgetHighlight(String target) {
    final parentCtx = widget.parentContext;
    Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!parentCtx.mounted) return;
      final rect = UIScanner.findElementRect(parentCtx, target);
      if (rect != null) {
        SmartAssistantOverlayManager.show(
          parentCtx,
          rect,
          'هنا حبيبي، اضغط على هذا العنصر!',
        );
      } else {
        ScaffoldMessenger.of(parentCtx).showSnackBar(
          SnackBar(
            content: Text('بحثت عن "$target" على الشاشة بس ما لكيته.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    widget.service.removeListener(_onUpdate);
    widget.service.onHighlightWidget = null;
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _typingCtrl.dispose();
    _rotationCtrl.dispose();
    try {
      _speechToText.stop().catchError((e) {
        debugPrint('STT stop in dispose failed: $e');
      });
    } catch (e) {
      debugPrint('STT stop in dispose failed: $e');
    }
    try {
      _flutterTts.stop().catchError((e) {
        debugPrint('TTS stop in dispose failed: $e');
      });
    } catch (e) {
      debugPrint('TTS stop in dispose failed: $e');
    }
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) {
      setState(() {});
      _scrollToEnd();
      if (widget.service.messages.isNotEmpty) {
        final lastMsg = widget.service.messages.last;
        if (!lastMsg.isUser && _lastSpokenMessage != lastMsg) {
          _lastSpokenMessage = lastMsg;
          _speak(lastMsg.text);
        }
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    widget.service.sendMessage(widget.parentContext, text);
  }

  void _sendQuick(String prompt) {
    widget.service.sendQuickAction(widget.parentContext, prompt);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        color: const Color(0xFF081C1E),
        child: Column(
          children: [
            _buildHeader(),
            if (widget.service.isProcessing)
              _AIProgressBar(theme: widget.theme),
            Expanded(child: _buildChatArea()),
            if (!widget.service.isProcessing &&
                widget.service.messages.isEmpty)
              _buildWelcomeHints(),
            if (!widget.service.isProcessing &&
                widget.service.messages.isNotEmpty)
              _buildQuickActions(),
            _buildInputBar(bottomInset),
          ],
        ),
      ),
    );
  }

  // ─── الترويسة الحديثة ───
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E282B),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // مقبض السحب
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                // أفاتار سكوزمي مع هالة نيون دوارة
                Stack(
                  alignment: Alignment.center,
                  children: [
                    RotationTransition(
                      turns: _rotationCtrl,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              widget.theme.gradientColors[0],
                              widget.theme.glowColor,
                              widget.theme.gradientColors[1],
                              widget.theme.gradientColors[0],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E282B),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.theme.glowColor.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Image.asset(
                        'imges/skozme.png',
                        fit: BoxFit.contain,
                        cacheWidth: 140,
                        cacheHeight: 140,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: widget.theme.gradientColors[1]
                                .withValues(alpha: 0.3),
                            child: Icon(
                              widget.theme.icon,
                              color: widget.theme.glowColor,
                              size: 16,
                            ),
                          );
                        },
                      ),
                    ),
                    // نقطة الحالة
                    Positioned(
                      bottom: 1,
                      right: 1,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: widget.service.isProcessing
                              ? Colors.amber
                              : const Color(0xFF00E676),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0D1117),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // الاسم والحالة
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.theme.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          if (widget.service.isProcessing)
                            _ThinkingDots(theme: widget.theme),
                          Text(
                            widget.service.isProcessing
                                ? 'يفكر...'
                                : widget.theme.subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.service.isProcessing
                                  ? widget.theme.glowColor
                                  : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // أزرار الترويسة
                _HeaderIconBtn(
                  icon: _ttsEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: _ttsEnabled
                      ? widget.theme.glowColor
                      : Colors.white30,
                  onTap: () {
                    setState(() {
                      _ttsEnabled = !_ttsEnabled;
                      if (!_ttsEnabled) {
                        try {
                          _flutterTts.stop().catchError((e) {
                            debugPrint('TTS stop toggle failed: $e');
                          });
                        } catch (e) {
                          debugPrint('TTS stop toggle failed: $e');
                        }
                      }
                    });
                  },
                ),
                _HeaderIconBtn(
                  icon: Icons.delete_outline_rounded,
                  color: Colors.white30,
                  onTap: () => widget.service.clearChat(),
                ),
                const SizedBox(width: 4),
                _HeaderIconBtn(
                  icon: Icons.close_rounded,
                  color: Colors.white54,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── منطقة المحادثة ───
  Widget _buildChatArea() {
    if (widget.service.messages.isEmpty && !widget.service.isProcessing) {
      return _buildEmptyState();
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      itemCount: widget.service.messages.length +
          (widget.service.isProcessing ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.service.messages.length) {
          return _buildTypingIndicator();
        }
        return _buildMessage(widget.service.messages[index]);
      },
    );
  }

  // ─── شاشة الترحيب الفارغة ───
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: _rotationCtrl,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        widget.theme.gradientColors[0].withValues(alpha: 0.5),
                        widget.theme.glowColor.withValues(alpha: 0.3),
                        widget.theme.gradientColors[1].withValues(alpha: 0.5),
                        widget.theme.gradientColors[0].withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 90,
                height: 90,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.asset(
                    'imges/skozme.png',
                    fit: BoxFit.contain,
                    cacheWidth: 320,
                    cacheHeight: 320,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (c, e, s) => Icon(
                      widget.theme.icon,
                      color: widget.theme.glowColor,
                      size: 44,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'مرحباً! أنا ${widget.theme.title}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'كيف أقدر أساعدك اليوم؟',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  // ─── رسالة واحدة ───
  Widget _buildMessage(ChatMessage msg) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: msg.isUser ? _buildUserBubble(msg) : _buildBotMessage(msg),
    );
  }

  // ─── رسالة المستخدم (فقاعة مدمجة) ───
  Widget _buildUserBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // أفاتار المستخدم
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.theme.gradientColors[0].withValues(alpha: 0.2),
              border: Border.all(
                color: widget.theme.gradientColors[0].withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.person_rounded,
                color: Colors.white60,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.70,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.theme.gradientColors[0],
                    widget.theme.gradientColors[1].withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.55,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── رسالة البوت (عرض كامل مثل ChatGPT) ───
  Widget _buildBotMessage(ChatMessage msg) {
    final hasAction = msg.actionType != null && msg.actionType!.isNotEmpty;

    // تحديد بيانات الإجراء التفاعلي
    String? badgeText;
    IconData? badgeIcon;
    if (hasAction) {
      switch (msg.actionType) {
        case 'navigate':
          badgeText = 'اضغط للانتقال';
          badgeIcon = Icons.open_in_new_rounded;
          break;
        case 'launch_whatsapp':
          badgeText = 'تواصل عبر واتساب';
          badgeIcon = Icons.chat_rounded;
          break;
        case 'fetch_sections':
          badgeText = 'تصفح الأقسام';
          badgeIcon = Icons.category_rounded;
          break;
        case 'confirm_order':
          badgeText = 'تأكيد الطلب (نقداً كاش)';
          badgeIcon = Icons.check_circle_rounded;
          break;
        default:
          badgeText = 'تشغيل الإجراء';
          badgeIcon = Icons.play_arrow_rounded;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      decoration: BoxDecoration(
        color: const Color(0xFF13363A),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // محتوى الرسالة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // نص الرسالة بتنسيق Markdown
                _MarkdownTextWidget(
                  text: msg.text,
                  theme: widget.theme,
                ),
                // كرت الإجراء التفاعلي
                if (hasAction && badgeText != null)
                  _buildBentoActionCard(
                      msg, badgeText, badgeIcon ?? Icons.play_arrow_rounded),
                const SizedBox(height: 6),
                // شريط الأزرار التفاعلية
                _buildMessageActions(msg),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // أفاتار سكوزمي
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              width: 30,
              height: 30,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFF0E282B),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.theme.glowColor.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Image.asset(
                'imges/skozme.png',
                fit: BoxFit.contain,
                cacheWidth: 100,
                cacheHeight: 100,
                filterQuality: FilterQuality.medium,
                errorBuilder: (c, e, s) => Container(
                  color: widget.theme.gradientColors[1]
                      .withValues(alpha: 0.3),
                  child: Icon(
                    widget.theme.icon,
                    color: widget.theme.glowColor,
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── أزرار التفاعل أسفل رسالة البوت ───
  Widget _buildMessageActions(ChatMessage msg) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _MsgActionBtn(
          icon: Icons.copy_rounded,
          label: 'نسخ',
          onTap: () {
            Clipboard.setData(ClipboardData(text: msg.text));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'تم نسخ الرد',
                  style: TextStyle(),
                ),
                backgroundColor: widget.theme.gradientColors[0],
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ),
        const SizedBox(width: 4),
        _MsgActionBtn(
          icon: Icons.volume_up_rounded,
          label: 'قراءة',
          onTap: () => _speak(msg.text),
        ),
        const Spacer(),
        // الوقت
        Text(
          '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }

  Widget _buildBentoActionCard(ChatMessage msg, String title, IconData icon) {
    return _BentoActionCardWidget(
      title: title,
      icon: icon,
      theme: widget.theme,
      onTap: () => widget.service
          .executeActionCommand(msg.actionType!, msg.actionData ?? ''),
    );
  }

  // ─── مؤشر الكتابة الحديث ───
  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF13363A),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // أيقونة التفكير
                AnimatedBuilder(
                  animation: _typingCtrl,
                  builder: (_, __) {
                    return Transform.scale(
                      scale: 0.9 + (_typingCtrl.value * 0.15),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: widget.theme.glowColor
                            .withValues(alpha: 0.5 + (_typingCtrl.value * 0.5)),
                        size: 18,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Text(
                  'سكوزمي يفكر',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 3),
                // ثلاث نقاط متحركة
                AnimatedBuilder(
                  animation: _typingCtrl,
                  builder: (_, __) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        final delay = i * 0.18;
                        final t = ((_typingCtrl.value + delay) % 1.0);
                        return Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Opacity(
                            opacity: (t < 0.5 ? t * 2 : (1 - t) * 2)
                                .clamp(0.3, 1.0),
                            child: Text(
                              '.',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: widget.theme.glowColor,
                                height: 0.5,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 30,
            height: 30,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF0E282B),
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.theme.glowColor.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: Image.asset(
              'imges/skozme.png',
              fit: BoxFit.contain,
              cacheWidth: 100,
              cacheHeight: 100,
              filterQuality: FilterQuality.medium,
              errorBuilder: (c, e, s) => Icon(
                widget.theme.icon,
                color: widget.theme.glowColor,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── اقتراحات ترحيبية ───
  Widget _buildWelcomeHints() {
    final actions = _getPageQuickActions();
    if (actions.isEmpty) return const SizedBox.shrink();
    final hints = actions.take(4).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: hints.map((a) {
          return GestureDetector(
            onTap: () => _sendQuick(a['prompt']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    a['icon'] as IconData,
                    size: 15,
                    color: widget.theme.glowColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      a['label'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _getPageQuickActions() {
    final route = ModalRoute.of(widget.parentContext)?.settings.name;
    switch (route) {
      case '/restaurants':
        return [
          {
            'icon': Icons.restaurant_menu_rounded,
            'label': 'بحث برجر',
            'prompt': 'ابحثلي عن برجر لحم في المطاعم',
          },
          {
            'icon': Icons.cake_rounded,
            'label': 'الحلويات',
            'prompt': 'عرض قسم الحلويات بالمطاعم',
          },
          {
            'icon': Icons.local_drink_rounded,
            'label': 'العصائر',
            'prompt': 'عرض قسم العصائر بالمطاعم',
          },
          {
            'icon': Icons.home_rounded,
            'label': 'أكلات منزلية',
            'prompt': 'عرض الأكلات المنزلية بالمطاعم',
          },
        ];
      case '/vacancies':
        return [
          {
            'icon': Icons.computer_rounded,
            'label': 'وظائف تقنية',
            'prompt': 'عرض وظائف قسم تقنية',
          },
          {
            'icon': Icons.school_rounded,
            'label': 'وظائف تعليمية',
            'prompt': 'عرض وظائف قسم تعليم',
          },
          {
            'icon': Icons.business_center_rounded,
            'label': 'فرص عمل',
            'prompt': 'عرض فرص العمل المتاحة',
          },
          {
            'icon': Icons.people_rounded,
            'label': 'باحثين عن عمل',
            'prompt': 'عرض طلبات الباحثين عن عمل',
          },
          {
            'icon': Icons.add_circle_outline_rounded,
            'label': 'نشر وظيفة جديدة',
            'prompt': 'أريد نشر وظيفة جديدة',
          },
        ];
      case '/complaints':
        return [
          {
            'icon': Icons.feedback_rounded,
            'label': 'تقديم شكوى',
            'prompt': 'أريد تقديم شكوى على تأخر سائق التاكسي',
          },
          {
            'icon': Icons.lightbulb_rounded,
            'label': 'تقديم اقتراح',
            'prompt': 'أريد تقديم اقتراح لتطوير التطبيق',
          },
          {
            'icon': Icons.search_rounded,
            'label': 'بحث بالشكاوى',
            'prompt': 'ابحث لي في الشكاوى',
          },
          {
            'icon': Icons.hourglass_empty_rounded,
            'label': 'شكاوى قيد المراجعة',
            'prompt': 'عرض الشكاوى التي بحالة قيد المراجعة',
          },
        ];
      case '/studios':
        return [
          {
            'icon': Icons.celebration_rounded,
            'label': 'استوديو زفاف',
            'prompt': 'أريد استوديو تصوير زفاف',
          },
          {
            'icon': Icons.face_rounded,
            'label': 'استوديو أطفال',
            'prompt': 'ابحث لي عن استوديو تصوير أطفال',
          },
          {
            'icon': Icons.photo_camera_rounded,
            'label': 'استوديو بورتريه',
            'prompt': 'أريد استوديو تصوير بورتريه',
          },
          {
            'icon': Icons.add_a_photo_rounded,
            'label': 'إضافة استوديو',
            'prompt': 'أريد إضافة استوديو جديد',
          },
        ];
      default:
        return SmartAssistantConfig.quickActions;
    }
  }

  // ─── الإجراءات السريعة ───
  Widget _buildQuickActions() {
    final actions = _getPageQuickActions();
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return _QuickActionButton(
            action: action,
            theme: widget.theme,
            onTap: () => _sendQuick(action['prompt']),
          );
        },
      ),
    );
  }

  // ─── حقل الإدخال العصري فائق الوضوح ───
  Widget _buildInputBar(double bottomInset) {
    final hasText = _inputCtrl.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, bottomInset + 12),
      decoration: BoxDecoration(
        color: const Color(0xFF07191B),
        border: Border(
          top: BorderSide(
            color: widget.theme.glowColor.withValues(alpha: 0.2),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // زر المايكروفون الصوتي
          GestureDetector(
            onLongPressStart: (_) => _startListening(),
            onLongPressEnd: (_) => _stopListening(),
            onTap: () {
              if (_isListening) {
                _stopListening();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF0E282B),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    content: const Row(
                      children: [
                        Icon(Icons.mic_rounded, color: Color(0xFF14B8A6), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'اضغط مطولاً للتحدث بالصوت ويا سكوزمي',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: _VoicePulsingButton(
              isListening: _isListening,
              theme: widget.theme,
            ),
          ),
          const SizedBox(width: 10),
          // شريط الكتابة المريح وواضح التباين
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF0D282D),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: hasText
                      ? widget.theme.glowColor
                      : widget.theme.glowColor.withValues(alpha: 0.35),
                  width: hasText ? 1.6 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.theme.glowColor.withValues(alpha: hasText ? 0.12 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: widget.theme.glowColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      cursorColor: widget.theme.glowColor,
                      cursorWidth: 2.2,
                      cursorRadius: const Radius.circular(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                      textDirection: TextDirection.rtl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      enabled: !widget.service.isProcessing,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'احچي ويا سكوزمي بالعراقي...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13.5,
                          fontWeight: FontWeight.normal,
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (hasText)
                    IconButton(
                      icon: const Icon(Icons.cancel_rounded, color: Colors.white70, size: 18),
                      splashRadius: 16,
                      onPressed: () {
                        _inputCtrl.clear();
                        setState(() {});
                      },
                    )
                  else
                    const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // زر الإرسال المتوهج
          _SendButton(
            isProcessing: widget.service.isProcessing,
            theme: widget.theme,
            onTap: widget.service.isProcessing ? () {} : _send,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// ويدجت عرض نص Markdown المتقدم
// ═══════════════════════════════════════════════════
class _MarkdownTextWidget extends StatelessWidget {
  final String text;
  final SmartAssistantTheme theme;

  const _MarkdownTextWidget({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final List<Widget> children = [];
    bool inCodeBlock = false;
    List<String> codeLines = [];
    String codeLang = '';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // كتلة كود
      if (line.trimLeft().startsWith('```')) {
        if (inCodeBlock) {
          children.add(_buildCodeBlock(codeLines.join('\n'), codeLang, context));
          codeLines = [];
          codeLang = '';
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
          codeLang = line.trimLeft().substring(3).trim();
        }
        continue;
      }

      if (inCodeBlock) {
        codeLines.add(line);
        continue;
      }

      // سطر فارغ
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }

      // عنوان
      if (line.startsWith('### ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            line.substring(4),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.5,
            ),
            textDirection: TextDirection.rtl,
          ),
        ));
      } else if (line.startsWith('## ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            line.substring(3),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.5,
            ),
            textDirection: TextDirection.rtl,
          ),
        ));
      } else if (line.startsWith('# ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            line.substring(2),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: theme.glowColor,
              height: 1.5,
            ),
            textDirection: TextDirection.rtl,
          ),
        ));
      }
      // قائمة نقطية
      else if (line.trimLeft().startsWith('- ') ||
          line.trimLeft().startsWith('• ') ||
          line.trimLeft().startsWith('* ')) {
        final bulletText =
            line.trimLeft().substring(2);
        children.add(_buildBulletItem(bulletText, '•'));
      }
      // قائمة مرقمة
      else if (RegExp(r'^\s*\d+[\.\)]\s').hasMatch(line)) {
        final match = RegExp(r'^\s*(\d+)[\.\)]\s(.*)').firstMatch(line);
        if (match != null) {
          children.add(_buildBulletItem(match.group(2)!, '${match.group(1)}.'));
        }
      }
      // نص عادي مع تنسيق inline
      else {
        children.add(_buildRichParagraph(line));
      }
    }

    // إغلاق كتلة كود مفتوحة
    if (inCodeBlock && codeLines.isNotEmpty) {
      children.add(_buildCodeBlock(codeLines.join('\n'), codeLang, context));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildBulletItem(String text, String bullet) {
    return Padding(
      padding: const EdgeInsets.only(right: 4, top: 3, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: TextDirection.rtl,
        children: [
          Text(
            bullet,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.glowColor,
              height: 1.65,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildRichParagraph(text)),
        ],
      ),
    );
  }

  Widget _buildRichParagraph(String text) {
    return Text.rich(
      _parseInlineMarkdown(text),
      textDirection: TextDirection.rtl,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFFE6EDF3),
        height: 1.65,
      ),
    );
  }

  TextSpan _parseInlineMarkdown(String text) {
    final List<InlineSpan> spans = [];
    final regex = RegExp(
      r'(\*\*\*.+?\*\*\*|\*\*.+?\*\*|\*.+?\*|`.+?`)',
    );

    int lastIndex = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }
      final m = match.group(0)!;
      if (m.startsWith('***') && m.endsWith('***')) {
        // Bold italic
        spans.add(TextSpan(
          text: m.substring(3, m.length - 3),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            color: theme.glowColor,
          ),
        ));
      } else if (m.startsWith('**') && m.endsWith('**')) {
        // Bold
        spans.add(TextSpan(
          text: m.substring(2, m.length - 2),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ));
      } else if (m.startsWith('*') && m.endsWith('*')) {
        // Italic
        spans.add(TextSpan(
          text: m.substring(1, m.length - 1),
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Color(0xFFB0C4DE),
          ),
        ));
      } else if (m.startsWith('`') && m.endsWith('`')) {
        // Inline code
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              m.substring(1, m.length - 1),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF79C0FF),
              ),
            ),
          ),
        ));
      }
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    if (spans.isEmpty) {
      return TextSpan(text: text);
    }

    return TextSpan(children: spans);
  }

  Widget _buildCodeBlock(String code, String lang, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // شريط عنوان الكود
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: Row(
              children: [
                if (lang.isNotEmpty)
                  Text(
                    lang,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'تم نسخ الكود',
                          style: TextStyle(),
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'نسخ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // محتوى الكود
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFFE6EDF3),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// زر إجراء على الرسالة (نسخ، قراءة)
// ═══════════════════════════════════════════════════
class _MsgActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MsgActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white38),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// زر أيقونة الترويسة
// ═══════════════════════════════════════════════════
class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HeaderIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// نقاط التفكير المتحركة في الترويسة
// ═══════════════════════════════════════════════════
class _ThinkingDots extends StatefulWidget {
  final SmartAssistantTheme theme;
  const _ThinkingDots({required this.theme});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = ((_ctrl.value + delay) % 1.0);
            final scale = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.5, 1.0);
            return Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.theme.glowColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════
// شريط التقدم النيوني المتحرك
// ═══════════════════════════════════════════════════
class _AIProgressBar extends StatefulWidget {
  final SmartAssistantTheme theme;
  const _AIProgressBar({required this.theme});

  @override
  State<_AIProgressBar> createState() => _AIProgressBarState();
}

class _AIProgressBarState extends State<_AIProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 2,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_controller.value * 4 - 2, 0),
              end: Alignment(_controller.value * 4 - 1, 0),
              colors: [
                Colors.transparent,
                widget.theme.glowColor.withValues(alpha: 0.8),
                widget.theme.gradientColors[0],
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════
// كرت الإجراء التفاعلي (Bento Action Card)
// ═══════════════════════════════════════════════════
class _BentoActionCardWidget extends StatefulWidget {
  final String title;
  final IconData icon;
  final SmartAssistantTheme theme;
  final VoidCallback onTap;

  const _BentoActionCardWidget({
    required this.title,
    required this.icon,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_BentoActionCardWidget> createState() => _BentoActionCardWidgetState();
}

class _BentoActionCardWidgetState extends State<_BentoActionCardWidget> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: widget.theme.gradientColors[0].withValues(alpha: 0.12),
            border: Border.all(
              color: widget.theme.glowColor.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: widget.theme.glowColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.theme.glowColor,
                  size: 15,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.theme.glowColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_left_rounded,
                size: 16,
                color: widget.theme.glowColor.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// زر خيار سريع
// ═══════════════════════════════════════════════════
class _QuickActionButton extends StatefulWidget {
  final Map<String, dynamic> action;
  final SmartAssistantTheme theme;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.action,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.94),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.action['icon'] as IconData,
                size: 14,
                color: widget.theme.glowColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                widget.action['label'],
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// زر المايكروفون النابض
// ═══════════════════════════════════════════════════
class _VoicePulsingButton extends StatefulWidget {
  final bool isListening;
  final SmartAssistantTheme theme;
  const _VoicePulsingButton({required this.isListening, required this.theme});

  @override
  State<_VoicePulsingButton> createState() => _VoicePulsingButtonState();
}

class _VoicePulsingButtonState extends State<_VoicePulsingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isListening) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _VoicePulsingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isListening && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isListening)
              Container(
                width: 40 * _pulse.value,
                height: 40 * _pulse.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.2 * (1.3 - _pulse.value)),
                ),
              ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isListening
                    ? Colors.red.withValues(alpha: 0.15)
                    : const Color(0xFF161B22),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isListening
                      ? Colors.red
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(
                widget.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: widget.isListening ? Colors.red : Colors.white54,
                size: 19,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════
// زر الإرسال
// ═══════════════════════════════════════════════════
class _SendButton extends StatefulWidget {
  final bool isProcessing;
  final SmartAssistantTheme theme;
  final VoidCallback onTap;

  const _SendButton({
    required this.isProcessing,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.93),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: widget.isProcessing
                ? null
                : LinearGradient(colors: widget.theme.gradientColors),
            color: widget.isProcessing
                ? Colors.white.withValues(alpha: 0.04)
                : null,
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.isProcessing
                ? Icons.hourglass_top_rounded
                : Icons.arrow_upward_rounded,
            color: widget.isProcessing ? Colors.white24 : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
