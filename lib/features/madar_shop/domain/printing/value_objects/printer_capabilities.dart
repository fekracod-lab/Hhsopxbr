// قدرات وميزات عتاد الطابعة (MADAR SHOP Printer Capabilities Value Object)
// Pure Dart — Zero UI Dependencies

class PrinterCapabilities {
  final bool text;
  final bool image;
  final bool qr;
  final bool barcode;
  final bool cut;
  final bool drawer;
  final bool color;
  final bool duplex;
  final bool label;
  final bool customPage;

  const PrinterCapabilities({
    this.text = true,
    this.image = false,
    this.qr = false,
    this.barcode = false,
    this.cut = false,
    this.drawer = false,
    this.color = false,
    this.duplex = false,
    this.label = false,
    this.customPage = false,
  });

  /// قدرات قياسية لطابعة إيصالات حرارية متصلة بدرج نقد وقاطع ورق
  factory PrinterCapabilities.standardThermalPos() {
    return const PrinterCapabilities(
      text: true,
      image: true,
      qr: true,
      barcode: true,
      cut: true,
      drawer: true,
      color: false,
      duplex: false,
      label: false,
      customPage: false,
    );
  }

  /// قدرات طابعة حرارية بسيطة بدون قاطع آلي ولا درج نقد
  factory PrinterCapabilities.basicThermal() {
    return const PrinterCapabilities(
      text: true,
      image: false,
      qr: true,
      barcode: true,
      cut: false,
      drawer: false,
      color: false,
      duplex: false,
      label: false,
      customPage: false,
    );
  }

  /// قدرات طابعة ليزر / مكتبية A4
  factory PrinterCapabilities.officeLaser() {
    return const PrinterCapabilities(
      text: true,
      image: true,
      qr: true,
      barcode: true,
      cut: false,
      drawer: false,
      color: true,
      duplex: true,
      label: false,
      customPage: true,
    );
  }

  /// قدرات طابعة ملصقات باركود مخصصة (Label Printer)
  factory PrinterCapabilities.labelPrinter() {
    return const PrinterCapabilities(
      text: true,
      image: true,
      qr: true,
      barcode: true,
      cut: false,
      drawer: false,
      color: false,
      duplex: false,
      label: true,
      customPage: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'image': image,
      'qr': qr,
      'barcode': barcode,
      'cut': cut,
      'drawer': drawer,
      'color': color,
      'duplex': duplex,
      'label': label,
      'customPage': customPage,
    };
  }

  factory PrinterCapabilities.fromMap(Map<String, dynamic> map) {
    return PrinterCapabilities(
      text: map['text'] as bool? ?? true,
      image: map['image'] as bool? ?? false,
      qr: map['qr'] as bool? ?? true,
      barcode: map['barcode'] as bool? ?? true,
      cut: map['cut'] as bool? ?? true,
      drawer: map['drawer'] as bool? ?? true,
      color: map['color'] as bool? ?? false,
      duplex: map['duplex'] as bool? ?? false,
      label: map['label'] as bool? ?? false,
      customPage: map['customPage'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterCapabilities &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          image == other.image &&
          qr == other.qr &&
          barcode == other.barcode &&
          cut == other.cut &&
          drawer == other.drawer &&
          color == other.color &&
          duplex == other.duplex &&
          label == other.label &&
          customPage == other.customPage;

  @override
  int get hashCode =>
      text.hashCode ^
      image.hashCode ^
      qr.hashCode ^
      barcode.hashCode ^
      cut.hashCode ^
      drawer.hashCode ^
      color.hashCode ^
      duplex.hashCode ^
      label.hashCode ^
      customPage.hashCode;

  @override
  String toString() =>
      'PrinterCapabilities(cut: $cut, drawer: $drawer, qr: $qr, barcode: $barcode)';
}
