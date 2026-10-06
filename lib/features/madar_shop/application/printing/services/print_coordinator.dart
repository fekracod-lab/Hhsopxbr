// المنسق المركزي لعمليات الطباعة وتأمين عدم التكرار (MADAR SHOP Print Coordinator Facade)
// Pure Dart — Zero UI Dependencies

import 'dart:async';

import '../../../domain/printing/contracts/i_print_job_repository.dart';
import '../../../domain/printing/contracts/i_printer_driver.dart';
import '../../../domain/printing/contracts/i_printer_profile_repository.dart';
import '../../../domain/printing/contracts/i_printer_repository.dart';
import '../../../domain/printing/contracts/i_printing_idempotency_store.dart';
import '../../../domain/printing/entities/print_job.dart';
import '../../../domain/printing/entities/printer.dart';
import '../../../domain/printing/entities/printer_profile.dart';
import '../../../domain/printing/enums/auto_print_policy.dart';
import '../../../domain/printing/enums/print_trigger_type.dart';
import '../../../domain/printing/failures/printing_failures.dart';
import '../../../domain/printing/rules/auto_print_evaluator.dart';
import '../../../domain/printing/value_objects/paper_profile.dart';
import '../commands/printing_commands.dart';
import '../events/printing_events.dart';
import '../renderers/renderer_factory.dart';
import 'print_queue_service.dart';

typedef DriverResolver = Future<IPrinterDriver> Function(Printer printer);

class PrintCoordinator {
  final IPrinterRepository _printerRepository;
  final IPrinterProfileRepository _profileRepository;
  final IPrintJobRepository _jobRepository;
  final IPrintingIdempotencyStore _idempotencyStore;
  final PrintQueueService _queueService;
  final DriverResolver _driverResolver;
  final PrintingEventListener? onEvent;
  final PrintingAuditListener? onAudit;

  // قفل التزامن لمنع سباق الطلبات المتزامنة لنفس الفاتورة (Document Concurrency Mutex)
  final Map<String, Future<void>> _activeLocks = {};

  PrintCoordinator({
    required IPrinterRepository printerRepository,
    required IPrinterProfileRepository profileRepository,
    required IPrintJobRepository jobRepository,
    required IPrintingIdempotencyStore idempotencyStore,
    required PrintQueueService queueService,
    required DriverResolver driverResolver,
    this.onEvent,
    this.onAudit,
  })  : _printerRepository = printerRepository,
        _profileRepository = profileRepository,
        _jobRepository = jobRepository,
        _idempotencyStore = idempotencyStore,
        _queueService = queueService,
        _driverResolver = driverResolver;

