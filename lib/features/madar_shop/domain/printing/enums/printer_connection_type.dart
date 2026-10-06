// أنواع اتصال الطابعات (MADAR SHOP Printer Connection Type Enum)
// Pure Dart — Zero UI Dependencies

enum PrinterConnectionType {
  usb,
  network,
  bluetooth,
  windowsAgent,
  systemPrinter;

  static PrinterConnectionType fromString(String? val) {
    if (val == null) return PrinterConnectionType.systemPrinter;
    switch (val.trim().toLowerCase()) {
      case 'usb':
        return PrinterConnectionType.usb;
      case 'network':
      case 'tcp':
      case 'ethernet':
      case 'wifi':
        return PrinterConnectionType.network;
      case 'bluetooth':
      case 'bt':
        return PrinterConnectionType.bluetooth;
      case 'windows_agent':
      case 'windowsagent':
      case 'agent':
        return PrinterConnectionType.windowsAgent;
      case 'system_printer':
      case 'systemprinter':
      case 'system':
      default:
        return PrinterConnectionType.systemPrinter;
    }
  }

  String toDbString() {
    switch (this) {
      case PrinterConnectionType.usb:
        return 'usb';
      case PrinterConnectionType.network:
        return 'network';
      case PrinterConnectionType.bluetooth:
        return 'bluetooth';
      case PrinterConnectionType.windowsAgent:
        return 'windows_agent';
      case PrinterConnectionType.systemPrinter:
        return 'system_printer';
    }
  }

  String get displayNameAr {
    switch (this) {
      case PrinterConnectionType.usb:
        return 'منفذ USB سلكي';
      case PrinterConnectionType.network:
        return 'شبكة محلية (IP/Network)';
      case PrinterConnectionType.bluetooth:
        return 'بلوتوث لاسلكي (Bluetooth)';
      case PrinterConnectionType.windowsAgent:
        return 'وكيل طباعة ويندوز (Windows Agent)';
      case PrinterConnectionType.systemPrinter:
        return 'طابعة النظام الافتراضية (System Spooler)';
    }
  }
}
