import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة إدارة إعدادات وتفضيلات الطابعة الحرارية لنظام مطاعم مدار على ويندوز
class PrinterSettingsService extends ChangeNotifier {
  static final PrinterSettingsService instance = PrinterSettingsService._internal();
  PrinterSettingsService._internal();

  // مفاتيح التخزين المحلي
  static const _kAutoPrintEnabled = 'printer_auto_print_enabled';
  static const _kPrinterName = 'printer_selected_name';
  static const _kPrinterUrl = 'printer_selected_url';
  static const _kPaperSize = 'printer_paper_size'; // '80mm' | '58mm'
  static const _kPrintReceipt = 'printer_print_receipt';
  static const _kPrintKitchenTicket = 'printer_print_kitchen_ticket';
  static const _kDirectSilentPrint = 'printer_direct_silent_print';
  static const _kPrintCopies = 'printer_print_copies';
  static const _kSoundAlert = 'printer_sound_alert';
  static const _kAutoOpenCashDrawer = 'printer_auto_open_cash_drawer';
  static const _kCashDrawerPin = 'printer_cash_drawer_pin'; // 'pin2' | 'pin5'

  // المتغيرات الحالية
  bool _autoPrintEnabled = true;
  String? _selectedPrinterName;
  String? _selectedPrinterUrl;
  String _paperSize = '80mm';
  bool _printCustomerReceipt = true;
  bool _printKitchenTicket = false;
  bool _directSilentPrint = true;
  int _printCopies = 1;
  bool _soundAlert = true;
  bool _autoOpenCashDrawer = true;
  String _cashDrawerPin = 'pin2';

  bool _isInitialized = false;
  List<Printer> _cachedPrinters = [];

  // Getters
  bool get autoPrintEnabled => _autoPrintEnabled;
  String? get selectedPrinterName => _selectedPrinterName;
  String? get selectedPrinterUrl => _selectedPrinterUrl;
  String get paperSize => _paperSize;
  bool get is80mm => _paperSize == '80mm';
  bool get printCustomerReceipt => _printCustomerReceipt;
  bool get printKitchenTicket => _printKitchenTicket;
  bool get directSilentPrint => _directSilentPrint;
  int get printCopies => _printCopies;
  bool get soundAlert => _soundAlert;
  bool get autoOpenCashDrawer => _autoOpenCashDrawer;
  String get cashDrawerPin => _cashDrawerPin;
  bool get isInitialized => _isInitialized;
  List<Printer> get cachedPrinters => _cachedPrinters;

  /// تهيئة وقراءة الإعدادات المحفوظة
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoPrintEnabled = prefs.getBool(_kAutoPrintEnabled) ?? true;
      _selectedPrinterName = prefs.getString(_kPrinterName);
      _selectedPrinterUrl = prefs.getString(_kPrinterUrl);
      _paperSize = prefs.getString(_kPaperSize) ?? '80mm';
      _printCustomerReceipt = prefs.getBool(_kPrintReceipt) ?? true;
      _printKitchenTicket = prefs.getBool(_kPrintKitchenTicket) ?? false;
      _directSilentPrint = prefs.getBool(_kDirectSilentPrint) ?? true;
      _printCopies = prefs.getInt(_kPrintCopies) ?? 1;
      _soundAlert = prefs.getBool(_kSoundAlert) ?? true;
      _autoOpenCashDrawer = prefs.getBool(_kAutoOpenCashDrawer) ?? true;
      _cashDrawerPin = prefs.getString(_kCashDrawerPin) ?? 'pin2';

