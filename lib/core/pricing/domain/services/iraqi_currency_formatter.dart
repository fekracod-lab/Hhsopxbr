/// 🇮🇶 محرك تنسيق العملة والتفقيط بالدينار العراقي والأرقام العربية
class IraqiCurrencyFormatter {
  static const Map<String, String> _arabicDigits = {
    '0': '٠',
    '1': '١',
    '2': '٢',
    '3': '٣',
    '4': '٤',
    '5': '٥',
    '6': '٦',
    '7': '٧',
    '8': '٨',
    '9': '٩',
  };

  /// تحويل الأرقام إلى أرقام عربية مشرقية مع فواصل الآلاف (مثال: ٨,٥٠٠ د.ع)
  static String format(num amount, {bool includeSymbol = true}) {
    final int val = amount.toInt();
    final formatted = val.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    final arabicFormatted = formatted.split('').map((char) => _arabicDigits[char] ?? char).join();
    return includeSymbol ? '$arabicFormatted د.ع' : arabicFormatted;
  }

  /// تفقيط السعر كتابة باللغة العربية مع الدينار العراقي (مثال: ثمانية آلاف وخمسمائة دينار)
  static String formatWritten(num amount) {
    final int val = amount.toInt();
    if (val == 0) return 'مجاني';

    // Direct lookup for common menu prices
    final direct = _commonPrices[val];
    if (direct != null) return direct;

    return '${_numberToWords(val)} دينار';
  }

  /// تنسيق مركب يشمل الأرقام العربية والتفقيط معاً
  static String formatFull(num amount) {
    final digits = format(amount);
    final words = formatWritten(amount);
    return '$digits ($words)';
  }

  static const Map<int, String> _commonPrices = {
    250: 'مئتان وخمسون دينار',
    500: 'خمسمائة دينار',
    750: 'سبعمائة وخمسون دينار',
    1000: 'ألف دينار',
    1250: 'ألف ومئتان وخمسون دينار',
    1500: 'ألف وخمسمائة دينار',
    1750: 'ألف وسبعمائة وخمسون دينار',
    2000: 'ألفان دينار',
    2250: 'ألفان ومئتان وخمسون دينار',
    2500: 'ألفان وخمسمائة دينار',
    3000: 'ثلاثة آلاف دينار',
    3500: 'ثلاثة آلاف وخمسمائة دينار',
    4000: 'أربعة آلاف دينار',
    4500: 'أربعة آلاف وخمسمائة دينار',
    5000: 'خمسة آلاف دينار',
    5500: 'خمسة آلاف وخمسمائة دينار',
    6000: 'ستة آلاف دينار',
    6500: 'ستة آلاف وخمسمائة دينار',
    7000: 'سبعة آلاف دينار',
    7500: 'سبعة آلاف وخمسمائة دينار',
    8000: 'ثمانية آلاف دينار',
    8500: 'ثمانية آلاف وخمسمائة دينار',
    9000: 'تسعة آلاف دينار',
    9500: 'تسعة آلاف وخمسمائة دينار',
    10000: 'عشرة آلاف دينار',
    11000: 'أحد عشر ألف دينار',
    11500: 'أحد عشر ألف وخمسمائة دينار',
    12000: 'اثنا عشر ألف دينار',
    12500: 'اثنا عشر ألف وخمسمائة دينار',
    13000: 'ثلاثة عشر ألف دينار',
    13500: 'ثلاثة عشر ألف وخمسمائة دينار',
    14000: 'أربعة عشر ألف دينار',
    14500: 'أربعة عشر ألف وخمسمائة دينار',
    15000: 'خمسة عشر ألف دينار',
    16000: 'ستة عشر ألف دينار',
    17000: 'سبعة عشر ألف دينار',
    18000: 'ثمانية عشر ألف دينار',
    19000: 'تسعة عشر ألف دينار',
    20000: 'عشرون ألف دينار',
    22000: 'اثنان وعشرون ألف دينار',
    25000: 'خمسة وعشرون ألف دينار',
    28000: 'ثمانية وعشرون ألف دينار',
    30000: 'ثلاثون ألف دينار',
    35000: 'خمسة وثلاثون ألف دينار',
    40000: 'أربعون ألف دينار',
    45000: 'خمسة وأربعون ألف دينار',
    50000: 'خمسون ألف دينار',
  };

  static String _numberToWords(int number) {
    if (number == 0) return 'صفر';

    final ones = ['', 'واحد', 'اثنان', 'ثلاثة', 'أربعة', 'خمسة', 'ستة', 'سبعة', 'ثمانية', 'تسعة'];
    final teens = [
      'عشرة', 'أحد عشر', 'اثنا عشر', 'ثلاثة عشر', 'أربعة عشر', 'خمسة عشر',
      'ستة عشر', 'سبعة عشر', 'ثمانية عشر', 'تسعة عشر'
    ];
    final tens = ['', '', 'عشرون', 'ثلاثون', 'أربعون', 'خمسون', 'ستون', 'سبعون', 'ثمانون', 'تسعون'];
    final hundreds = [
      '', 'مائة', 'مئتان', 'ثلاثمائة', 'أربعمائة', 'خمسمائة',
      'ستمائة', 'سبعمائة', 'ثمانمائة', 'تسعمائة'
    ];

    String convertLessThanThousand(int n) {
      if (n == 0) return '';
      final h = n ~/ 100;
      final rem = n % 100;
      final t = rem ~/ 10;
      final o = rem % 10;

      final parts = <String>[];
      if (h > 0) parts.add(hundreds[h]);

      if (rem > 0) {
        if (rem < 10) {
          parts.add(ones[rem]);
        } else if (rem < 20) {
          parts.add(teens[rem - 10]);
        } else {
          if (o > 0) {
            parts.add('${ones[o]} و${tens[t]}');
          } else {
            parts.add(tens[t]);
          }
        }
      }

      return parts.join('و');
    }

    if (number < 1000) {
      return convertLessThanThousand(number);
    }

    final thousands = number ~/ 1000;
    final remainder = number % 1000;

    String thousandsText = '';
    if (thousands == 1) {
      thousandsText = 'ألف';
    } else if (thousands == 2) {
      thousandsText = 'ألفان';
    } else if (thousands >= 3 && thousands <= 9) {
      thousandsText = '${ones[thousands]} آلاف';
    } else if (thousands == 10) {
      thousandsText = 'عشرة آلاف';
    } else {
      thousandsText = '${convertLessThanThousand(thousands)} ألف';
    }

    if (remainder > 0) {
      return '$thousandsText و${convertLessThanThousand(remainder)}';
    }
    return thousandsText;
  }
}
