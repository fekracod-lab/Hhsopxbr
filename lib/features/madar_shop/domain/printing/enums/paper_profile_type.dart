// نمط ونوع الورق المعتمد (MADAR SHOP Paper Profile Type Enum)
// Pure Dart — Zero UI Dependencies

enum PaperProfileType {
  thermal58mm,
  thermal80mm,
  a4,
  a5,
  label,
  custom;

  bool get isThermal => this == PaperProfileType.thermal58mm || this == PaperProfileType.thermal80mm;
  bool get isSheet => this == PaperProfileType.a4 || this == PaperProfileType.a5;
  bool get isLabel => this == PaperProfileType.label;

  static PaperProfileType fromString(String? val) {
    if (val == null) return PaperProfileType.thermal80mm;
    switch (val.trim().toLowerCase()) {
      case '58mm':
      case 'thermal_58mm':
      case 'thermal58':
        return PaperProfileType.thermal58mm;
      case '80mm':
      case 'thermal_80mm':
      case 'thermal80':
        return PaperProfileType.thermal80mm;
      case 'a4':
        return PaperProfileType.a4;
      case 'a5':
        return PaperProfileType.a5;
      case 'label':
      case 'barcode_label':
        return PaperProfileType.label;
      case 'custom':
      default:
        return PaperProfileType.custom;
    }
  }

  String toDbString() {
    switch (this) {
      case PaperProfileType.thermal58mm:
        return 'thermal_58mm';
      case PaperProfileType.thermal80mm:
        return 'thermal_80mm';
      case PaperProfileType.a4:
        return 'a4';
      case PaperProfileType.a5:
        return 'a5';
      case PaperProfileType.label:
        return 'label';
      case PaperProfileType.custom:
        return 'custom';
    }
  }

  String get displayNameAr {
    switch (this) {
      case PaperProfileType.thermal58mm:
        return 'حراري 58 ملم (كاشير صغير)';
      case PaperProfileType.thermal80mm:
        return 'حراري 80 ملم (كاشير قياسي)';
      case PaperProfileType.a4:
        return 'ورق قياسي A4 (فواتير وتقارير رسمية)';
      case PaperProfileType.a5:
        return 'ورق A5 (فواتير مصغرة)';
      case PaperProfileType.label:
        return 'ملصقات وباركود (Labels)';
      case PaperProfileType.custom:
        return 'أبعاد مخصصة (Custom Size)';
    }
  }
}
