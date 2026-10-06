import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/database/local_database_service.dart';
import '../features/pos/domain/pos_order.dart';
import 'printer_settings_service.dart';
import 'thermal_printer_service.dart';

/// حالة مهمة الطباعة في طابور العمليات
enum PrintJobStatus {
  pending,   // في الانتظار
  printing,  // جاري الإرسال للطابعة
  printed,   // تمت الطباعة بنجاح
  failed,    // فشلت الطباعة (نفاد ورق / انقطاع كابل / الطابعة غير متصلة)
}

/// كائن مهمة الطباعة
class PrintJob {
  final String jobId;
  final String orderId;
  final String? printerId;
  final PrintJobStatus status;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? printedAt;
  final Map<String, dynamic> payload;

  PrintJob({
    required this.jobId,
    required this.orderId,
    this.printerId,
    required this.status,
    required this.attempts,
    this.lastError,
    required this.createdAt,
    this.printedAt,
    required this.payload,
  });

  factory PrintJob.fromMap(Map<String, dynamic> map) {
    PrintJobStatus parseStatus(String? s) {
      switch (s) {
        case 'printing':
          return PrintJobStatus.printing;
        case 'printed':
          return PrintJobStatus.printed;
        case 'failed':
          return PrintJobStatus.failed;
        default:
          return PrintJobStatus.pending;
      }
    }

    Map<String, dynamic> parsePayload(dynamic raw) {
      if (raw is Map<String, dynamic>) return raw;
      if (raw is String) {
        try {
          return jsonDecode(raw);
        } catch (_) {}
      }
      return {};
    }

    return PrintJob(
      jobId: map['job_id'] ?? map['jobId'] ?? '',
      orderId: map['order_id'] ?? map['orderId'] ?? '',
      printerId: map['printer_id'] ?? map['printerId'],
      status: parseStatus(map['status']),
      attempts: (map['attempts'] ?? 0) as int,
      lastError: map['last_error'] ?? map['lastError'],
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      printedAt: DateTime.tryParse(map['printed_at']?.toString() ?? ''),
      payload: parsePayload(map['receipt_payload_json'] ?? map['payload']),
    );
  }
}

/// خدمة إدارة طابور الطباعة المتين (Robust Print Queue Service)
/// تتعامل مع انقطاع الطابعة، نفاد الورق، إعادة المحاولة التلقائية واليدوية
class PrintQueueService {
  static final PrintQueueService instance = PrintQueueService._internal();
  PrintQueueService._internal();

  final _uuid = const Uuid();
  Timer? _autoRetryTimer;

  // تيارات أحداث الطابور للواجهة التفاعلية
  final _failedJobsController = StreamController<List<PrintJob>>.broadcast();
  Stream<List<PrintJob>> get failedJobsStream => _failedJobsController.stream;

  List<PrintJob> _currentFailedJobs = [];
  List<PrintJob> get currentFailedJobs => List.unmodifiable(_currentFailedJobs);
  int get failedCount => _currentFailedJobs.length;

