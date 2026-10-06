// نمط وأبعاد الورق الطباعي (MADAR SHOP Paper Profile Value Object)
// Pure Dart — Zero UI Dependencies

import '../enums/paper_profile_type.dart';

class PaperProfile {
  final PaperProfileType type;
  final double widthMm;
  final double? heightMm; // null للرولات الحرارية المستمرة (Continuous rolls)
  final double printableWidthMm;
  final double marginLeftMm;
  final double marginRightMm;
  final double marginTopMm;
  final double marginBottomMm;
  final int dpi;
  final int maxCharsPerLine; // عدد الحروف في السطر لخط النمط القياسي (Standard Font)
  final bool supportsCut;
  final bool supportsDrawer;

  const PaperProfile({
    required this.type,
    required this.widthMm,
    this.heightMm,
    required this.printableWidthMm,
    this.marginLeftMm = 0.0,
    this.marginRightMm = 0.0,
    this.marginTopMm = 0.0,
    this.marginBottomMm = 0.0,
    this.dpi = 203, // 203 DPI standard for thermal POS receipt printers
    required this.maxCharsPerLine,
    this.supportsCut = true,
    this.supportsDrawer = true,
  }) : assert(widthMm > 0, 'عرض الورق يجب أن يكون أكبر من الصفر');

  bool get isContinuous => heightMm == null;
  double get leftMarginMm => marginLeftMm;
  double get rightMarginMm => marginRightMm;

  PaperProfile copyWith({
    PaperProfileType? type,
    double? widthMm,
    double? heightMm,
    double? printableWidthMm,
    double? marginLeftMm,
    double? marginRightMm,
    double? marginTopMm,
    double? marginBottomMm,
    int? dpi,
    int? maxCharsPerLine,
    bool? supportsCut,
    bool? supportsDrawer,
  }) {
    return PaperProfile(
      type: type ?? this.type,
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      printableWidthMm: printableWidthMm ?? this.printableWidthMm,
      marginLeftMm: marginLeftMm ?? this.marginLeftMm,
      marginRightMm: marginRightMm ?? this.marginRightMm,
      marginTopMm: marginTopMm ?? this.marginTopMm,
      marginBottomMm: marginBottomMm ?? this.marginBottomMm,
      dpi: dpi ?? this.dpi,
      maxCharsPerLine: maxCharsPerLine ?? this.maxCharsPerLine,
      supportsCut: supportsCut ?? this.supportsCut,
      supportsDrawer: supportsDrawer ?? this.supportsDrawer,
    );
  }

  /// ملف ورقي قياسي لطابعة حرارية 58 ملم (32 حرفاً في السطر)
  factory PaperProfile.thermal58mm({
    int maxCharsPerLine = 32,
    bool supportsCut = true,
    bool supportsDrawer = true,
  }) {
    return PaperProfile(
      type: PaperProfileType.thermal58mm,
      widthMm: 58.0,
      heightMm: null, // Roll
      printableWidthMm: 48.0,
      marginLeftMm: 0.0,
      marginRightMm: 0.0,
      marginTopMm: 0.0,
      marginBottomMm: 0.0,
      dpi: 203,
      maxCharsPerLine: maxCharsPerLine,
      supportsCut: supportsCut,
      supportsDrawer: supportsDrawer,
    );
  }

  /// ملف ورقي قياسي لطابعة حرارية 80 ملم (48 حرفاً في السطر)
  factory PaperProfile.thermal80mm({
    int maxCharsPerLine = 48,
    bool supportsCut = true,
    bool supportsDrawer = true,
  }) {
    return PaperProfile(
      type: PaperProfileType.thermal80mm,
      widthMm: 80.0,
      heightMm: null, // Roll
      printableWidthMm: 72.0,
      marginLeftMm: 4.0,
      marginRightMm: 4.0,
      marginTopMm: 0.0,
      marginBottomMm: 0.0,
      dpi: 203,
      maxCharsPerLine: maxCharsPerLine,
      supportsCut: supportsCut,
      supportsDrawer: supportsDrawer,
    );
  }

