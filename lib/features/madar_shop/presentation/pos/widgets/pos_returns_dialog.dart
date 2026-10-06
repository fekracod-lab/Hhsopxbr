// حوار البحث عن الفاتورة وإجراء المرتجع السريع (MADAR SHOP POS Returns Dialog)
// Presentation Layer — Sale Lookup & Return Delegation to ReturnsCoordinator

import 'package:flutter/material.dart';

import '../../../application/returns/commands/returns_commands.dart';
import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/pos/entities/sale.dart';
import '../../../domain/returns/enums/return_reason.dart';
import '../controllers/windows_pos_controller.dart';

class PosReturnsDialog extends StatefulWidget {
  final WindowsPosController controller;

  const PosReturnsDialog({
    super.key,
    required this.controller,
  });

  @override
  State<PosReturnsDialog> createState() => _PosReturnsDialogState();
}

class _PosReturnsDialogState extends State<PosReturnsDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Sale> _foundSales = [];
  Sale? _selectedSale;
  bool _isSearching = false;
  bool _isProcessingReturn = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    setState(() => _isSearching = true);
    final sales = await widget.controller.lookupSales(query: _searchCtrl.text.trim());
    if (mounted) {
      setState(() {
        _foundSales = sales;
        _isSearching = false;
      });
    }
  }

  Future<void> _processReturn() async {
    if (_selectedSale == null || widget.controller.returnsCoordinator == null) return;
    setState(() {
      _isProcessingReturn = true;
      _statusMessage = null;
    });

    try {
      final sale = _selectedSale!;
      final itemsToReturn = sale.items.map((item) {
        return CreateReturnItemInput(
          originalSaleItemId: item.itemId,
          productId: item.productId,
          variantId: item.variantId,
          quantity: StockQuantity.fromDouble(item.quantity),
          reason: ReturnReason.defective,
        );
      }).toList();

      final command = CreateReturnOrderCommand(
        commandId: 'CMD-RET-${DateTime.now().microsecondsSinceEpoch}',
        businessId: widget.controller.businessId,
        branchId: widget.controller.branchId,
        originalSaleId: sale.id,
        returnNumber: 'RET-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
        items: itemsToReturn,
        actorId: widget.controller.identityCoordinator.currentUser?.userId ?? 'CASHIER',
        idempotencyKey: 'IDEMP-RET-${sale.id}-${DateTime.now().millisecondsSinceEpoch}',
      );

      final result = await widget.controller.returnsCoordinator!.createReturnOrder(command);

      if (mounted) {
        setState(() {
          _statusMessage = 'تم إنشاء المرتجع بنجاح #${result.order.returnNumber}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'تعذر معالجة المرتجع: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingReturn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1D27) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.assignment_return_outlined, color: Color(0xFF1E88E5), size: 24),
          SizedBox(width: 10),
          Text(
            'استرجاع فاتورة ومواد مرتجعة (F8)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Cairo'),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // شريط البحث عن الفاتورة
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onSubmitted: (_) => _performSearch(),
                    decoration: InputDecoration(
                      hintText: 'ابحث برقم الفاتورة أو الباركود أو العميل...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _performSearch,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('بحث', style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_statusMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(color: Color(0xFF1E88E5), fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // قائمة الفواتير الموجودة
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : (_foundSales.isEmpty
                      ? const Center(
                          child: Text('لا توجد فواتير مطابقة للبحث', style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
                        )
                      : ListView.separated(
                          itemCount: _foundSales.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final sale = _foundSales[index];
                            final isSelected = _selectedSale?.id == sale.id;

                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: const Color(0xFF1E88E5).withAlpha(20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              title: Text(
                                'فاتورة #${sale.saleNumber} — ${sale.grandTotal.toAmount().toStringAsFixed(0)} د.ع',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13.5),
                              ),
                              subtitle: Text(
                                'الوقت: ${sale.createdAt.hour}:${sale.createdAt.minute} • المواد: ${sale.items.length}',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF1E88E5)) : null,
                              onTap: () => setState(() => _selectedSale = sale),
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo'))),
        if (_selectedSale != null)
          ElevatedButton.icon(
            onPressed: _isProcessingReturn ? null : _processReturn,
            icon: _isProcessingReturn
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.assignment_return_rounded),
            label: const Text('معالجة المرتجع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
      ],
    );
  }
}
