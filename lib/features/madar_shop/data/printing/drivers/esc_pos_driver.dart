// وسيط أوامر ESC/POS القياسية للطابعات الحرارية (MADAR SHOP ESC/POS Driver)
// Pure Dart — Zero UI Dependencies

import 'dart:convert';
import 'dart:typed_data';

import '../../../domain/printing/contracts/i_printer_driver.dart';
import '../../../domain/printing/entities/print_job.dart';
import '../../../domain/printing/enums/printer_status.dart';
import '../../../domain/printing/failures/printing_failures.dart';
import '../../../domain/printing/value_objects/rendered_payload.dart';

class EscPosDriver implements IPrinterDriver {
  bool _connected = false;
  PrinterStatus _status = PrinterStatus.online;

  // أوامر ESC/POS الثنائية القياسية
  static const List<int> cmdInit = [0x1B, 0x40]; // ESC @
  static const List<int> cmdCutFull = [0x1D, 0x56, 0x00]; // GS V 0
  static const List<int> cmdCutPartial = [0x1D, 0x56, 0x01]; // GS V 1
  static const List<int> cmdOpenDrawer = [0x1B, 0x70, 0x00, 0x19, 0xFA]; // ESC p 0 25 250
  static const List<int> cmdFeed3Lines = [0x1B, 0x64, 0x03]; // ESC d 3

  final List<Uint8List> transmittedPackets = [];

  @override
  Future<bool> connect({Duration timeout = const Duration(seconds: 5)}) async {
    _connected = true;
    _status = PrinterStatus.online;
    return true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<void> printPayload(PrintJob job, RenderedPayload payload) async {
    if (!_connected) {
      throw const PrinterOfflineFailure('تعذر الإرسال: الطابعة غير متصلة');
    }

    final bytesBuilder = BytesBuilder();

    // 1. تهيئة الطابعة
    bytesBuilder.add(cmdInit);

    // 2. حمولة البيانات
    bytesBuilder.add(payload.rawBytes);

    // 3. تغذية الورق لضمان خروج النص من مسار القاطع
    bytesBuilder.add(cmdFeed3Lines);

    // 4. فتح الدرج إن وجد
    if (payload.hasDrawerKick) {
      bytesBuilder.add(cmdOpenDrawer);
    }

    // 5. قطع الورق إن وجد
    if (payload.hasCutCommand) {
      bytesBuilder.add(cmdCutPartial);
    }

    final packet = bytesBuilder.toBytes();
    transmittedPackets.add(packet);
  }

  @override
  Future<bool> testPrint() async {
    if (!_connected) return false;
    final testText = '--- MADAR SHOP TEST PRINT ---\nOK\n';
    final payload = RenderedPayload(
      rawBytes: utf8.encode(testText),
      plainText: testText,
      characterWidth: 32,
      lineCount: 2,
    );
    final dummyJob = PrintJob(
      id: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
      businessId: 'test_biz',
      branchId: 'test_branch',
      printerId: 'test_printer',
      documentId: 'TEST-DOC',
      documentType: 'TEST',
      paperProfile: 'THERMAL_80MM',
      copies: 1,
      idempotencyKey: 'TEST-KEY',
      createdAt: DateTime.now(),
    );
    await printPayload(dummyJob, payload);
    return true;
  }

  @override
  Future<void> openCashDrawer() async {
    if (!_connected) {
      throw const PrinterOfflineFailure('الطابعة غير متصلة لفتح الدرج');
    }
    transmittedPackets.add(Uint8List.fromList(cmdOpenDrawer));
  }

  @override
  Future<void> cutPaper() async {
    if (!_connected) {
      throw const PrinterOfflineFailure('الطابعة غير متصلة لأمر القطع');
    }
    transmittedPackets.add(Uint8List.fromList(cmdCutPartial));
  }

  @override
  Future<PrinterStatus> getStatus() async {
    return _status;
  }

  void setStatus(PrinterStatus status) {
    _status = status;
  }
}
