import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/pos_constants.dart';
import '../../../../core/theme/app_theme.dart';

/// نافذة تخصيص الوجبة (الأحجام، الإضافات، الملاحظات) للكاشير
class ItemCustomizationModal extends StatefulWidget {
  final Map<String, dynamic> mealData;
  final Function({
    required double finalPrice,
    String? selectedSize,
    required List<Map<String, dynamic>> selectedAddons,
    String? notes,
  }) onConfirm;

  const ItemCustomizationModal({
    super.key,
    required this.mealData,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> mealData,
    required Function({
      required double finalPrice,
      String? selectedSize,
      required List<Map<String, dynamic>> selectedAddons,
      String? notes,
    }) onConfirm,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ItemCustomizationModal(mealData: mealData, onConfirm: onConfirm),
    );
  }

  @override
  State<ItemCustomizationModal> createState() => _ItemCustomizationModalState();
}

class _ItemCustomizationModalState extends State<ItemCustomizationModal> {
  late double _basePrice;
  String? _selectedSize;
  double _sizeAdditionalPrice = 0.0;
  final List<Map<String, dynamic>> _selectedAddons = [];
  final TextEditingController _notesController = TextEditingController();

  List<dynamic> _sizes = [];
  List<dynamic> _addons = [];

  @override
  void initState() {
    super.initState();
    _basePrice = (widget.mealData['price'] ?? 0).toDouble();
    _sizes = (widget.mealData['sizes'] as List<dynamic>?) ?? [];
    _addons = (widget.mealData['addons'] as List<dynamic>?) ?? [];

    if (_sizes.isNotEmpty) {
      final first = _sizes.first;
      if (first is Map) {
        _selectedSize = first['name']?.toString() ?? 'افتراضي';
        _sizeAdditionalPrice = (first['price'] ?? 0).toDouble();
      } else {
        _selectedSize = first.toString();
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _totalPrice {
    double sum = _basePrice + _sizeAdditionalPrice;
    for (var addon in _selectedAddons) {
      sum += (addon['price'] ?? 0).toDouble();
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.mealData['name'] ?? widget.mealData['title'] ?? 'تخصيص الوجبة';

    return Dialog(
      backgroundColor: PosTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: PosTheme.borderDark),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width.clamp(320.0, 520.0),
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // العنوان
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: PosTheme.textLight,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: PosTheme.textMuted),
                ),
              ],
            ),
            const Divider(color: PosTheme.borderDark, height: 24),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // قسم الأحجام إن وجدت
                    if (_sizes.isNotEmpty) ...[
                      Text(
                        'الحجم المطلوب:',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: PosTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _sizes.map((s) {
                          String sizeName = '';
                          double addPrice = 0.0;
                          if (s is Map) {
                            sizeName = s['name']?.toString() ?? '';
                            addPrice = (s['price'] ?? 0).toDouble();
                          } else {
                            sizeName = s.toString();
                          }

                          final isSelected = _selectedSize == sizeName;
                          return ChoiceChip(
                            label: Text(
                              addPrice > 0 ? '$sizeName (+${PosConstants.formatMoney(addPrice)})' : sizeName,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: isSelected ? Colors.white : PosTheme.textLight,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: PosTheme.primary,
                            backgroundColor: PosTheme.cardDark,
                            side: BorderSide(
                              color: isSelected ? PosTheme.primary : PosTheme.borderDark,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setState(() {
                                  _selectedSize = sizeName;
                                  _sizeAdditionalPrice = addPrice;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // قسم الإضافات إن وجدت
                    if (_addons.isNotEmpty) ...[
                      Text(
                        'الإضافات المتاحة:',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: PosTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._addons.map((a) {
                        final addonMap = a is Map ? Map<String, dynamic>.from(a) : {'name': a.toString(), 'price': 0};
                        final addonName = addonMap['name']?.toString() ?? '';
                        final addonPrice = (addonMap['price'] ?? 0).toDouble();

                        final isChecked = _selectedAddons.any((e) => e['name'] == addonName);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: PosTheme.cardDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isChecked ? PosTheme.primary : PosTheme.borderDark,
                            ),
                          ),
                          child: CheckboxListTile(
                            title: Text(
                              addonName,
                              style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textLight, fontSize: 13),
                            ),
                            subtitle: addonPrice > 0
                                ? Text(
                                    '+ ${PosConstants.formatMoney(addonPrice)}',
                                    style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.accent, fontSize: 11),
                                  )
                                : null,
                            value: isChecked,
                            activeColor: PosTheme.primary,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedAddons.add(addonMap);
                                } else {
                                  _selectedAddons.removeWhere((e) => e['name'] == addonName);
                                }
                              });
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 18),
                    ],

                    // قسم ملاحظات المطبخ الخاصة
                    Text(
                      'ملاحظات خاصة للمطبخ والشيف:',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: PosTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textLight, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'مثال: بدون بصل، زيادة صوص ثوم، مشوي جيداً...',
                        hintStyle: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textDisabled, fontSize: 12),
                        filled: true,
                        fillColor: PosTheme.cardDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: PosTheme.borderDark),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: PosTheme.primary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(color: PosTheme.borderDark, height: 24),

            // السعر الإجمالي وزر الإضافة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('السعر الإجمالي للقطعة:', style: GoogleFonts.ibmPlexSansArabic(color: PosTheme.textMuted, fontSize: 11)),
                    Text(
                      PosConstants.formatMoney(_totalPrice),
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: PosTheme.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onConfirm(
                      finalPrice: _totalPrice,
                      selectedSize: _selectedSize,
                      selectedAddons: _selectedAddons,
                      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 20),
                  label: Text(
                    'إضافة للسلة',
                    style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PosTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
