// شريط الحالة العلوي لنقطة البيع (MADAR SHOP POS Top Status Bar)
// Presentation Layer — Clean Info Hierarchy & Live Indicators

import 'package:flutter/material.dart';

import '../../../domain/printing/enums/printer_status.dart';
import '../../../domain/sync/enums/connectivity_state.dart';
import '../controllers/windows_pos_controller.dart';
import 'pos_sync_details_dialog.dart';

class PosTopStatusBar extends StatelessWidget {
  final WindowsPosController controller;
  final VoidCallback? onLogout;

  const PosTopStatusBar({
    super.key,
    required this.controller,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final syncSnapshot = controller.syncStatus;
    final isOnline = syncSnapshot.connectivityState == ConnectivityState.online;
    final isSyncing = syncSnapshot.isSyncing;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF232734) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 1. عنوان واسم المتجر والفرع
          Flexible(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Color(0xFF1E88E5), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    controller.businessId.isNotEmpty ? controller.businessId : 'متجر مدار',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '• ${controller.branchId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),
          Container(width: 1, height: 20, color: Colors.grey.withAlpha(50)),
          const SizedBox(width: 12),

          // 2. بيانات الكاشير والمحطة
          Flexible(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline_rounded, size: 16, color: isDark ? Colors.white60 : Colors.black54),
                  const SizedBox(width: 6),
                  Text(
                    controller.cashierName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      controller.terminalId,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // 3. شارات المزامنة والطباعة وزر الخروج
          Flexible(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // شارة حالة المزامنة والاتصال
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => PosSyncDetailsDialog(controller: controller),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSyncing
                            ? Colors.orange.withAlpha(25)
                            : (isOnline ? Colors.green.withAlpha(25) : Colors.red.withAlpha(25)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSyncing
                              ? Colors.orange.withAlpha(70)
                              : (isOnline ? Colors.green.withAlpha(70) : Colors.red.withAlpha(70)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSyncing
                                ? Icons.sync_rounded
                                : (isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded),
                            size: 16,
                            color: isSyncing
                                ? Colors.orange
                                : (isOnline ? Colors.green : Colors.red),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isSyncing
                                ? 'جاري المزامنة...'
                                : (isOnline ? 'متصل' : 'بدون اتصال (أوفلاين)'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                              color: isSyncing
                                  ? Colors.orange
                                  : (isOnline ? Colors.green : Colors.red),
                            ),
                          ),
                          if (syncSnapshot.pendingOutboxCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${syncSnapshot.pendingOutboxCount}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // شارة الطابعة
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.print_outlined,
                          size: 16,
                          color: controller.printerState == PrinterStatus.online
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          controller.printerState == PrinterStatus.online
                              ? 'الطابعة جاهزة'
                              : (controller.printerState == PrinterStatus.offline
                                  ? 'الطابعة غير متصلة'
                                  : 'الطابعة غير معروفة'),
                          style: const TextStyle(fontSize: 11.5, fontFamily: 'Cairo'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // زر إغلاق الجلسة أو الخروج
                  IconButton(
                    icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 20),
                    tooltip: 'إغلاق الوردية / تسجيل الخروج (F10)',
                    onPressed: onLogout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