  /// بدء خدمة الطابور والفحص الدوري
  void start() {
    _autoRetryTimer?.cancel();
    _refreshQueue();

    // مؤقت فحص دوري كل 20 ثانية لمحاولة إعادة طباعة الفواتير المعلقة
    _autoRetryTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      retryAllFailedJobs(isAuto: true);
    });
  }

  /// إيقاف الخدمة
  void stop() {
    _autoRetryTimer?.cancel();
    _autoRetryTimer = null;
  }

  /// تحديث قائمة المهام الفاشلة المعلقة وبثها للواجهة
  Future<void> _refreshQueue() async {
    try {
      final rows = await LocalDatabaseService.instance.getActiveOrFailedPrintJobs();
      _currentFailedJobs = rows.map((e) => PrintJob.fromMap(e)).where((job) => job.status == PrintJobStatus.failed).toList();
      _failedJobsController.add(_currentFailedJobs);
    } catch (e) {
      debugPrint('[PrintQueueService] Error refreshing queue: $e');
    }
  }

  /// إدراج مهمة طباعة جديدة وتنفيذها فوراً
  Future<bool> enqueueAndPrint({
    required PosOrder order,
    String restaurantName = 'مطعم مدار',
    String restaurantPhone = '',
    String restaurantAddress = '',
    bool isKitchenTicket = false,
  }) async {
    final jobId = _uuid.v4();
    final settings = PrinterSettingsService.instance;
    await settings.init();

    final payload = {
      'order': order.toMap(),
      'restaurantName': restaurantName,
      'restaurantPhone': restaurantPhone,
      'restaurantAddress': restaurantAddress,
      'isKitchenTicket': isKitchenTicket,
    };

    // 1. تسجيل المهمة في SQLite بحالة pending
    await LocalDatabaseService.instance.insertPrintJob(
      jobId: jobId,
      orderId: order.orderId,
      printerId: settings.selectedPrinterName,
      payload: payload,
      status: 'pending',
    );

    // 2. تحديث الحالة إلى printing وتنفيذ الطباعة الفعلية
    await LocalDatabaseService.instance.updatePrintJobStatus(jobId: jobId, status: 'printing');

    try {
      final success = await ThermalPrinterService.printOrder(
        order: order,
        restaurantName: restaurantName,
        restaurantPhone: restaurantPhone,
        restaurantAddress: restaurantAddress,
      );

      if (success) {
        await LocalDatabaseService.instance.updatePrintJobStatus(jobId: jobId, status: 'printed');
        debugPrint('[PrintQueueService] Job $jobId for order #${order.orderId} printed successfully.');
        await _refreshQueue();
        return true;
      } else {
        const errorMsg = 'تعذر الوصول إلى الطابعة أو لم يتم تأكيد خروج الورقة';
        await LocalDatabaseService.instance.updatePrintJobStatus(jobId: jobId, status: 'failed', error: errorMsg);
        debugPrint('[PrintQueueService] Job $jobId failed: $errorMsg');
        await _refreshQueue();
        return false;
      }
    } catch (e) {
      final errorMsg = 'خطأ أثناء محاولة الطباعة: $e';
      await LocalDatabaseService.instance.updatePrintJobStatus(jobId: jobId, status: 'failed', error: errorMsg);
      debugPrint('[PrintQueueService] Job $jobId exception: $e');
      await _refreshQueue();
      return false;
    }
  }

  /// إعادة محاولة طباعة مهمة فاشلة محددة
  Future<bool> retryJob(String jobId) async {
    try {
      final rows = await LocalDatabaseService.instance.getActiveOrFailedPrintJobs();
      final match = rows.where((r) => (r['job_id'] ?? r['jobId']) == jobId).firstOrNull;
      if (match == null) return false;

      final job = PrintJob.fromMap(match);
      final orderMap = job.payload['order'] as Map<String, dynamic>? ?? {};
      final order = PosOrder.fromMap(orderMap, job.orderId);

      await LocalDatabaseService.instance.updatePrintJobStatus(jobId: jobId, status: 'printing');

      final success = await ThermalPrinterService.printOrder(
        order: order,
        restaurantName: job.payload['restaurantName'] ?? 'مطعم مدار',
        restaurantPhone: job.payload['restaurantPhone'] ?? '',
        restaurantAddress: job.payload['restaurantAddress'] ?? '',
      );

      if (success) {
        await LocalDatabaseService.instance.updatePrintJobStatus(jobId: jobId, status: 'printed');
        await _refreshQueue();
        return true;
      } else {
        await LocalDatabaseService.instance.updatePrintJobStatus(
          jobId: jobId,
          status: 'failed',
          error: 'فشلت إعادة المحاولة - يرجى التحقق من اتصال الطابعة',
        );
        await _refreshQueue();
        return false;
      }
    } catch (e) {
      await LocalDatabaseService.instance.updatePrintJobStatus(
        jobId: jobId,
        status: 'failed',
        error: e.toString(),
      );
      await _refreshQueue();
      return false;
    }
  }

  /// إعادة محاولة طباعة كافة الفواتير الفاشلة دفعة واحدة
  Future<void> retryAllFailedJobs({bool isAuto = false}) async {
    await _refreshQueue();
    if (_currentFailedJobs.isEmpty) return;

    if (!isAuto) {
      debugPrint('[PrintQueueService] Manual retry triggered for ${_currentFailedJobs.length} failed jobs.');
    }

    for (final job in _currentFailedJobs) {
      await retryJob(job.jobId);
    }
  }
}
