import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';


import '../../../../core/theme/app_theme.dart';
import '../../../../services/printer_settings_service.dart';
import '../../../../services/thermal_printer_service.dart';
import 'receipt_design_showcase_dialog.dart';

/// نافذة إعدادات الطابعة الحرارية والطباعة المباشرة التلقائية لنظام مطاعم مدار
class PrinterSettingsDialog extends StatefulWidget {
  const PrinterSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const PrinterSettingsDialog(),
    );
  }

  @override
  State<PrinterSettingsDialog> createState() => _PrinterSettingsDialogState();
}

class _PrinterSettingsDialogState extends State<PrinterSettingsDialog> {
  final _settings = PrinterSettingsService.instance;

  bool _isLoadingPrinters = false;
  bool _isTestingPrint = false;
  String? _testMessage;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() => _isLoadingPrinters = true);
    await _settings.refreshPrinters();
    if (mounted) {
      setState(() => _isLoadingPrinters = false);
    }
  }

  Future<void> _runTestPrint() async {
    setState(() {
      _isTestingPrint = true;
      _testMessage = null;
    });
    HapticFeedback.mediumImpact();

    try {
      final success = await ThermalPrinterService.printTestReceipt();
      if (mounted) {
        setState(() {
          _isTestingPrint = false;
          _testSuccess = success;
          _testMessage = success
              ? 'تم إرسال أمر الطباعة التجريبية بنجاح إلى الطابعة! ✅'
              : 'فشلت الطباعة التجريبية. يرجى التأكد من تشغيل الطابعة وتوصيل كابل USB أو الشبكة.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTestingPrint = false;
          _testSuccess = false;
          _testMessage = 'حدث خطأ أثناء الطباعة: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: PosTheme.surfaceDark,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: PosTheme.borderDark, width: 1.2),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width.clamp(320.0, 560.0),
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // رأس النافذة
              _buildHeader(),
              const SizedBox(height: 16),
              const Divider(color: PosTheme.borderDark, height: 1),
              const SizedBox(height: 16),

              // محتوى الإعدادات القابل للتمرير
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // قسم الطابعة المحددة
                      _buildPrinterSelector(),
                      const SizedBox(height: 18),

                      // تفعيل الطباعة التلقائية للطلبات الواردة
                      _buildAutoPrintSwitch(),
                      const SizedBox(height: 18),

                      // مقاس الورق (80mm vs 58mm)
                      _buildPaperSizeSelector(),
                      const SizedBox(height: 18),

                      // تفضيلات نوع الفواتير والنسخ
                      _buildPrintOptions(),
                      const SizedBox(height: 16),

                      // بطاقة معاينة تصاميم الفواتير والتقارير الجديدة المعتمدة
                      _buildShowcaseBanner(),
                      const SizedBox(height: 16),

                      // إعدادات درج النقد والنبضة
                      _buildCashDrawerOptions(),
                      const SizedBox(height: 16),

                      // رسالة نتيجة الفحص التجريبي
                      if (_testMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _testSuccess == true
                                ? PosTheme.success.withValues(alpha: 0.15)
                                : PosTheme.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _testSuccess == true ? PosTheme.success : PosTheme.danger,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _testSuccess == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                color: _testSuccess == true ? PosTheme.success : PosTheme.danger,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _testMessage!,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: _testSuccess == true ? Colors.greenAccent : Colors.redAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(color: PosTheme.borderDark, height: 1),
              const SizedBox(height: 16),

              // الأزرار السفلية
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: PosTheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.print_rounded, color: PosTheme.accent, size: 24),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إعدادات الطابعة الحرارية والطباعة التلقائية',
              style: GoogleFonts.ibmPlexSansArabic(
                color: PosTheme.textLight,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'ضبط الطابعة للطباعة المباشرة لطلبات الزبائن والكاشير',
              style: GoogleFonts.ibmPlexSansArabic(
                color: PosTheme.textMuted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: PosTheme.textMuted),
          tooltip: 'إغلاق',
        ),
      ],
    );
  }

  Widget _buildPrinterSelector() {
    final printers = _settings.cachedPrinters;
    final selectedName = _settings.selectedPrinterName;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'اختيار الطابعة الحرارية (Windows)',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: PosTheme.textLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              InkWell(
                onTap: _loadPrinters,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoadingPrinters)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: PosTheme.accent),
                        )
                      else
                        const Icon(Icons.refresh_rounded, size: 16, color: PosTheme.accent),
                      const SizedBox(width: 6),
                      Text(
                        'تحديث القائمة',
                        style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.accent, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (printers.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'لم يتم العثور على طابعات معرفة في ويندوز. تأكد من توصيل الطابعة وتثبيت التعريف الخاص بها.',
                      style: GoogleFonts.ibmPlexSansArabic(color: Colors.amber, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: printers.any((p) => p.name == selectedName) ? selectedName : null,
              isExpanded: true,
              dropdownColor: PosTheme.surfaceDark,
              decoration: InputDecoration(
                filled: true,
                fillColor: PosTheme.bgDark,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: PosTheme.borderDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: PosTheme.borderDark),
                ),
              ),
              hint: Text(
                'اختر الطابعة (أو اتركها للافتراضية)',
                style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textDisabled, fontSize: 12),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    'الطابعة الافتراضية للويندوز (تلقائي)',
                    style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.gold, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                ...printers.map((p) {
                  return DropdownMenuItem<String>(
                    value: p.name,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            p.name,
                            style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textLight, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (p.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: PosTheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('افتراضية', style: TextStyle(color: PosTheme.accent, fontSize: 9)),
                          ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                if (val == null) {
                  _settings.setSelectedPrinter(null);
                } else {
                  final p = printers.firstWhere((element) => element.name == val);
                  _settings.setSelectedPrinter(p);
                }
                setState(() {});
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAutoPrintSwitch() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _settings.autoPrintEnabled
            ? PosTheme.primary.withValues(alpha: 0.12)
            : PosTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _settings.autoPrintEnabled ? PosTheme.primary.withValues(alpha: 0.5) : PosTheme.borderDark,
        ),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: PosTheme.accent,
        title: Text(
          'الطباعة التلقائية المباشرة عند وصول طلب جديد',
          style: GoogleFonts.ibmPlexSansArabic(
            color: PosTheme.textLight,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          'عند قيام الزبون بالطلب من مدار، تطبع الفاتورة فوراً دون الحاجة لفتح النافذة أو الضغط يدوياً',
          style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textMuted, fontSize: 11),
        ),
        value: _settings.autoPrintEnabled,
        onChanged: (val) {
          _settings.setAutoPrintEnabled(val);
          setState(() {});
        },
      ),
    );
  }

  Widget _buildPaperSizeSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'عرض ورق الطابعة الحرارية',
            style: GoogleFonts.ibmPlexSansArabic(
              color: PosTheme.textLight,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildPaperSizeOption(
                  label: '80 ملم (ورق عريض قياسي)',
                  sublabel: 'المقاس الأكثر شيوعاً في طابعات الكاشير',
                  sizeKey: '80mm',
                  isSelected: _settings.is80mm,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPaperSizeOption(
                  label: '58 ملم (ورق صغير)',
                  sublabel: 'طابعات البلوتوث والمحمولة الصغيرة',
                  sizeKey: '58mm',
                  isSelected: !_settings.is80mm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaperSizeOption({
    required String label,
    required String sublabel,
    required String sizeKey,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        _settings.setPaperSize(sizeKey);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? PosTheme.primary.withValues(alpha: 0.18) : PosTheme.bgDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? PosTheme.primary : PosTheme.borderDark,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? PosTheme.accent : PosTheme.textDisabled,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: isSelected ? PosTheme.textLight : PosTheme.textMuted,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              sublabel,
              style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textDisabled, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintOptions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'خيارات البونات والنسخ',
            style: GoogleFonts.ibmPlexSansArabic(
              color: PosTheme.textLight,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),

          // طباعة فاتورة الحساب للزبون
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: PosTheme.primary,
            title: Text(
              'طباعة فاتورة الحساب (مع تفاصيل الزبون والعنوان والأسعار)',
              style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textLight, fontSize: 12),
            ),
            value: _settings.printCustomerReceipt,
            onChanged: (val) {
              _settings.setPrintCustomerReceipt(val ?? true);
              setState(() {});
            },
          ),

          // طباعة بون المطبخ KOT
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: PosTheme.primary,
            title: Text(
              'طباعة بون المطبخ (KOT) للشيف (عناصر الوجبات والملاحظات بخط كبير)',
              style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textLight, fontSize: 12),
            ),
            value: _settings.printKitchenTicket,
            onChanged: (val) {
              _settings.setPrintKitchenTicket(val ?? false);
              setState(() {});
            },
          ),

          // طباعة صامتة ومباشرة بدون معاينة
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: PosTheme.primary,
            title: Text(
              'طباعة صامتة ومباشرة دون فتح نافذة معاينة (Direct Silent Print)',
              style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textLight, fontSize: 12),
            ),
            value: _settings.directSilentPrint,
            onChanged: (val) {
              _settings.setDirectSilentPrint(val ?? true);
              setState(() {});
            },
          ),

          // تنبيه صوتي
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: PosTheme.primary,
            title: Text(
              'تشغيل صوت إنذار الطلب الجديد فور وروده من مدار',
              style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textLight, fontSize: 12),
            ),
            value: _settings.soundAlert,
            onChanged: (val) {
              _settings.setSoundAlert(val ?? true);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCashDrawerOptions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosTheme.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'إعدادات درج النقد (Cash Drawer RJ11)',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: PosTheme.textLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await ThermalPrinterService.kickCashDrawer();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'تم إرسال نبضة فتح الدرج بنجاح' : 'تعذر فتح الدرج - تحقق من المنفذ وإعدادات الطابعة'),
                        backgroundColor: ok ? Colors.teal : Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.flash_on, size: 14, color: Colors.amberAccent),
                label: Text('اختبار فتح الدرج', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: Colors.amberAccent)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.amberAccent.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: PosTheme.primary,
            title: Text(
              'فتح درج النقد تلقائياً بعد تأكيد الدفع وطباعة الفاتورة',
              style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textLight, fontSize: 12),
            ),
            subtitle: Text(
              'تسلسل مشروط: لا يتم فتح الدرج إلا بعد إتمام الدفع النقدي وخروج الفاتورة',
              style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textMuted, fontSize: 10),
            ),
            value: _settings.autoOpenCashDrawer,
            onChanged: (val) {
              _settings.setAutoOpenCashDrawer(val ?? true);
              setState(() {});
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('منفذ إشارة النبضة:', style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textLight, fontSize: 12)),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('Pin 2 (Epson/Xprinter/Standard)'),
                selected: _settings.cashDrawerPin == 'pin2',
                onSelected: (_) {
                  _settings.setCashDrawerPin('pin2');
                  setState(() {});
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Pin 5 (Star/Other)'),
                selected: _settings.cashDrawerPin == 'pin5',
                onSelected: (_) {
                  _settings.setCashDrawerPin('pin5');
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// بطاقة إبراز التصاميم الـ 7 الجديدة
  Widget _buildShowcaseBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2330),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosTheme.accent.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: PosTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.palette_rounded, color: PosTheme.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'التصاميم الحرارية المعتمدة الجديدة (7 نماذج)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'صالة، توصيل، سفري، قسيمة المطبخ، وتقارير المبيعات وطرق الدفع',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => ReceiptDesignShowcaseDialog.show(context),
            icon: const Icon(Icons.visibility_rounded, size: 16),
            label: Text(
              'معاينة النماذج 🎨',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 11.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: PosTheme.accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // زر الطباعة التجريبية
        ElevatedButton.icon(
          onPressed: _isTestingPrint ? null : _runTestPrint,
          icon: _isTestingPrint
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.receipt_long_rounded, size: 18),
          label: Text(
            _isTestingPrint ? 'جاري الطباعة...' : 'تجربة الطباعة الآن',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: PosTheme.cardDark,
            foregroundColor: PosTheme.accent,
            side: const BorderSide(color: PosTheme.primary),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 10),

        // زر معاينة النماذج
        OutlinedButton.icon(
          onPressed: () => ReceiptDesignShowcaseDialog.show(context),
          icon: const Icon(Icons.grid_view_rounded, size: 16),
          label: Text(
            'معاينة الـ 7 نماذج 🎨',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Color(0xFF3E475C)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const Spacer(),

        // زر تم وحفظ
        ElevatedButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: PosTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            'حفظ وإغلاق',
            style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
