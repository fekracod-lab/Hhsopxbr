// حوار تفاصيل حالة المزامنة والاتصال (MADAR SHOP POS Sync Details Dialog)
// Presentation Layer — Clean Cashier-Friendly Health Snapshot

import 'package:flutter/material.dart';

import '../../../application/sync/commands/sync_commands.dart';
import '../../../domain/sync/enums/connectivity_state.dart';
import '../controllers/windows_pos_controller.dart';

class PosSyncDetailsDialog extends StatefulWidget {
  final WindowsPosController controller;

  const PosSyncDetailsDialog({
    super.key,
    required this.controller,
  });

  @override
  State<PosSyncDetailsDialog> createState() => _PosSyncDetailsDialogState();
}

class _PosSyncDetailsDialogState extends State<PosSyncDetailsDialog> {
  bool _isManualSyncRunning = false;

  Future<void> _triggerManualSync() async {
    setState(() => _isManualSyncRunning = true);
    try {
      await widget.controller.syncCoordinator.triggerSync(
        TriggerSyncCommand(
          businessId: widget.controller.businessId,
          branchId: widget.controller.branchId,
        ),
      );
      await widget.controller.refreshSyncStatus();
    } catch (_) {}
    if (mounted) setState(() => _isManualSyncRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final snapshot = widget.controller.syncStatus;
    final isOnline = snapshot.connectivityState == ConnectivityState.online;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1A1D27) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: isOnline ? Colors.green : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 10),
          const Text(
            'حالة المزامنة والشبكة',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Cairo'),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRow('حالة الاتصال:', isOnline ? 'متصل بالإنترنت' : 'غير متصل (أوفلاين)',
                valueColor: isOnline ? Colors.green : Colors.redAccent),
            const Divider(height: 16),
            _buildRow('أوامر قيد الانتظار في الصادر:', '${snapshot.pendingOutboxCount}'),
            const Divider(height: 16),
            _buildRow('أوامر جاري إرسالها:', '${snapshot.inFlightCount}'),
            const Divider(height: 16),
            _buildRow('أوامر فشلت بحاجة لإعادة المحاولة:', '${snapshot.failedCount}',
                valueColor: snapshot.failedCount > 0 ? Colors.redAccent : null),
            const Divider(height: 16),
            _buildRow('تعارضات بحاجة لمراجعة المشرف:', '${snapshot.conflictCount}',
                valueColor: snapshot.conflictCount > 0 ? Colors.orange : null),
            const Divider(height: 16),
            _buildRow(
              'آخر مزامنة ناجحة:',
              snapshot.lastSuccessfulSyncAt != null
                  ? '${snapshot.lastSuccessfulSyncAt!.hour.toString().padLeft(2, '0')}:${snapshot.lastSuccessfulSyncAt!.minute.toString().padLeft(2, '0')}:${snapshot.lastSuccessfulSyncAt!.second.toString().padLeft(2, '0')}'
                  : 'لم تتم مزامنة بعد',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo'))),
        ElevatedButton.icon(
          onPressed: _isManualSyncRunning ? null : _triggerManualSync,
          icon: _isManualSyncRunning
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.sync_rounded, size: 18),
          label: const Text('مزامنة الآن', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontFamily: 'Cairo', color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