  /// ملف ورقي قياسي لصفحة A4 (210 x 297 mm)
  factory PaperProfile.a4({
    int maxCharsPerLine = 80,
    double marginMm = 15.0,
  }) {
    return PaperProfile(
      type: PaperProfileType.a4,
      widthMm: 210.0,
      heightMm: 297.0,
      printableWidthMm: 210.0 - (marginMm * 2),
      marginLeftMm: marginMm,
      marginRightMm: marginMm,
      marginTopMm: marginMm,
      marginBottomMm: marginMm,
      dpi: 300,
      maxCharsPerLine: maxCharsPerLine,
      supportsCut: false,
      supportsDrawer: false,
    );
  }

  /// ملف ورقي قياسي لصفحة A5 (148 x 210 mm)
  factory PaperProfile.a5({
    int maxCharsPerLine = 60,
    double marginMm = 10.0,
  }) {
    return PaperProfile(
      type: PaperProfileType.a5,
      widthMm: 148.0,
      heightMm: 210.0,
      printableWidthMm: 148.0 - (marginMm * 2),
      marginLeftMm: marginMm,
      marginRightMm: marginMm,
      marginTopMm: marginMm,
      marginBottomMm: marginMm,
      dpi: 300,
      maxCharsPerLine: maxCharsPerLine,
      supportsCut: false,
      supportsDrawer: false,
    );
  }

  /// ملف ورقي لملصقات الباركود والأصناف (Labels)
  factory PaperProfile.label({
    double widthMm = 50.0,
    double heightMm = 30.0,
    int maxCharsPerLine = 28,
  }) {
    return PaperProfile(
      type: PaperProfileType.label,
      widthMm: widthMm,
      heightMm: heightMm,
      printableWidthMm: widthMm - 4.0,
      marginLeftMm: 2.0,
      marginRightMm: 2.0,
      marginTopMm: 2.0,
      marginBottomMm: 2.0,
      dpi: 203,
      maxCharsPerLine: maxCharsPerLine,
      supportsCut: false,
      supportsDrawer: false,
    );
  }

  /// ملف ورقي مخصص
  factory PaperProfile.custom({
    required double widthMm,
    double? heightMm,
    required double printableWidthMm,
    required int maxCharsPerLine,
    double marginLeftMm = 0.0,
    double marginRightMm = 0.0,
    double? leftMarginMm,
    double? rightMarginMm,
    double marginTopMm = 0.0,
    double marginBottomMm = 0.0,
    bool supportsCut = false,
    bool supportsDrawer = false,
    int dpi = 203,
  }) {
    return PaperProfile(
      type: PaperProfileType.custom,
      widthMm: widthMm,
      heightMm: heightMm,
      printableWidthMm: printableWidthMm,
      marginLeftMm: leftMarginMm ?? marginLeftMm,
      marginRightMm: rightMarginMm ?? marginRightMm,
      marginTopMm: marginTopMm,
      marginBottomMm: marginBottomMm,
      dpi: dpi,
      maxCharsPerLine: maxCharsPerLine,
      supportsCut: supportsCut,
      supportsDrawer: supportsDrawer,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperProfile &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          widthMm == other.widthMm &&
          heightMm == other.heightMm &&
          printableWidthMm == other.printableWidthMm &&
          maxCharsPerLine == other.maxCharsPerLine;

  @override
  int get hashCode =>
      type.hashCode ^
      widthMm.hashCode ^
      heightMm.hashCode ^
      printableWidthMm.hashCode ^
      maxCharsPerLine.hashCode;

  @override
  String toString() =>
      'PaperProfile(type: $type, ${widthMm}x${heightMm ?? "roll"}mm, maxChars: $maxCharsPerLine)';
}
