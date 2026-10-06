import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/parcel_delivery_controller.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'form_text_field.dart';
import 'place_selection_sheet.dart';

class ParcelRequestFormSheet extends StatefulWidget {
  const ParcelRequestFormSheet({super.key});

  @override
  State<ParcelRequestFormSheet> createState() => _ParcelRequestFormSheetState();
}

class _ParcelRequestFormSheetState extends State<ParcelRequestFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = context.read<ParcelDeliveryController>().state;
    _descriptionController.text = state.itemDescription;
    _recipientNameController.text = state.recipientName;
    _recipientPhoneController.text = state.recipientPhone;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ParcelDeliveryController>();

    return Container(
      decoration: BoxDecoration(
        color: app_colors.darkBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 0),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildLocationInfo(controller),
                    const SizedBox(height: 24),
                    _buildVehicleSelection(controller),
                    const SizedBox(height: 24),
                    _buildFormFields(controller),
                    const SizedBox(height: 32),
                    _buildPricingInfo(controller),
                    const SizedBox(height: 32),
                    _buildSubmitButton(controller),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: app_colors.darkSubText.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.local_shipping, color: app_colors.primaryColor, size: 28),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'تفاصيل طلب التوصيل',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: app_colors.darkText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo(ParcelDeliveryController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: app_colors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: app_colors.darkBorder),
      ),
      child: Column(
        children: [
          _buildLocationRow(
            icon: Icons.my_location,
            title: 'موقع الاستلام',
            address: 'موقعك الحالي',
            color: app_colors.primaryColor,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder:
                    (_) => ChangeNotifierProvider.value(
                      value: controller,
                      child: const PlaceSelectionSheet(),
                    ),
              );
            },
            child: _buildLocationRow(
              icon: Icons.location_on,
              title: 'موقع التسليم (اضغط لاختيار الوجهة)',
              address: controller.state.dropoffName,
              color: app_colors.successColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required String title,
    required String address,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: app_colors.darkSubText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: app_colors.darkText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleSelection(ParcelDeliveryController controller) {
    final vehicles = [
      {'id': 'motorcycle', 'name': 'دراجة نارية', 'icon': Icons.motorcycle, 'desc': 'طرود صغيرة'},
      {'id': 'بيك اب', 'name': 'بيك اب', 'icon': Icons.directions_car, 'desc': 'طرود متوسطة'},
      {'id': 'حمل', 'name': 'شاحنة حمل', 'icon': Icons.local_shipping, 'desc': 'طرود كبيرة'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نوع المركبة',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: app_colors.darkText,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
                vehicles.map((vehicle) {
                  final isSelected = controller.state.selectedVehicle == vehicle['id'];
                  return GestureDetector(
                    onTap: () => controller.setVehicle(vehicle['id'] as String),
                    child: Container(
                      margin: const EdgeInsets.only(left: 12),
                      padding: const EdgeInsets.all(16),
                      width: 110,
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? app_colors.primaryColor.withValues(alpha: 0.1)
                                : app_colors.darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? app_colors.primaryColor : app_colors.darkBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            vehicle['icon'] as IconData,
                            color: isSelected ? app_colors.primaryColor : app_colors.darkSubText,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            vehicle['name'] as String,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? app_colors.primaryColor : app_colors.darkText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vehicle['desc'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: app_colors.darkSubText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields(ParcelDeliveryController controller) {
    return Column(
      children: [
        FormTextField(
          controller: _descriptionController,
          label: 'وصف الطرد',
          hintText: 'مثال: وثائق - هدايا - ملابس...',
          prefixIcon: Icons.description,
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'يرجى إدخال وصف الطرد';
            }
            return null;
          },
          onChanged: (value) => controller.setParcelDescription(value),
        ),
        const SizedBox(height: 16),
        FormTextField(
          controller: _recipientNameController,
          label: 'اسم المستلم',
          hintText: 'أدخل اسم المستلم كاملاً',
          prefixIcon: Icons.person,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'يرجى إدخال اسم المستلم';
            }
            return null;
          },
          onChanged:
              (value) => controller.setRecipientDetails(
                name: value,
                phone: _recipientPhoneController.text,
              ),
        ),
        const SizedBox(height: 16),
        FormTextField(
          controller: _recipientPhoneController,
          label: 'رقم هاتف المستلم',
          hintText: '07xxxxxxxx',
          prefixIcon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'يرجى إدخال رقم الهاتف';
            }
            return null;
          },
          onChanged:
              (value) =>
                  controller.setRecipientDetails(name: _recipientNameController.text, phone: value),
        ),
      ],
    );
  }

  Widget _buildPricingInfo(ParcelDeliveryController controller) {
    final pricing = controller.state.pricingResult;

    if (pricing == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: app_colors.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: app_colors.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.receipt, color: app_colors.primaryColor),
              const SizedBox(width: 12),
              const Text(
                'تفاصيل السعر',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: app_colors.darkText,
                ),
              ),
              const Spacer(),
              Text(
                '${pricing.price.toInt()} د.ع',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: app_colors.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPricingItem(
                'المسافة',
                '${pricing.distanceKm.toStringAsFixed(1)} كم',
                Icons.linear_scale,
              ),
              _buildPricingItem('الوقت المتوقع', '${pricing.etaMinutes} دقيقة', Icons.access_time),
              _buildPricingItem('نوع الخدمة', 'توصيل سريع', Icons.delivery_dining),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: app_colors.darkSubText),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: app_colors.darkSubText),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: app_colors.darkText,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(ParcelDeliveryController controller) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: controller.state.isSubmitting ? null : () => _submitForm(controller),
        style: ElevatedButton.styleFrom(
          backgroundColor: app_colors.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child:
            controller.state.isSubmitting
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                )
                : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'تأكيد الطلب',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Future<void> _submitForm(ParcelDeliveryController controller) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    controller.setRecipientDetails(
      name: _recipientNameController.text,
      phone: _recipientPhoneController.text,
    );
    controller.setParcelDescription(_descriptionController.text);

    final result = await controller.submitRequest();

    if (result['success'] == true) {
      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog(result['requestId']);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['error'] ?? 'صار خطأ، حاول مرة ثانية')));
      }
    }
  }

  void _showSuccessDialog(String requestId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Column(
              children: [
                Icon(Icons.check_circle, color: app_colors.successColor, size: 60),
                SizedBox(height: 16),
                Text(
                  'تم تأكيد طلبك!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'رقم طلبك: # ${requestId.substring(requestId.length - 6).toUpperCase()}',
                  style: const TextStyle(color: app_colors.darkText),
                ),
                const SizedBox(height: 8),
                const Text(
                  'سيتم التواصل معك فور قبول الطلب',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: app_colors.darkSubText),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'حسناً',
                  style: TextStyle(
                    color: app_colors.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
