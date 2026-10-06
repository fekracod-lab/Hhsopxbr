// عميل وكيل طباعة ويندوز للاختبار والمحاكاة (MADAR SHOP Mock Print Agent Client)
// Pure Dart — Zero UI Dependencies

import '../../../domain/printing/contracts/i_print_agent_client.dart';
import '../../../domain/printing/entities/print_job.dart';
import '../../../domain/printing/enums/printer_status.dart';
import '../../../domain/printing/failures/printing_failures.dart';
import '../../../domain/printing/value_objects/rendered_payload.dart';

class MockPrintAgentClient implements IPrintAgentClient {
  bool isAgentReachable = true;
  PrinterStatus remotePrinterStatus = PrinterStatus.online;
  final List<PrintJob> receivedJobs = [];
  final List<RenderedPayload> receivedPayloads = [];

  @override
  Future<bool> pingAgent({required String agentUrl}) async {
    return isAgentReachable;
  }

  @override
  Future<void> sendJobToAgent({
    required String agentUrl,
    required PrintJob job,
    required RenderedPayload payload,
  }) async {
    if (!isAgentReachable) {
      throw const PrinterOfflineFailure('وكيل الطباعة المحلي غير متاح أو لا يستجيب');
    }
    receivedJobs.add(job);
    receivedPayloads.add(payload);
  }

  @override
  Future<PrinterStatus> getAgentPrinterStatus({
    required String agentUrl,
    required String printerName,
  }) async {
    if (!isAgentReachable) {
      return PrinterStatus.offline;
    }
    return remotePrinterStatus;
  }

  void reset() {
    isAgentReachable = true;
    remotePrinterStatus = PrinterStatus.online;
    receivedJobs.clear();
    receivedPayloads.clear();
  }
}
