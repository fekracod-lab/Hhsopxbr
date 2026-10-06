// حوار اختيار أو تغيير العميل لنقطة البيع (MADAR SHOP POS Customer Dialog)
// Presentation Layer — Customer Lookup, Credit Availability & Walk-In Option

import 'package:flutter/material.dart';

import '../../../domain/sync/entities/cached_entities.dart';
import '../controllers/windows_pos_controller.dart';

class PosCustomerDialog extends StatefulWidget {
  final WindowsPosController controller;

  const PosCustomerDialog({
    super.key,
    required this.controller,
  });

  @override
  State<PosCustomerDialog> createState() => _PosCustomerDialogState();
}

class _PosCustomerDialogState extends State<PosCustomerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<CachedCustomer> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadSampleCustomers();
  }

  void _loadSampleCustomers() {
    // قائمة تجريبية أو محملة من الكاش المحلي
    _customers = [
      CachedCustomer(
        id: 'CUST-001',
        name: 'علي حسن التميمي',
        phone: '07701234567',
        creditBalanceMinorUnits: 2500000,
        creditLimitMinorUnits: 10000000,
        version: 1,
        fetchedAt: DateTime.now(),
      ),
      CachedCustomer(
        id: 'CUST-002',
        name: 'شركة الفرات للتجهيزات',
        phone: '07809876543',
        creditBalanceMinorUnits: 5000000,
        creditLimitMinorUnits: 50000000,
        version: 1,
        fetchedAt: DateTime.now(),
      ),
      CachedCustomer(
        id: 'CUST-003',
        name: 'محمد صادق الهاشمي',
        phone: '07505554433',
        creditBalanceMinorUnits: 0,
        creditLimitMinorUnits: 15000000,
        version: 1,
        fetchedAt: DateTime.now(),
      ),
    ];
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _customers.where((c) {
      return q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.phone.contains(q) ||
          c.id.toLowerCase().contains(q);
    }).toList();

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1D27) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.person_search_rounded, color: Color(0xFF1E88E5), size: 22),
          SizedBox(width: 10),
          Text('اختيار العميل (F2)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
        ],
      ),
      content: SizedBox(
        width: 460,
        height: 380,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو رقم الهاتف...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),

            // خيار زبون عام (Walk-in)
            ListTile(
              leading: const Icon(Icons.storefront_outlined, color: Colors.grey),
              title: const Text('زبون نقدي عام (Walk-in)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              subtitle: const Text('دفع نقدي أو فوري بدون فتح حساب آجل'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () {
                widget.controller.setCustomer(null);
                Navigator.pop(context);
              },
            ),
            const Divider(),

            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final customer = filtered[index];
                  final availableCredit = (customer.availableCreditMinorUnits / 100).toStringAsFixed(0);

                  return ListTile(
                    leading: const Icon(Icons.account_circle, color: Color(0xFF1E88E5)),
                    title: Text(customer.name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13.5)),
                    subtitle: Text('هاتف: ${customer.phone} • متاح آجل: $availableCredit د.ع', style: const TextStyle(fontSize: 11.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onTap: () {
                      widget.controller.setCustomer(customer);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
      ],
    );
  }
}