      _isInitialized = true;
      // استعلام الطابعات بالخلفية لعدم حجب أو تجميد نافذة الويندوز الرئيسية
      unawaited(refreshPrinters().catchError((e) {
        debugPrint('[PrinterSettingsService] Error loading printers: $e');
        return <Printer>[];
      }));
    } catch (e) {
      debugPrint('[PrinterSettingsService] Error loading settings: $e');
    }
  }

  /// تحديث قائمة الطابعات المتصلة بالويندوز
  Future<List<Printer>> refreshPrinters() async {
    try {
      _cachedPrinters = await Printing.listPrinters();
      notifyListeners();
      return _cachedPrinters;
    } catch (e) {
      debugPrint('[PrinterSettingsService] Error listing printers: $e');
      _cachedPrinters = [];
      return [];
    }
  }

  /// جلب الطابعة المستهدفة للطباعة المباشرة
  Future<Printer?> getTargetPrinter() async {
    if (_cachedPrinters.isEmpty) {
      await refreshPrinters();
    }

    if (_cachedPrinters.isEmpty) {
      return null;
    }

    // 1. إذا كان المستخدم قد حدد طابعة بالاسم أو الرابط
    if (_selectedPrinterUrl != null || _selectedPrinterName != null) {
      for (final p in _cachedPrinters) {
        if (_selectedPrinterUrl != null && p.url == _selectedPrinterUrl) {
          return p;
        }
        if (_selectedPrinterName != null && p.name == _selectedPrinterName) {
          return p;
        }
      }
    }

    // 2. البحث عن طابعة حرارية شائعة من الاسم
    final thermalKeywords = ['pos', 'thermal', 'receipt', 'xp-', '80', '58', 'tm-', 'rp', 'printer'];
    for (final p in _cachedPrinters) {
      final lowerName = p.name.toLowerCase();
      if (thermalKeywords.any((kw) => lowerName.contains(kw))) {
        return p;
      }
    }

    // 3. الطابعة الافتراضية للنظام
    for (final p in _cachedPrinters) {
      if (p.isDefault) {
        return p;
      }
    }

    // 4. أول طابعة متاحة
    return _cachedPrinters.first;
  }

  /// التحقق هل الطابعة متصلة ومتاحة حالياً
  Future<bool> isPrinterConnected() async {
    final target = await getTargetPrinter();
    return target != null && target.isAvailable;
  }

  // Setters مع الحفظ الفوري
  Future<void> setAutoPrintEnabled(bool value) async {
    _autoPrintEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoPrintEnabled, value);
  }

  /// الفحص التلقائي الذكي لعرض الورق بناءً على اسم وموديل الطابعة
  static String detectPaperSize(Printer printer) {
    final searchStr = '${printer.name} ${printer.url}'.toLowerCase();
    final is58 = searchStr.contains('58') ||
        searchStr.contains('mini') ||
        searchStr.contains('xp-58') ||
        searchStr.contains('xp58') ||
        searchStr.contains('pos58') ||
        searchStr.contains('pos-58') ||
        searchStr.contains('bluetooth') ||
        searchStr.contains('mobile') ||
        searchStr.contains('portable');
    return is58 ? '58mm' : '80mm';
  }

  Future<void> setSelectedPrinter(Printer? printer) async {
    final prefs = await SharedPreferences.getInstance();
    if (printer == null) {
      _selectedPrinterName = null;
      _selectedPrinterUrl = null;
      await prefs.remove(_kPrinterName);
      await prefs.remove(_kPrinterUrl);
    } else {
      _selectedPrinterName = printer.name;
      _selectedPrinterUrl = printer.url;
      // التعرف التلقائي على حجم ورق الطابعة وتطبيقه
      _paperSize = detectPaperSize(printer);
      await prefs.setString(_kPrinterName, _selectedPrinterName!);
      await prefs.setString(_kPrinterUrl, _selectedPrinterUrl ?? _selectedPrinterName!);
      await prefs.setString(_kPaperSize, _paperSize);
    }
    notifyListeners();
  }

  Future<void> setPaperSize(String size) async {
    if (size != '80mm' && size != '58mm') return;
    _paperSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPaperSize, size);
  }

  Future<void> setPrintCustomerReceipt(bool value) async {
    _printCustomerReceipt = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrintReceipt, value);
  }

  Future<void> setPrintKitchenTicket(bool value) async {
    _printKitchenTicket = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrintKitchenTicket, value);
  }

  Future<void> setDirectSilentPrint(bool value) async {
    _directSilentPrint = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDirectSilentPrint, value);
  }

  Future<void> setPrintCopies(int copies) async {
    if (copies < 1 || copies > 5) return;
    _printCopies = copies;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrintCopies, copies);
  }

  Future<void> setSoundAlert(bool value) async {
    _soundAlert = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSoundAlert, value);
  }

  Future<void> setAutoOpenCashDrawer(bool value) async {
    _autoOpenCashDrawer = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoOpenCashDrawer, value);
  }

  Future<void> setCashDrawerPin(String pin) async {
    if (pin != 'pin2' && pin != 'pin5') return;
    _cashDrawerPin = pin;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCashDrawerPin, pin);
  }
}
