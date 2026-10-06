import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// نافذة اختيار وتحديث حالة المحاسبة الأسبوعية
class AccountingStatusDialog extends StatelessWidget {
  final String tabName;
  final DateTime weekStart;
  final String currentStatus;
  final Future<void> Function(String newStatus, DateTime? postponedToDate) onStatusSelected;

  const AccountingStatusDialog({
    super.key,
    required this.tabName,
    required this.weekStart,
    required this.currentStatus,
    required this.onStatusSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required String tabName,
    required DateTime weekStart,
    required String currentStatus,
    required Future<void> Function(String newStatus, DateTime? postponedToDate) onStatusSelected,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AccountingStatusDialog(
        tabName: tabName,
        weekStart: weekStart,
        currentStatus: currentStatus,
        onStatusSelected: onStatusSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'تغيير حالة المحاسبة الأسبوعية',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusOption(context, 'محاسب (تم التسوية)', 'paid'),
            const Divider(height: 1),
            _buildStatusOption(context, 'غير محاسب (معلق)', 'unpaid'),
            const Divider(height: 1),
            _buildStatusOption(context, 'مؤجل (تأجيل الدفع)', 'postponed', isPostponedOption: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(
    BuildContext context,
    String label,
    String value, {
    bool isPostponedOption = false,
  }) {
    final isSelected = currentStatus == value;
    const primaryColor = Color(0xFF00BFA5);

    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? primaryColor : null,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: primaryColor) : null,
      onTap: () async {
        Navigator.pop(context);
        if (isPostponedOption) {
          final chosenDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now().add(const Duration(days: 1)),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF00BFA5),
                    onPrimary: Colors.white,
                  ),
                ),
                child: child!,
              );
            },
          );

          if (chosenDate != null && context.mounted) {
            final formattedDate = DateFormat('yyyy/MM/dd').format(chosenDate);
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('تأكيد وإجراء التأجيل', style: TextStyle(fontWeight: FontWeight.bold)),
                content: Text(
                  'تحذير: هل أنت متأكد من تأجيل محاسبة هذا الأسبوع إلى تاريخ $formattedDate؟',
                  style: const TextStyle(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء', style: TextStyle()),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('تأكيد التأجيل', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await onStatusSelected('postponed', chosenDate);
            }
          }
        } else {
          await onStatusSelected(value, null);
        }
      },
    );
  }
}
