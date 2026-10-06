// عقد العميل البرمجي لوكيل طباعة ويندوز (MADAR SHOP Windows Print Agent Client Contract)
// Pure Dart — Zero UI Dependencies

import '../entities/print_job.dart';
import '../enums/printer_status.dart';
import '../value_objects/rendered_payload.dart';

abstract class IPrintAgentClient {
  Future<bool> pingAgent({required String agentUrl});

  Future<void> sendJobToAgent({
    required String agentUrl,
    required PrintJob job,
    required RenderedPayload payload,
  });

  Future<PrinterStatus> getAgentPrinterStatus({
    required String agentUrl,
    required String printerName,
  });
}
