import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// النوايا المعرفة للمستخدم في تطبيق مدار
enum UserIntent {
  navigate, // التنقل بين الصفحات
  search, // البحث عن محتوى
  filter, // الفلترة
  sort, // التترتيب
  add, // إضافة عنصر جديد
  order, // طلب وجبة طعام
  register, // تسجيل شريك (مطعم/كابتن)
  editProfile, // تعديل الملف الشخصي
  trackOrder, // تتبع الطلبات
  contactSupport, // الدعم الفني
  info, // الاستفسار عن معلومات
  highlight, // تسليط الضوء
  greeting, // التحية والترحيب
  unknown, // غير معروف
}

/// تعريف هيكل الكيانات المرن للتنقل والوصول السريع
class EntityDefinition {
  final String route;
  final List<String> aliases;

  const EntityDefinition({
    required this.route,
    required this.aliases,
  });
}

/// كلاس حفظ سياق المحادثة المترابطة
class ConversationContext {
  String? lastEntity;
  String? lastRoute;
  UserIntent? lastIntent;
  String? lastSearchQuery;
  String? lastSentiment; // 'happy', 'sad_angry', 'neutral'
  DateTime? lastInteraction;

  ConversationContext({
    this.lastEntity,
    this.lastRoute,
    this.lastIntent,
    this.lastSearchQuery,
    this.lastSentiment = 'neutral',
    this.lastInteraction,
  });

  void update({
    String? entity,
    String? route,
    UserIntent? intent,
    String? searchQuery,
    String? sentiment,
  }) {
    if (entity != null) lastEntity = entity;
    if (route != null) lastRoute = route;
    if (intent != null) lastIntent = intent;
    if (searchQuery != null) lastSearchQuery = searchQuery;
    if (sentiment != null) lastSentiment = sentiment;
    lastInteraction = DateTime.now();
  }

  void checkExpiry() {
    final now = DateTime.now();
    if (lastInteraction != null && now.difference(lastInteraction!).inMinutes > 5) {
      lastEntity = null;
      lastRoute = null;
      lastIntent = null;
      lastSearchQuery = null;
      lastSentiment = 'neutral';
    }
  }
}

/// كلاس لتسجيل العبارات غير المفهومة محلياً في الهاتف
class UnrecognizedPhrasesLogger {
  static Future<void> log(String phrase) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/unrecognized_phrases.json');
      List<Map<String, dynamic>> list = [];
      
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = json.decode(content);
        if (decoded is List) {
          list = List<Map<String, dynamic>>.from(decoded);
        }
      }

      // التحقق من وجود العبارة مسبقاً لمنع التكرار
      final bool alreadyExists = list.any((item) => item['text'] == phrase);
      if (!alreadyExists) {
        list.add({
          'text': phrase,
          'date': DateTime.now().toIso8601String().substring(0, 10),
        });
        await file.writeAsString(json.encode(list), flush: true);
        debugPrint('Logged unrecognized phrase locally: $phrase');
      }
    } catch (e) {
      debugPrint('Error logging unrecognized phrase: $e');
    }
  }
}

/// محرك اللغة الطبيعية المحلي للهجة العراقية - سكوزمي أوفلاين المطور
class IraqiNLPEngine {
  static Map<String, dynamic>? _rawDict;
  static bool isLoaded = false;
  static bool isLearning = false;
  static String learningPhrase = '';
  static Map<String, String> _learnedPhrases = {};
  
  // سياق المحادثة الحالي
  static final ConversationContext context = ConversationContext();

  // تحميل القاموس الخارجي JSON
  static Future<void> loadDictionary() async {
    if (isLoaded) return;
    try {
      final jsonStr = await rootBundle.loadString('assets/ai/iraqi_dictionary.json');
      _rawDict = json.decode(jsonStr);
      isLoaded = true;
      debugPrint('Iraqi dictionary JSON loaded successfully from assets.');
    } catch (e) {
      debugPrint('Error loading iraqi_dictionary.json: $e. Using local fallbacks.');
      _rawDict = null;
      isLoaded = true;
    }
  }

