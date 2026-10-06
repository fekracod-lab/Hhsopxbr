import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/print_queue_service.dart';

/// شريط تنبيه طابور الطباعة (Print Queue Warning & Retry Bar)
/// يظهر أعلى شاشة الكاشير فقط عند وجود فواتير فشلت طباعتها
class PrintQueueIndicatorBar extends StatelessWidget {
  const PrintQueueIndicatorBar({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PrintJob>>(
      stream: PrintQueueService.instance.failedJobsStream,
      initialData: PrintQueueService.instance.currentFailedJobs,
      builder: (context, snapshot) {
        final failedJobs = snapshot.data ?? [];
        if (failedJobs.isEmpty) return const SizedBox.shrink();

        final count = failedJobs.length;
        final c = context.posColors;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: c.warning.withValues(alpha: context.isDarkMode ? 0.18 : 0.14),
              border: Border(
                bottom: BorderSide(color: c.warning.withValues(alpha: 0.55), width: 1.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.print_disabled_outlined,
                  color: c.warning,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تنبيه طابعة الكاشير: تعذر طباعة $count ${count == 1 ? "فاتورة" : "فواتير"}!',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: c.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        'يرجى التأكد من تشغيل الطابعة، توصيل الكابل، أو تزويد بكرة الورق.',
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: c.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('جاري إعادة إرسال الفواتير المعلقة إلى الطابعة...'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: c.warning,
                      ),
                    );
                    await PrintQueueService.instance.retryAllFailedJobs();
                  },
                  icon: Icon(Icons.replay_rounded, size: 16, color: c.warning),
                  label: Text(
                    'إعادة المحاولة الآن',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      color: c.warning,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.warning.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    elevation: 0,
                    side: BorderSide(color: c.warning.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}