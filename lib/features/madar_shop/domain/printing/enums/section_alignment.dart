// محاذاة أجزاء الطباعة (MADAR SHOP Section Alignment Enum)
// Pure Dart — Zero UI Dependencies

enum SectionAlignment {
  left,
  center,
  right;

  static SectionAlignment fromString(String? val) {
    if (val == null) return SectionAlignment.left;
    switch (val.trim().toLowerCase()) {
      case 'center':
        return SectionAlignment.center;
      case 'right':
        return SectionAlignment.right;
      case 'left':
      default:
        return SectionAlignment.left;
    }
  }

  String toDbString() {
    switch (this) {
      case SectionAlignment.left:
        return 'left';
      case SectionAlignment.center:
        return 'center';
      case SectionAlignment.right:
        return 'right';
    }
  }
}
