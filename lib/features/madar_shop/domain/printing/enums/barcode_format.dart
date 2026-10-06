// صيغ الباركود والـ QR (MADAR SHOP Barcode Format Enum)
// Pure Dart — Zero UI Dependencies

enum BarcodeFormat {
  code128,
  ean13,
  qrCode;

  bool get isQr => this == BarcodeFormat.qrCode;
  bool get is1D => this == BarcodeFormat.code128 || this == BarcodeFormat.ean13;

  static BarcodeFormat fromString(String? val) {
    if (val == null) return BarcodeFormat.code128;
    switch (val.trim().toLowerCase()) {
      case 'qr':
      case 'qrcode':
      case 'qr_code':
        return BarcodeFormat.qrCode;
      case 'ean13':
      case 'ean_13':
        return BarcodeFormat.ean13;
      case 'code128':
      case 'code_128':
      default:
        return BarcodeFormat.code128;
    }
  }

  String toDbString() {
    switch (this) {
      case BarcodeFormat.code128:
        return 'code128';
      case BarcodeFormat.ean13:
        return 'ean13';
      case BarcodeFormat.qrCode:
        return 'qr_code';
    }
  }
}
