import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/pos_language_controller.dart';
import '../../application/pos_provider.dart';

/// نافذة إدخال وتعديل بيانات عميل التوصيل (الاسم، رقم الهاتف، العنوان، والملاحظات)
/// تدعم الحفظ التلقائي والاقتراح الذكي من العملاء السابقين المسجلين
class DeliveryDetailsDialog extends StatefulWidget {
  final PosProvider pos;

  const DeliveryDetailsDialog({super.key, required this.pos});

  static Future<bool?> show(BuildContext context, PosProvider pos) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DeliveryDetailsDialog(pos: pos),
    );
  }

  @override
  State<DeliveryDetailsDialog> createState() => _DeliveryDetailsDialogState();
}

class _DeliveryDetailsDialogState extends State<DeliveryDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;

  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  List<Map<String, String>> _recentCustomers = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pos.customerName == 'زبون مباشر' ? '' : widget.pos.customerName);
    _phoneController = TextEditingController(text: widget.pos.customerPhone);
    _addressController = TextEditingController(text: widget.pos.deliveryAddress);
    _notesController = TextEditingController(text: widget.pos.orderNotes);

    _loadRecentDeliveryCustomers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentDeliveryCustomers() async {
    if (_uid.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('orders')
          .where('restaurantId', isEqualTo: _uid)
          .where('orderType', isEqualTo: 'delivery')
          .limit(25)
          .get();

      final Map<String, Map<String, String>> uniqueCustomers = {};

      for (var doc in snap.docs) {
        final data = doc.data();
        final name = (data['customerName'] ?? '').toString().trim();
        final phone = (data['customerPhone'] ?? '').toString().trim();
        final addr = (data['deliveryAddress'] ?? '').toString().trim();

        if (name.isNotEmpty && name != 'زبون مباشر' && (phone.isNotEmpty || addr.isNotEmpty)) {
          final key = phone.isNotEmpty ? phone : name;
          if (!uniqueCustomers.containsKey(key)) {
            uniqueCustomers[key] = {
              'name': name,
              'phone': phone,
              'address': addr,
            };
          }
        }
      }

      if (mounted) {
        setState(() {
          _recentCustomers = uniqueCustomers.values.take(6).toList();
        });
      }
    } catch (_) {
    }
  }

  void _applyCustomer(Map<String, String> cust) {
    setState(() {
      _nameController.text = cust['name'] ?? '';
      _phoneController.text = cust['phone'] ?? '';
      _addressController.text = cust['address'] ?? '';
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final notes = _notesController.text.trim();

    widget.pos.setCustomerInfo(
      name: name.isNotEmpty ? name : 'زبون مباشر',
      phone: phone,
      address: address,
      notes: notes,
    );

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.posColors;
    final isEn = PosLanguageController.instance.isEnglish;

    return Directionality(
      textDirection: PosLanguageController.instance.textDirection,
      child: Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: c.border),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width.clamp(320.0, 520.0),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // رأس النافذة
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.accent.withValues(alpha: 0.25)),
                        ),
                        child: Icon(Icons.delivery_dining_rounded, color: c.accent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEn ? 'Delivery Order Details' : 'بيانات عميل التوصيل',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                            ),
                            Text(
                              isEn
                                  ? 'Enter customer name, phone, and delivery address'
                                  : 'تسجيل اسم الزبون ورقم الهاتف والعنوان لطباعتها بالفاتورة',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11.5,
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: Icon(Icons.close_rounded, color: c.textMuted),
                        splashRadius: 20,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Divider(color: c.border, height: 1),
                  const SizedBox(height: 16),

                  // اقتراحات العملاء السابقين السريعة
                  if (_recentCustomers.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.history_rounded, size: 15, color: c.accent),
                        const SizedBox(width: 6),
                        Text(
                          isEn ? 'Recent Delivery Customers:' : 'عملاء توصيل سابقين (اختيار سريع):',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _recentCustomers.map((cust) {
                        final name = cust['name'] ?? '';
                        final phone = cust['phone'] ?? '';
                        return InkWell(
                          onTap: () => _applyCustomer(cust),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: c.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_pin_circle_rounded, size: 14, color: c.accent),
                                const SizedBox(width: 5),
                                Text(
                                  phone.isNotEmpty ? '$name ($phone)' : name,
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    fontSize: 11,
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 1. اسم الزبون
                  Text(
                    isEn ? 'Customer Name *' : 'اسم العميل / المستلم *',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontSize: 13),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person_outline_rounded, color: c.accent, size: 18),
                      hintText: isEn ? 'e.g. Ahmed Ali' : 'مثال: أحمد علي',
                      hintStyle: GoogleFonts.ibmPlexSansArabic(color: c.textDisabled, fontSize: 12),
                      filled: true,
                      fillColor: c.card,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.accent, width: 1.5)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return isEn ? 'Customer name is required' : 'يرجى كتابة اسم العميل';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // 2. رقم الهاتف
                  Text(
                    isEn ? 'Phone Number *' : 'رقم هاتف العميل *',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.phone_outlined, color: c.accent, size: 18),
                      hintText: isEn ? '07XXXXXXXXX' : '07XXXXXXXXX',
                      hintStyle: GoogleFonts.ibmPlexSansArabic(color: c.textDisabled, fontSize: 12),
                      filled: true,
                      fillColor: c.card,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.accent, width: 1.5)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return isEn ? 'Phone number is required' : 'يرجى كتابة رقم الهاتف للتواصل مع السائق';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // 3. عنوان التوصيل
                  Text(
                    isEn ? 'Delivery Address *' : 'عنوان التوصيل بالتفصيل *',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    textInputAction: TextInputAction.next,
                    style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Icon(Icons.location_on_outlined, color: const Color(0xFFEF4444), size: 20),
                      ),
                      hintText: isEn
                          ? 'Area, Street, Landmark, House / Apt #'
                          : 'المنطقة، الشارع، أقرب نقطة دالة، رقم المنزل أو الشقة',
                      hintStyle: GoogleFonts.ibmPlexSansArabic(color: c.textDisabled, fontSize: 12),
                      filled: true,
                      fillColor: c.card,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.accent, width: 1.5)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return isEn ? 'Delivery address is required' : 'يرجى كتابة عنوان التوصيل لتوجيه المندوب';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // 4. ملاحظات إضافية (اختياري)
                  Text(
                    isEn ? 'Delivery Instructions / Notes (Optional)' : 'ملاحظات وتوجيهات خاصة بالسائق (اختياري)',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _notesController,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                    style: GoogleFonts.ibmPlexSansArabic(color: c.textPrimary, fontSize: 12.5),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.note_alt_outlined, color: c.textMuted, size: 18),
                      hintText: isEn ? 'e.g. 2nd floor, call upon arrival' : 'مثال: الطابق الثاني، الاتصال عند الوصول',
                      hintStyle: GoogleFonts.ibmPlexSansArabic(color: c.textDisabled, fontSize: 11.5),
                      filled: true,
                      fillColor: c.card,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.accent, width: 1.5)),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // أزرار الحفظ والإلغاء
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.textPrimary,
                            side: BorderSide(color: c.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            isEn ? 'Cancel' : 'إلغاء',
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text(
                            isEn ? 'Save Details' : 'تثبيت بيانات التوصيل',
                            style: GoogleFonts.ibmPlexSansArabic(fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: c.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