  // تحميل العبارات المتعلمة من التخزين المحلي
  static Future<void> loadLearnedPhrases() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/learned_phrases.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = json.decode(content);
        if (decoded is Map<String, dynamic>) {
          _learnedPhrases = decoded.map((k, v) => MapEntry(k, v.toString()));
          debugPrint('Loaded ${_learnedPhrases.length} learned phrases.');
        }
      }
    } catch (e) {
      debugPrint('Error loading learned phrases: $e');
    }
  }

  // حفظ العبارات المتعلمة محلياً في الهاتف
  static Future<void> saveLearnedPhrase(String phrase, String route) async {
    try {
      _learnedPhrases[normalizeIraqi(phrase)] = route;
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/learned_phrases.json');
      await file.writeAsString(json.encode(_learnedPhrases), flush: true);
      debugPrint('Saved learned phrase locally: $phrase -> $route');
    } catch (e) {
      debugPrint('Error saving learned phrase: $e');
    }
  }

  // الحصول على بدائل الكيانات ديناميكياً كخريطة أوزان
  static Map<String, int> _getEntityAliases(String key) {
    if (_rawDict != null && _rawDict!['entities'] != null && _rawDict!['entities'][key] != null) {
      final Map<String, dynamic> rawMap = _rawDict!['entities'][key]['aliases'] ?? {};
      return rawMap.map((k, v) => MapEntry(k, v as int));
    }
    return _fallbackEntities[key]?['aliases'] ?? {};
  }

  // الحصول على مسار الكيان ديناميكياً
  static String _getEntityRoute(String key) {
    if (_rawDict != null && _rawDict!['entities'] != null && _rawDict!['entities'][key] != null) {
      return _rawDict!['entities'][key]['route'] ?? '';
    }
    return _fallbackEntities[key]?['route'] ?? '';
  }

  // الحصول على كلمات النوايا ديناميكياً كخريطة أوزان
  static Map<String, int> _getIntentKeywords(UserIntent intent) {
    final intentName = intent.name;
    if (_rawDict != null && _rawDict!['intents'] != null && _rawDict!['intents'][intentName] != null) {
      final Map<String, dynamic> rawMap = _rawDict!['intents'][intentName] ?? {};
      return rawMap.map((k, v) => MapEntry(k, v as int));
    }
    return _fallbackIntents[intent] ?? {};
  }

  // الحصول على كلمات المشاعر ديناميكياً
  static List<String> _getSentimentKeywords(String sentiment) {
    if (_rawDict != null && _rawDict!['sentiment'] != null && _rawDict!['sentiment'][sentiment] != null) {
      return List<String>.from(_rawDict!['sentiment'][sentiment]);
    }
    return _fallbackSentiments[sentiment] ?? [];
  }

  // الحصول على الردود ديناميكياً
  static List<String> _getResponses(String key) {
    if (_rawDict != null && _rawDict!['responses'] != null && _rawDict!['responses'][key] != null) {
      return List<String>.from(_rawDict!['responses'][key]);
    }
    return _fallbackResponses[key] ?? ['تدلل عيوني!'];
  }

  /// اختيار رد عشوائي من القائمة لتجنب التكرار الرتيب
  static String randomResponse(String key) {
    final list = _getResponses(key);
    if (list.isEmpty) return 'تدلل عيوني!';
    return list[Random().nextInt(list.length)];
  }

  /// حساب تشابه خوارزمية ليفنشتاين Levenshtein Similarity
  static double calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final int l1 = s1.length;
    final int l2 = s2.length;
    final int diff = (l1 - l2).abs();
    final int maxLen = max(l1, l2);
    final double maxPossibleSimilarity = 1.0 - (diff / maxLen);
    if (maxPossibleSimilarity < 0.85) {
      return maxPossibleSimilarity;
    }

    int m = s1.length;
    int n = s2.length;
    List<List<int>> dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (s1.codeUnitAt(i - 1) == s2.codeUnitAt(j - 1)) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + min(dp[i - 1][j - 1], min(dp[i - 1][j], dp[i][j - 1]));
        }
      }
    }

    int distance = dp[m][n];
    return 1.0 - (distance / maxLen);
  }

  /// مطابقة مرنة (Fuzzy Match) للكلمات المفتاحية
  static bool hasMatch(String text, String keyword) {
    final normText = normalizeIraqi(text);
    final normKw = normalizeIraqi(keyword);
    
    // مطابقة تامة
    if (normText.contains(normKw)) return true;

    // مطابقة مرنة على مستوى الكلمات
    if (normKw.contains(' ')) {
      // للمطالب التي تحتوي على مسافات (مركبة)
      final textWords = normText.split(' ');
      final kwWords = normKw.split(' ');
      if (textWords.length >= kwWords.length) {
        for (int i = 0; i <= textWords.length - kwWords.length; i++) {
          final subPhrase = textWords.sublist(i, i + kwWords.length).join(' ');
          if (calculateSimilarity(subPhrase, normKw) >= 0.85) {
            return true;
          }
        }
      }
    } else {
      // للمطالب المكونة من كلمة واحدة
      final words = normText.split(' ');
      for (final word in words) {
        if (calculateSimilarity(word, normKw) >= 0.85) {
          return true;
        }
      }
    }
    return false;
  }

  /// تنظيف وتطبيع اللهجة العراقية بشكل متقدم
  static String normalizeIraqi(String text) {
    String normalized = text.toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ئ', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ء', '')
        .replaceAll('گ', 'ك')
        .replaceAll('چ', 'ج');

    // إزالة الزوائد مثل "ال" التعريف الذكية
    final List<String> words = normalized.split(' ').map((w) {
      if (w.startsWith('ال') && w.length > 3) {
        return w.substring(2);
      }
      return w;
    }).where((w) => w.trim().isNotEmpty).toList();

    return words.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// إزالة البادئة لسكوزمي أو أي كلمات نداء عراقية شائعة
  static String cleanExcuseMePrefix(String text) {
    String cleaned = text.trim();
    final prefixes = [
      'يا سكوزمي', 'excuse me', 'excuseme', 'يا ولد', 'يا اخوية', 'اخوي', 'حبيبي', 'عيني', 'فدوة'
    ];
    // إزالة النداء إذا كان في البداية
    for (var prefix in prefixes) {
      final normC = cleaned.toLowerCase();
      if (normC.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length).trim();
        break;
      }
    }
    // إزالة كلمة "سكوزمي" المنفردة من أي مكان
    cleaned = cleaned.replaceAll(RegExp(r'\bexcuseme\b|\bexcuse me\b|سكوزمي', caseSensitive: false), '').trim();
    
    if (cleaned.startsWith('و') || cleaned.startsWith('يا')) {
      cleaned = cleaned.substring(2).trim();
    }
    return cleaned;
  }

  /// حل وتوليد الأمر النهائي بناءً على النية والكيان والسياق والطلب
  static String resolveCommand(String rawText, String currentRoute) {
    // 0. تهيئة القاموس إذا لم يكن جاهزاً
    if (!isLoaded) {
      loadDictionary();
    }

    // فحص صلاحية سياق الحديث الأخير ومسحه إذا انتهى
    context.checkExpiry();
    context.lastRoute = currentRoute;

    final cleaned = cleanExcuseMePrefix(rawText);
    final normalized = normalizeIraqi(cleaned);

    // 0.1 التعامل مع وضع التعلم التفاعلي
    if (isLearning) {
      String? matchedRoute;
      String? matchedName;
      
      if (normalized == '1' || normalized.contains('اول واحد') || normalized.contains('مطاعم') || normalized.contains('مطعم')) {
        matchedRoute = '/restaurants';
        matchedName = 'المطاعم';
      } else if (normalized == '2' || normalized.contains('ثاني') || normalized.contains('وظائف') || normalized.contains('شغل') || normalized.contains('وظيفة')) {
        matchedRoute = '/vacancies';
        matchedName = 'الوظائف';
      } else if (normalized == '3' || normalized.contains('ثالث') || normalized.contains('تكسي') || normalized.contains('تاكسي') || normalized.contains('سياره') || normalized.contains('سيارة')) {
        matchedRoute = '/taxi';
        matchedName = 'تكسي مدار';
      } else if (normalized == '4' || normalized.contains('رابع') || normalized.contains('دعم') || normalized.contains('شكوى') || normalized.contains('شكاوى')) {
        matchedRoute = '/complaints';
        matchedName = 'الدعم الفني والشكاوى';
      }

      if (matchedRoute != null && matchedName != null) {
        isLearning = false;
        final phraseToLearn = learningPhrase;
        learningPhrase = '';
        saveLearnedPhrase(phraseToLearn, matchedRoute);
        return 'FAQ_ANSWER: ${json.encode({
          'response': 'صار تدلل عيوني! تعلمت وحفظت ببالي. المرة الجاية لما تكول "$phraseToLearn" راح أفتحلك $matchedName مباشرة!',
          'actionType': 'navigate',
          'actionData': matchedRoute
        })}';
      } else {
        isLearning = false;
        learningPhrase = '';
      }
    }

    // 0.2 التحقق من العبارات المتعلمة مسبقاً (مطابقة تامة أو مرنة)
    String? foundRoute;
    if (_learnedPhrases.containsKey(normalized)) {
      foundRoute = _learnedPhrases[normalized];
    } else {
      for (final entry in _learnedPhrases.entries) {
        if (calculateSimilarity(normalized, entry.key) >= 0.85) {
          foundRoute = entry.value;
          break;
        }
      }
    }

    if (foundRoute != null) {
      String matchedName = 'الصفحة المطلوبة';
      switch (foundRoute) {
        case '/restaurants':
          matchedName = 'المطاعم';
          break;
        case '/vacancies':
          matchedName = 'الوظائف';
          break;
        case '/taxi':
          matchedName = 'تكسي مدار';
          break;
        case '/complaints':
          matchedName = 'الدعم الفني والشكاوى';
          break;
      }

      return 'FAQ_ANSWER: ${json.encode({
        'response': 'صار تدلل عيوني! هاي تعلمتها منك سابقاً. راح أفتحلك $matchedName!',
        'actionType': 'navigate',
        'actionData': foundRoute
      })}';
    }

    // 1. تحليل المشاعر لتحديد نبرة الإجابة
    String sentiment = 'neutral';
    final positiveWords = _getSentimentKeywords('happy');
    final sadWords = _getSentimentKeywords('sad');
    final angryWords = _getSentimentKeywords('angry');
    
    if (positiveWords.any((w) => hasMatch(normalized, w))) {
      sentiment = 'happy';
    } else if (angryWords.any((w) => hasMatch(normalized, w))) {
      sentiment = 'sad_angry';
    } else if (sadWords.any((w) => hasMatch(normalized, w))) {
      sentiment = 'sad_angry';
    }
    context.update(sentiment: sentiment);

    // 2. كشف الأسئلة المتعلقة بالمطور والبرمجة (عمر الراوي)
    final developerKeywords = ['مطور', 'صنع', 'برمج', 'سواك', 'عمر الراوي', 'عمر', 'الراوي'];
    bool isDeveloperQuery = developerKeywords.any((k) => normalized.contains(k));
    if (isDeveloperQuery) {
      return 'SAY: "${randomResponse('creator')}"';
    }

    // 3. كشف النية باستخدام نظام النقاط (Scoring) بناءً على أوزان الكلمات المفتاحية
    final scores = <UserIntent, int>{};
    for (final intent in UserIntent.values) {
      scores[intent] = 0;
    }

    for (final intent in UserIntent.values) {
      int score = 0;
      final keywords = _getIntentKeywords(intent);
      keywords.forEach((keyword, weight) {
        if (hasMatch(normalized, keyword)) {
          score += weight;
        }
      });
      scores[intent] = score;
    }

    UserIntent detectedIntent = UserIntent.unknown;
    int maxScore = 0;
    scores.forEach((intent, score) {
      if (score > maxScore) {
        maxScore = score;
        detectedIntent = intent;
      }
    });

    // 4. كشف الكيان بالاعتماد على الوزن الأعلى لتجنب التضارب (Entity Extraction with Weight Priority)
    String? matchedEntityKey;
    String? matchedRoute;
    int maxEntityScore = 0;

    final entityKeys = [
      'restaurants', 'vacancies', 'taxi', 'stores',
      'complaints', 'my_orders', 'favorites', 'profile', 'delivery', 'studios', 'real_estate',
      'login', 'register', 'home', 'all-sections'
    ];

    for (final key in entityKeys) {
      final aliases = _getEntityAliases(key);
      final route = _getEntityRoute(key);
      aliases.forEach((alias, weight) {
        if (hasMatch(normalized, alias) && weight > maxEntityScore) {
          maxEntityScore = weight;
          matchedEntityKey = key;
          matchedRoute = route;
        }
      });
    }

    // 5. تطبيق ذاكرة السياق للمتابعة (Context Memory)
    if (matchedEntityKey != null) {
      context.update(entity: matchedEntityKey, intent: detectedIntent);
    } else {
      if (context.lastEntity != null && 
          (detectedIntent == UserIntent.order || 
           detectedIntent == UserIntent.search || 
           detectedIntent == UserIntent.filter || 
           detectedIntent == UserIntent.sort ||
           detectedIntent == UserIntent.add)) {
        matchedEntityKey = context.lastEntity;
        matchedRoute = _getEntityRoute(matchedEntityKey!);
      }
    }

    // 6. معالجة التحية والترحيب حسب مشاعر المستخدم
    if (detectedIntent == UserIntent.greeting) {
      if (sentiment == 'happy') {
        return 'SAY: "${randomResponse('greeting_happy')}"';
      } else if (sentiment == 'sad_angry') {
        return 'SAY: "${randomResponse('greeting_sad_angry')}"';
      }
      return 'SAY: "${randomResponse('greeting')}"';
    }

    // 7. معالجة الاستفسارات العامة (Info)
    if (detectedIntent == UserIntent.info && matchedEntityKey == null) {
      return 'SAY: "${randomResponse('info')}"';
    }

    // 8. معالجة تغيير كلمة المرور والبروفايل
    if (normalized.contains('تغيير كلمة المرور') || normalized.contains('تغيير الرمز') || 
        normalized.contains('تعديل الرمز') || normalized.contains('غير الرمز')) {
      return 'PROFILE_CHANGE_PASSWORD';
    }

    // معالجة البروفايل (عدل معلوماتي، معلومات حسابي)
    if (matchedEntityKey == 'profile') {
      if (detectedIntent == UserIntent.editProfile || normalized.contains('عدل معلوماتي') || normalized.contains('تحديث معلوماتي')) {
        return 'PROFILE_EDIT';
      }
      if (normalized.contains('اني منو') || normalized.contains('منو اني') || normalized.contains('معلومات حسابي')) {
        return 'WHO_AM_I';
      }
      return 'NAVIGATE: "/favorites"';
    }

    // 9. معالجة تتبع الطلبات
    if (detectedIntent == UserIntent.trackOrder) {
      return 'TRACK_ORDERS';
    }

    // 10. معالجة الدعم الفني والشكاوى
    if (detectedIntent == UserIntent.contactSupport) {
      return 'CONTACT_SUPPORT';
    }

    // 11. معالجة أرقام الطوارئ
    if (normalized.contains('طوارئ') || normalized.contains('اسعاف') || normalized.contains('اطفاء') || normalized.contains('شرطه')) {
      return 'EMERGENCY_NUMBERS';
    }

    // 12. معالجة "اني منو" المباشرة
    if (normalized.contains('اني منو') || normalized.contains('منو اني') || normalized.contains('معلومات حسابي')) {
      return 'WHO_AM_I';
    }

    // 13. معالجة التنقل (Navigate)
    if (detectedIntent == UserIntent.navigate && matchedRoute != null) {
      return 'NAVIGATE: "$matchedRoute"';
    }

    // 14. معالجة الطلب (Order Disambiguation & Automation)
    if (detectedIntent == UserIntent.order || matchedEntityKey == 'restaurants') {
      if (normalized.contains('بيتزا') || normalized.contains('برجر') || normalized.contains('شاورما') || normalized.contains('قص') || normalized.contains('كباب')) {
        return _parseFoodOrder(normalized);
      }
      return 'NAVIGATE: "/restaurants"';
    }

    // 15. معالجة إضافة إعلانات (Add)
    if (detectedIntent == UserIntent.add) {
      if (matchedEntityKey == 'vacancies') return 'JOB_ADD';
      if (matchedEntityKey == 'real_estate') return 'REAL_ESTATE_ADD';
      if (matchedEntityKey == 'complaints') return 'COMPLAINT_ADD';
      if (matchedEntityKey == 'studios') return 'STUDIO_ADD';
      
      // التخمين حسب السياق
      if (currentRoute == '/vacancies') return 'JOB_ADD';
      if (currentRoute == '/real_estate') return 'REAL_ESTATE_ADD';
      if (currentRoute == '/complaints') return 'COMPLAINT_ADD';
      if (currentRoute == '/studios') return 'STUDIO_ADD';
    }

    // 16. معالجة البحث والفلترة والترتيب
    if (detectedIntent == UserIntent.search || detectedIntent == UserIntent.filter || detectedIntent == UserIntent.sort) {
      return _resolveSearchOrFilter(normalized, matchedEntityKey, currentRoute, rawText);
    }

    // 17. معالجة الانتقال الافتراضي إذا ذكر الكيان بدون فعل واضح
    if (matchedRoute != null) {
      return 'NAVIGATE: "$matchedRoute"';
    }

    // 18. عبارة غير مفهومة - تفعيل حلقة التعلم التفاعلي
    isLearning = true;
    learningPhrase = rawText;
    UnrecognizedPhrasesLogger.log(rawText);

    return 'SAY: "حبيبي ما فهمت عليك زين. \n'
           'بس تكدر تعلمني شجنت تقصد علمود أحفظها ببالي المرة الجاية؟\n'
           'اكتب رقم الاختيار:\n'
           '1⃣ فتح صفحة المطاعم \n'
           '2⃣ فتح صفحة الوظائف \n'
           '3⃣ طلب تكسي مدار \n'
           '4⃣ البحث عن أطباء ومدرسين \n'
           '5⃣ التواصل مع الدعم الفني \n'
           '(أو اكتب أي شي ثاني لتخطي التعلم)"';
  }

  /// تحليل طلب الطعام وتجهيز صيغة FOOD_ORDER
  static String _parseFoodOrder(String normalized) {
    String restaurant = '';
    final restMatch = RegExp(r'من (?:مطعم\s+)?([^\s]+(?: [^\s]+)?)').firstMatch(normalized);
    if (restMatch != null) {
      restaurant = restMatch.group(1)!.trim();
    } else {
      final knownRestaurants = ['الصاج', 'البركة', 'النور', 'السلطان', 'طيبة', 'الملك'];
      for (var kr in knownRestaurants) {
        if (normalized.contains(kr)) {
          restaurant = 'مطعم $kr';
          break;
        }
      }
    }
    if (restaurant.isEmpty) {
      restaurant = 'مطعم الصاج'; 
    }

    final items = <Map<String, dynamic>>[];
    final foodItems = {
      'بيتزا': ['بيتزا', 'بيتزا دبل', 'بيتزا لحم', 'بيتزا دجاج'],
      'برجر': ['برجر', 'همبرجر', 'برجر لحم', 'برجر دجاج'],
      'شاورما': ['شاورما', 'قص', 'صاج دجاج', 'صاج لحم'],
      'كباب': ['كباب', 'مشاوي'],
      'كولا': ['كولا', 'بيبسي', 'سفن'],
      'عصير': ['عصير', 'موجه']
    };

    foodItems.forEach((key, aliases) {
      for (var alias in aliases) {
        if (normalized.contains(alias)) {
          int qty = 1;
          if (normalized.contains('دبل') || normalized.contains('اثنين') || normalized.contains('2')) {
            qty = 2;
          }
          items.add({
            'name': alias,
            'qty': qty,
          });
          break; 
        }
      }
    });

    if (items.isNotEmpty) {
      return 'FOOD_ORDER: ${json.encode({'restaurant': restaurant, 'items': items})}';
    }

    return 'NAVIGATE: "/restaurants"';
  }

  /// معالجة وتوليد أوامر البحث والفلترة والترتيب للمستأجرين
  static String _resolveSearchOrFilter(String normalized, String? matchedEntityKey, String currentRoute, String rawText) {
    String query = '';
    final searchTerms = ['ابحث عن', 'دورلي على', 'شوفلي عن', 'بحث عن', 'اريد', 'ابي', 'دورلي', 'ابحثلي', 'لكيلي'];
    for (var term in searchTerms) {
      final normTerm = normalizeIraqi(term);
      if (normalized.contains(normTerm)) {
        final index = normalized.indexOf(normTerm) + normTerm.length;
        if (index < rawText.length) {
          query = rawText.substring(index).trim();
          query = query.replaceFirst(RegExp(r'^(وظيفه|شغل|عمل|وظيفة|عن|على|دكتور|مدرس|استوديو|عقار|طبيب|معلم)\s*'), '').trim();
          break;
        }
      }
    }

    final entity = matchedEntityKey ?? _getEntityFromRoute(currentRoute);

    if (entity == 'vacancies') {
      if (normalized.contains('تقنيه') || normalized.contains('تقنية')) return 'JOB_CATEGORY: "تقنية"';
      if (normalized.contains('تعليم')) return 'JOB_CATEGORY: "تعليم"';
      if (normalized.contains('صحه') || normalized.contains('صحة')) return 'JOB_CATEGORY: "صحة"';
      if (normalized.contains('هندسه') || normalized.contains('هندسة')) return 'JOB_CATEGORY: "هندسة"';
      if (normalized.contains('تجاره') || normalized.contains('تجارة')) return 'JOB_CATEGORY: "تجارة"';
      if (normalized.contains('خدمات')) return 'JOB_CATEGORY: "خدمات"';

      if (normalized.contains('باحثين')) return 'JOB_FILTER: "seeker"';
      if (normalized.contains('فرص') || normalized.contains('اصحاب العمل')) return 'JOB_FILTER: "employer"';
      if (normalized.contains('محفوظه') || normalized.contains('مفضله') || normalized.contains('مفضلة')) return 'JOB_FILTER: "saved"';
      if (normalized.contains('احدث') || normalized.contains('جديد')) return 'JOB_SORT: "date_desc"';
      if (normalized.contains('اقدم')) return 'JOB_SORT: "date_asc"';
      if (normalized.contains('تفاعل') || normalized.contains('لايكات')) return 'JOB_SORT: "likes_desc"';

      if (query.isNotEmpty) return 'JOB_SEARCH: "$query"';
      return 'NAVIGATE: "/vacancies"';
    }

    if (entity == 'restaurants') {
      if (normalized.contains('حلويات')) return 'RESTAURANT_CATEGORY: "الحلويات"';
      if (normalized.contains('عصائر') || normalized.contains('مشروبات')) return 'RESTAURANT_CATEGORY: "العصائر"';
      if (normalized.contains('منزلية') || normalized.contains('طبخ بيت')) return 'RESTAURANT_CATEGORY: "المنزلية"';
      if (query.isNotEmpty) return 'RESTAURANT_SEARCH: "$query"';
      return 'NAVIGATE: "/restaurants"';
    }

    if (entity == 'stores') {
      if (query.isNotEmpty) return 'STORE_SEARCH: "$query"';
      return 'NAVIGATE: "/stores"';
    }

    if (entity == 'real_estate') {
      if (normalized.contains('بيع')) return 'REAL_ESTATE_FILTER: "للبيع"';
      if (normalized.contains('ايجار') || normalized.contains('إيجار')) return 'REAL_ESTATE_FILTER: "للإيجار"';
      if (query.isNotEmpty) return 'REAL_ESTATE_SEARCH: "$query"';
      return 'NAVIGATE: "/real_estate"';
    }

    if (entity == 'studios') {
      if (normalized.contains('زفاف') || normalized.contains('عرس')) return 'STUDIO_FILTER: "تصوير زفاف"';
      if (normalized.contains('شخصي') || normalized.contains('بورتريه')) return 'STUDIO_FILTER: "تصوير بورتريه"';
      if (normalized.contains('منتجات')) return 'STUDIO_FILTER: "تصوير منتجات"';
      if (query.isNotEmpty) return 'STUDIO_SEARCH: "$query"';
      return 'NAVIGATE: "/studios"';
    }

    if (query.isNotEmpty) {
      return 'FETCH_SECTIONS: "$query"';
    }

    return 'NAVIGATE: "/all-sections"';
  }

  static String _getEntityFromRoute(String route) {
    if (route.contains('vacancies')) return 'vacancies';
    if (route.contains('restaurants')) return 'restaurants';
    if (route.contains('stores')) return 'stores';
    if (route.contains('real_estate')) return 'real_estate';
    if (route.contains('studios')) return 'studios';
    return '';
  }

  // هياكل Fallback محلية لحماية الكود من الانهيار عند فشل تحميل الأصول
  static const Map<String, Map<String, dynamic>> _fallbackEntities = {
    'restaurants': {
      'route': '/restaurants',
      'aliases': {'مطاعم': 10, 'مطعم': 10, 'بيتزا': 10, 'برجر': 10, 'شاورما': 10, 'وجبات': 6, 'جوعان': 5}
    },
    'vacancies': {
      'route': '/vacancies',
      'aliases': {'وظائف': 10, 'شغل': 5, 'عمل': 5, 'توظيف': 9, 'فرص عمل': 10}
    },
    'taxi': {
      'route': '/taxi',
      'aliases': {'تكسي': 10, 'تاكسي': 10, 'كابتن': 9, 'سيارة': 6}
    },
    'stores': {
      'route': '/stores',
      'aliases': {'متاجر': 10, 'تسوق': 7, 'متجر': 10, 'اسواق': 8}
    },
    'complaints': {
      'route': '/complaints',
      'aliases': {'شكوي': 10, 'شكاوي': 10, 'اقتراح': 9, 'شكوى': 10}
    },
    'my_orders': {
      'route': '/my_orders',
      'aliases': {'طلباتي': 10, 'طلبات': 8, 'اوردراتي': 9}
    },
    'favorites': {
      'route': '/favorites',
      'aliases': {'مفضله': 10, 'المفضله': 10, 'favorites': 10}
    },
    'profile': {
      'route': '/favorites',
      'aliases': {'حسابي': 10, 'بروفايلي': 10, 'ملفي الشخصي': 10, 'معلوماتي': 9}
    },
    'delivery': {
      'route': '/delivery',
      'aliases': {'مرسال': 10, 'توصيل': 8, 'طرد': 8, 'غراض': 8}
    },
    'studios': {
      'route': '/studios',
      'aliases': {'استوديو': 10, 'تصوير': 10, 'استوديوهات': 10, 'كاميرا': 8}
    },
    'real_estate': {
      'route': '/real_estate',
      'aliases': {'عقارات': 10, 'عقار': 10, 'شقة للبيع': 10, 'شقة للايجار': 10, 'بيوت': 8}
    },
    'login': {
      'route': '/login',
      'aliases': {'تسجيل دخول': 10, 'دخول': 8}
    },
    'register': {
      'route': '/register',
      'aliases': {'انشاء حساب': 10, 'تسجيل': 8}
    },
    'home': {
      'route': '/home',
      'aliases': {'الرئيسية': 10, 'الرئيسيه': 10, 'home': 10}
    },
    'all-sections': {
      'route': '/all-sections',
      'aliases': {'الاقسام': 10, 'اقسام': 9, 'sections': 10}
    }
  };

  static const Map<UserIntent, Map<String, int>> _fallbackIntents = {
    UserIntent.navigate: {'وديني': 10, 'ودني': 10, 'خذني': 10, 'روحني': 10, 'وصلني': 10},
    UserIntent.search: {'دورلي': 10, 'لكيلي': 10, 'لاكيلي': 10, 'شوفلي': 10, 'جيبلي': 9, 'ابحثلي': 9},
    UserIntent.order: {'اطلب': 10, 'اطلبلي': 10, 'سويلي اوردر': 10, 'اريد اكل': 9},
    UserIntent.add: {'اضف': 10, 'اضافة': 10, 'انشر': 10, 'سجل اعلان': 10},
    UserIntent.register: {'سجل مطعم': 10, 'سجل تكسي': 10, 'اشتغل كابتن': 10},
    UserIntent.editProfile: {'عدل معلوماتي': 10, 'تغيير الاسم': 9, 'حدث بياناتي': 9},
    UserIntent.trackOrder: {'تابع طلباتي': 10, 'وين طلبي': 10, 'حالة طلبي': 10},
    UserIntent.contactSupport: {'رقم الدعم': 10, 'دعم فني': 10, 'تواصل مع الادارة': 10},
    UserIntent.info: {'منو مطورك': 10, 'منو صنعك': 10, 'عمر الراوي': 10, 'شنو مدار': 9},
    UserIntent.highlight: {'اشرلي': 10, 'اشر': 10, 'وين زر': 10},
    UserIntent.greeting: {'هلو': 10, 'مرحبا': 10, 'السلام عليكم': 10, 'شلونك': 9},
    UserIntent.filter: {'صفيني': 10, 'فلتر': 10},
    UserIntent.sort: {'رتب': 10, 'ترتيب': 10}
  };

  static const Map<String, List<String>> _fallbackSentiments = {
    'happy': ['شكرا', 'ممنون', 'عاشت ايدك', 'ممتاز', 'احسنت', 'طيب', 'حلو', 'حبيبي'],
    'sad': ['زعلان', 'متضايق', 'مقهور', 'ضايج'],
    'angry': ['معصب', 'زعلان منكم', 'الخدمة تعبانة', 'بطيء', 'خربان', 'سيء', 'تاخر']
  };

  static const Map<String, List<String>> _fallbackResponses = {
    'greeting': ['يا هلا ومية هلا بيك عيوني! شلون أكدر أساعدك اليوم يا غالي؟ تدلل!'],
    'creator': ['ابتكار وهندسة سكوزمي وتطبيق مدار تم تطويرها وبرمجتها بالكامل بواسطة المبدع المهندس عمر الراوي!'],
    'info': ['تطبيق مدار هو دليلك وخدمتك الشاملة بالقائم وكل العراق! نوفرلك: مطاعم ، تكسي ، أطباء ومعلمين ، وظائف ، عقارات ، واستوديوهات تصوير ومتاجر .'],
    'navigate_success': ['تدلل من عيوني! راح أنقلك هسة وطايرين!'],
    'search_start': ['من عيوني الثنتين! ثواني أدورلك على أحسن شي...'],
    'not_understood': ['يا بعد راسي ما فهمت عليك زين.. ممكن تكلي بكلمات ثانية وتدلل؟']
  };
}