  /// تنفيذ أمر طباعة مع التحقق الصارم من العزل والتكرار وسياسات الفروع
  Future<PrintJob> submitPrintJob(SubmitPrintJobCommand command) async {
    final lockKey = '${command.businessId}_${command.document.documentId}';

    // انتظار أي معالجة جارية لنفس الوثيقة لضمان منع التكرار المتزامن
    while (_activeLocks.containsKey(lockKey)) {
      await _activeLocks[lockKey];
    }

    final completer = Completer<void>();
    _activeLocks[lockKey] = completer.future;

    try {
      return await _executeSubmit(command);
    } finally {
      _activeLocks.remove(lockKey);
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  static int _jobCounter = 0;

  Future<PrintJob> _executeSubmit(SubmitPrintJobCommand command) async {
    // 1. التحقق من مفتاح عدم التكرار المباشر
    final keyExists = await _idempotencyStore.hasKey(
      businessId: command.businessId,
      idempotencyKey: command.idempotencyKey,
    );
    if (keyExists) {
      final existingJobId = await _idempotencyStore.getJobIdForKey(
        businessId: command.businessId,
        idempotencyKey: command.idempotencyKey,
      );
      if (existingJobId != null) {
        final existingJob = await _jobRepository.getJobById(
          businessId: command.businessId,
          jobId: existingJobId,
        );
        if (existingJob != null) {
          return existingJob;
        }
      }
      throw DuplicatePrintRequestFailure(
        'طلب الطباعة مكرر بالمفتاح (${command.idempotencyKey})',
      );
    }

    // 2. التحقق من منع التكرار التلقائي (Auto-Print Idempotency)
    if (command.triggerType == PrintTriggerType.autoPrint) {
      final alreadyAutoPrinted = await _idempotencyStore.hasAutoPrintExecuted(
        businessId: command.businessId,
        documentId: command.document.documentId,
      );
      if (alreadyAutoPrinted) {
        throw const DuplicateAutoPrintFailure(
          'تمت الطباعة التلقائية لهذه الوثيقة مسبقاً ولا يجوز تكرارها آلياً.',
        );
      }
    }

    // 3. التحقق من متطلبات إعادة الطباعة اليدوية (Manual Reprint)
    if (command.triggerType == PrintTriggerType.manualReprint) {
      if (command.reprintReason == null || command.reprintReason!.trim().isEmpty) {
        throw const InvalidReprintReasonFailure(
          'إعادة الطباعة اليدوية تتطلب تحديد سبب واضح ومبرر للتدقيق.',
        );
      }

      onEvent?.call(ReprintRequestedEvent(
        businessId: command.businessId,
        branchId: command.branchId,
        timestamp: DateTime.now(),
        jobId: 'REPRINT-${command.idempotencyKey}',
        documentId: command.document.documentId,
        requestedBy: command.requestedBy,
        reason: command.reprintReason!,
        copies: command.copies,
      ));

      onAudit?.call(PrintingAuditRecord(
        action: 'REPRINT_REQUESTED',
        businessId: command.businessId,
        branchId: command.branchId,
        actor: command.requestedBy,
        documentId: command.document.documentId,
        reason: command.reprintReason,
        timestamp: DateTime.now(),
        safeMetadata: {
          'copies': command.copies,
        },
      ));
    }

    // 4. استرجاع وتطبيق ملف تعريف الطباعة للفرع (PrinterProfile)
    final profile = await _profileRepository.getProfileForDocument(
      businessId: command.businessId,
      branchId: command.branchId,
      documentType: command.document.documentType,
    );

    // إذا كانت الطباعة تلقائية، نتحقق من سياسة التلقائية المعتمدة
    if (command.triggerType == PrintTriggerType.autoPrint) {
      final policy = profile?.autoPrintPolicy ?? command.document.metadata['autoPrintPolicy'];
      if (policy is AutoPrintPolicy) {
        final shouldPrint = AutoPrintEvaluator.shouldAutoPrint(
          policy: policy,
          documentType: command.document.documentType,
        );
        if (!shouldPrint) {
          throw const AutoPrintSuppressedFailure(
            'تم حجب الطباعة التلقائية وفقاً لسياسة المتجر أو الفرع المعتمدة',
          );
        }
      }
    }

    // 5. تحديد الطابعة والتحقق من العزل (Branch Isolation)
    final targetPrinterId = command.printerIdOverride ??
        profile?.printerId;

    Printer? printer;
    if (targetPrinterId != null) {
      printer = await _printerRepository.getPrinterById(
        businessId: command.businessId,
        printerId: targetPrinterId,
      );
    }

    // المحاولة مع الطابعة الافتراضية للفرع
    printer ??= await _printerRepository.getDefaultPrinter(
      businessId: command.businessId,
      branchId: command.branchId,
    );

    if (printer == null) {
      throw const NoAvailablePrinterFailure('لا توجد طابعة مهيأة للفرع المحدد');
    }

    // التحقق الصارم من العزل المتعدد للمتاجر والفروع (Multi-Tenant Isolation)
    if (printer.businessId != command.businessId || printer.branchId != command.branchId) {
      throw const CrossBranchPrinterAccessFailure(
        'ممنوع أمنياً: محاولة استخدام طابعة تتبع فرعاً أو متجراً آخر.',
      );
    }

    // 6. تحديد خصائص الورق والـ Renderer
    final paperProfile = profile?.paperProfile ??
        command.document.preferredPaperProfile ??
        printer.paperProfile;

    final renderer = RendererFactory.getRenderer(paperProfile.type);

    // 7. تحويل الوثيقة إلى حمولة بيانات (Render Payload)
    final renderedPayload = renderer.render(
      document: command.document,
      profile: paperProfile,
      capabilities: printer.capabilities,
    );

    // 8. إنشاء مهمة الطباعة
    final jobId = 'JOB-${DateTime.now().millisecondsSinceEpoch}-${++_jobCounter}-${command.document.documentId}';
    final effectiveCopies = command.copies > 0
        ? command.copies
        : (profile?.copies ?? 1);

    final job = PrintJob(
      id: jobId,
      businessId: command.businessId,
      branchId: command.branchId,
      printerId: printer.id,
      documentId: command.document.documentId,
      documentType: command.document.documentType.name,
      paperProfile: paperProfile.type.name,
      triggerType: command.triggerType,
      copies: effectiveCopies,
      idempotencyKey: command.idempotencyKey,
      createdAt: DateTime.now(),
      metadata: {
        'requestedBy': command.requestedBy,
        if (command.reprintReason != null) 'reprintReason': command.reprintReason,
      },
    );

    // 9. تسجيل مفاتيح عدم التكرار قبل إرسال المهمة للطابور
    await _idempotencyStore.recordKey(
      businessId: command.businessId,
      idempotencyKey: command.idempotencyKey,
      jobId: jobId,
    );

    if (command.triggerType == PrintTriggerType.autoPrint) {
      await _idempotencyStore.recordAutoPrint(
        businessId: command.businessId,
        documentId: command.document.documentId,
        jobId: jobId,
      );
    }

    // 10. استدعاء السائق وإدراج المهمة في طابور المعالجة
    final driver = await _driverResolver(printer);

    return await _queueService.enqueueJob(
      job: job,
      payload: renderedPayload,
      driver: driver,
    );
  }

  /// تنفيذ إعادة الطباعة اليدوية الصريحة
  Future<PrintJob> reprintDocument(ReprintCommand command) async {
    return await submitPrintJob(SubmitPrintJobCommand(
      businessId: command.businessId,
      branchId: command.branchId,
      document: command.document,
      triggerType: PrintTriggerType.manualReprint,
      printerIdOverride: command.printerIdOverride,
      copies: command.copies,
      requestedBy: command.requestedBy,
      reprintReason: command.reason,
      idempotencyKey: command.idempotencyKey,
    ));
  }
}
