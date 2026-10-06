// وسيط طابعات الشبكة المباشرة عبر TCP/IP (MADAR SHOP Network Printer Driver)
// Pure Dart — Zero UI Dependencies

import 'dart:async';
import 'dart:io';

import '../../../domain/printing/contracts/i_printer_driver.dart';
import '../../../domain/printing/entities/print_job.dart';
import '../../../domain/printing/enums/printer_status.dart';
import '../../../domain/printing/failures/printing_failures.dart';
import '../../../domain/printing/value_objects/rendered_payload.dart';
import 'esc_pos_driver.dart';

class NetworkPrinterDriver implements IPrinterDriver {
  final String host;
  final int port;
  final Duration connectTimeout;
  final Duration writeTimeout;
  final int maxRetries;

  Socket? _socket;
  final EscPosDriver _escPosHelper = EscPosDriver();

  NetworkPrinterDriver({
    required this.host,
    this.port = 9100,
    this.connectTimeout = const Duration(seconds: 4),
    this.writeTimeout = const Duration(seconds: 5),
    this.maxRetries = 2,
  });

  @override
  Future<bool> connect({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      _socket = await Socket.connect(
        host,
        port,
        timeout: timeout < connectTimeout ? timeout : connectTimeout,
      );
      return true;
    } catch (_) {
      _socket = null;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _socket?.flush();
      await _socket?.close();
    } catch (_) {
      // تجاهل أخطاء الإغلاق
    } finally {
      _socket?.destroy();
      _socket = null;
    }
  }

  @override
  Future<void> printPayload(PrintJob job, RenderedPayload payload) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        if (_socket == null) {
          final ok = await connect();
          if (!ok) {
            throw PrinterOfflineFailure('تعذر الاتصال بطابعة الشبكة ($host:$port)');
          }
        }

        // إعداد البايتات بواسطة مولد أوامر ESC/POS
        final bytes = <int>[
          ...EscPosDriver.cmdInit,
          ...payload.rawBytes,
          ...EscPosDriver.cmdFeed3Lines,
          if (payload.hasDrawerKick) ...EscPosDriver.cmdOpenDrawer,
          if (payload.hasCutCommand) ...EscPosDriver.cmdCutPartial,
        ];

        _socket!.add(bytes);
        await _socket!.flush().timeout(writeTimeout, onTimeout: () {
          throw const PrintAckTimeoutFailure(
            'انتهت مهلة التأكيد بعد إرسال بيانات الشبكة (Network ACK Timeout)',
          );
        });

        // تم بنجاح
        return;
      } on PrintAckTimeoutFailure {
        // خطأ حرِج: لا نعيد الإرسال تلقائياً لتفادي تكرار طباعة الفاتورة
        rethrow;
      } catch (e) {
        await disconnect();
        if (attempts >= maxRetries) {
          throw PrinterHardwareFailure(
            'فشل إرسال أمر الطباعة عبر الشبكة بعد $attempts محاولات: $e',
          );
        }
        // تأخير زمني تصاعدي بسيط قبل إعادة المحاولة (Exponential backoff)
        await Future.delayed(Duration(milliseconds: 200 * attempts));
      }
    }
  }

  @override
  Future<bool> testPrint() async {
    final ok = await connect();
    if (!ok) return false;
    try {
      final bytes = <int>[
        ...EscPosDriver.cmdInit,
        ...'TEST NETWORK PRINT OK\n'.codeUnits,
        ...EscPosDriver.cmdFeed3Lines,
        ...EscPosDriver.cmdCutPartial,
      ];
      _socket!.add(bytes);
      await _socket!.flush().timeout(writeTimeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      await disconnect();
    }
  }

  @override
  Future<void> openCashDrawer() async {
    if (_socket == null) {
      final ok = await connect();
      if (!ok) throw const PrinterOfflineFailure('تعذر الاتصال بالطابعة لفتح الدرج');
    }
    _socket!.add(EscPosDriver.cmdOpenDrawer);
    await _socket!.flush();
  }

  @override
  Future<void> cutPaper() async {
    if (_socket == null) {
      final ok = await connect();
      if (!ok) throw const PrinterOfflineFailure('تعذر الاتصال بالطابعة لأمر القطع');
    }
    _socket!.add(EscPosDriver.cmdCutPartial);
    await _socket!.flush();
  }

  @override
  Future<PrinterStatus> getStatus() async {
    if (_socket == null) {
      final ok = await connect(timeout: const Duration(seconds: 2));
      if (!ok) return PrinterStatus.offline;
      await disconnect();
    }
    return PrinterStatus.online;
  }
}
