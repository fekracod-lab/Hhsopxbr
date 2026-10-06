// خدمة طابور مهام الطباعة والتحكم بالحالات (MADAR SHOP Print Queue Service)
// Pure Dart — Zero UI Dependencies

import 'dart:async';

import '../../../domain/printing/contracts/i_print_job_repository.dart';
import '../../../domain/printing/contracts/i_printer_driver.dart';
import '../../../domain/printing/entities/print_job.dart';
import '../../../domain/printing/enums/print_job_status.dart';
import '../../../domain/printing/failures/printing_failures.dart';
import '../../../domain/printing/rules/print_state_machine.dart';
import '../../../domain/printing/value_objects/rendered_payload.dart';
import '../events/printing_events.dart';

typedef PrintingEventListener = void Function(PrintingEvent event);
typedef PrintingAuditListener = void Function(PrintingAuditRecord record);

class PrintQueueService {
  final IPrintJobRepository _jobRepository;
  final int maxRetries;
  final Duration baseRetryDelay;
  final PrintingEventListener? onEvent;
  final PrintingAuditListener? onAudit;

  PrintQueueService({
    required IPrintJobRepository jobRepository,
    this.maxRetries = 3,
    this.baseRetryDelay = const Duration(milliseconds: 50),
    this.onEvent,
    this.onAudit,
  }) : _jobRepository = jobRepository;

  /// إدراج مهمة جديدة في الطابور والبدء المباشر بمعالجتها
  Future<PrintJob> enqueueJob({
    required PrintJob job,
    required RenderedPayload payload,
    required IPrinterDriver driver,
  }) async {
    // التحقق من صحة الحالة الأولية
    final initialTransition = PrintStateMachine.validateTransition(
      currentStatus: PrintJobStatus.queued,
      nextStatus: PrintJobStatus.queued,
    );
    if (!initialTransition.isAllowed) {
      throw InvalidPrintStateTransitionFailure(initialTransition.rejectionReason!);
    }

    await _jobRepository.saveJob(job);

    onEvent?.call(PrintQueuedEvent(
      businessId: job.businessId,
      branchId: job.branchId,
      timestamp: DateTime.now(),
      jobId: job.id,
      documentId: job.documentId,
      documentType: job.documentType.name,
      printerId: job.printerId,
      triggerType: job.triggerType.name,
      copies: job.copies,
    ));

    onAudit?.call(PrintingAuditRecord(
      action: 'PRINT_REQUESTED',
      businessId: job.businessId,
      branchId: job.branchId,
      actor: job.triggerType.name,
      documentId: job.documentId,
      printerId: job.printerId,
      jobId: job.id,
      timestamp: DateTime.now(),
      safeMetadata: {
        'copies': job.copies,
        'triggerType': job.triggerType.name,
      },
    ));

    // معالجة المهمة
    return await _processJob(
      job: job,
      payload: payload,
      driver: driver,
    );
  }

  Future<PrintJob> _processJob({
    required PrintJob job,
    required RenderedPayload payload,
    required IPrinterDriver driver,
  }) async {
    final printingTransition = PrintStateMachine.validateTransition(
      currentStatus: job.status,
      nextStatus: PrintJobStatus.printing,
    );
    if (!printingTransition.isAllowed) {
      throw InvalidPrintStateTransitionFailure(printingTransition.rejectionReason!);
    }

    final startTime = DateTime.now();
    var currentJob = job.transitionTo(
      PrintJobStatus.printing,
      startedAt: startTime,
      attemptCount: job.attemptCount + 1,
    );
    await _jobRepository.saveJob(currentJob);

    onEvent?.call(PrintStartedEvent(
      businessId: currentJob.businessId,
      branchId: currentJob.branchId,
      timestamp: startTime,
      jobId: currentJob.id,
      documentId: currentJob.documentId,
      printerId: currentJob.printerId,
      attemptNumber: currentJob.attemptCount,
    ));

    try {
      // 1. الاتصال بالطابعة
      final connected = await driver.connect();
      if (!connected) {
        throw const PrinterOfflineFailure('تعذر الاتصال بالطابعة');
      }

      // 2. إرسال النسخ
      for (int c = 0; c < currentJob.copies; c++) {
        await driver.printPayload(currentJob, payload);
      }

      // 3. نجاح الطباعة
      final completedTime = DateTime.now();
      final completedTransition = PrintStateMachine.validateTransition(
        currentStatus: currentJob.status,
        nextStatus: PrintJobStatus.completed,
      );
      if (!completedTransition.isAllowed) {
        throw InvalidPrintStateTransitionFailure(completedTransition.rejectionReason!);
      }

      final completedJob = currentJob.transitionTo(
        PrintJobStatus.completed,
        completedAt: completedTime,
      );
      await _jobRepository.saveJob(completedJob);

      onEvent?.call(PrintCompletedEvent(
        businessId: completedJob.businessId,
        branchId: completedJob.branchId,
        timestamp: completedTime,
        jobId: completedJob.id,
        documentId: completedJob.documentId,
        printerId: completedJob.printerId,
        duration: completedTime.difference(startTime),
      ));

      onAudit?.call(PrintingAuditRecord(
        action: 'PRINT_COMPLETED',
        businessId: completedJob.businessId,
        branchId: completedJob.branchId,
        actor: 'PRINT_ENGINE',
        documentId: completedJob.documentId,
        printerId: completedJob.printerId,
        jobId: completedJob.id,
        timestamp: completedTime,
      ));

      return completedJob;
    } on PrintAckTimeoutFailure catch (e) {
      // حالة حرجة: انقطاع تأكيد الطباعة بعد إرسال البيانات
      // لا نعيد المحاولة آلياً مطلقاً لتفادي مضاعفة طباعة الفواتير
      final unknownJob = currentJob.transitionTo(
        PrintJobStatus.unknownRequiresConfirmation,
        error: e.message,
      );
      await _jobRepository.saveJob(unknownJob);

      onEvent?.call(UnknownPrintStateEvent(
        businessId: unknownJob.businessId,
        branchId: unknownJob.branchId,
        timestamp: DateTime.now(),
        jobId: unknownJob.id,
        documentId: unknownJob.documentId,
        printerId: unknownJob.printerId,
        reason: e.message,
      ));

      onAudit?.call(PrintingAuditRecord(
        action: 'UNKNOWN_PRINT_STATE',
        businessId: unknownJob.businessId,
        branchId: unknownJob.branchId,
        actor: 'HARDWARE_TRANSPORT',
        documentId: unknownJob.documentId,
        printerId: unknownJob.printerId,
        jobId: unknownJob.id,
        reason: e.message,
        timestamp: DateTime.now(),
      ));

      return unknownJob;
    } catch (e) {
      final errorMsg = e.toString();

      // فحص سياسة إعادة المحاولة المقيدة (Bounded Retry)
      if (currentJob.attemptCount < maxRetries) {
        final requeuedJob = currentJob.transitionTo(
          PrintJobStatus.queued,
          error: errorMsg,
        );
        await _jobRepository.saveJob(requeuedJob);

        // انتظار تصاعدي قبل المحاولة القادمة (Backoff)
        final delayMs = baseRetryDelay.inMilliseconds * currentJob.attemptCount;
        if (delayMs > 0) {
          await Future.delayed(Duration(milliseconds: delayMs));
        }

        // محاولة إعادة الطباعة
        return await _processJob(
          job: requeuedJob,
          payload: payload,
          driver: driver,
        );
      } else {
        // استنفاد كافة المحاولات المقيدة
        final failedJob = currentJob.transitionTo(
          PrintJobStatus.failed,
          error: 'فشلت الطباعة بعد ${currentJob.attemptCount} محاولات: $errorMsg',
        );
        await _jobRepository.saveJob(failedJob);

        onEvent?.call(PrintFailedEvent(
          businessId: failedJob.businessId,
          branchId: failedJob.branchId,
          timestamp: DateTime.now(),
          jobId: failedJob.id,
          documentId: failedJob.documentId,
          printerId: failedJob.printerId,
          errorMessage: errorMsg,
          attemptsMade: failedJob.attemptCount,
        ));

        onAudit?.call(PrintingAuditRecord(
          action: 'PRINT_FAILED',
          businessId: failedJob.businessId,
          branchId: failedJob.branchId,
          actor: 'PRINT_ENGINE',
          documentId: failedJob.documentId,
          printerId: failedJob.printerId,
          jobId: failedJob.id,
          reason: errorMsg,
          timestamp: DateTime.now(),
        ));

        return failedJob;
      }
    }
  }

  /// تأكيد المستخدم لحالة الطباعة المعلقة وغير المؤكدة (Manual Confirmation)
  Future<PrintJob> confirmUnknownState({
    required String businessId,
    required String jobId,
    required bool actuallyPrinted,
    required String actor,
    required String reason,
  }) async {
    final existing = await _jobRepository.getJobById(
      businessId: businessId,
      jobId: jobId,
    );

    if (existing == null) {
      throw const PrintJobNotFoundFailure('مهمة الطباعة غير موجودة');
    }

    final targetStatus = actuallyPrinted ? PrintJobStatus.completed : PrintJobStatus.failed;
    final transition = PrintStateMachine.validateTransition(
      currentStatus: existing.status,
      nextStatus: targetStatus,
    );
    if (!transition.isAllowed) {
      throw InvalidPrintStateTransitionFailure(transition.rejectionReason!);
    }

    final updated = existing.transitionTo(
      targetStatus,
      completedAt: actuallyPrinted ? DateTime.now() : null,
      error: actuallyPrinted ? null : 'تم تأكيد عدم خروج المطبوع يدوياً: $reason',
    );
    await _jobRepository.saveJob(updated);

    onAudit?.call(PrintingAuditRecord(
      action: actuallyPrinted ? 'PRINT_CONFIRMED_COMPLETED' : 'PRINT_CONFIRMED_FAILED',
      businessId: businessId,
      branchId: updated.branchId,
      actor: actor,
      documentId: updated.documentId,
      printerId: updated.printerId,
      jobId: updated.id,
      reason: reason,
      timestamp: DateTime.now(),
    ));

    return updated;
  }

  /// إلغاء مهمة قيد الانتظار
  Future<PrintJob> cancelJob({
    required String businessId,
    required String jobId,
    required String cancelledBy,
    required String reason,
  }) async {
    final existing = await _jobRepository.getJobById(
      businessId: businessId,
      jobId: jobId,
    );

    if (existing == null) {
      throw const PrintJobNotFoundFailure('مهمة الطباعة غير موجودة');
    }

    final transition = PrintStateMachine.validateTransition(
      currentStatus: existing.status,
      nextStatus: PrintJobStatus.cancelled,
    );
    if (!transition.isAllowed) {
      throw InvalidPrintStateTransitionFailure(transition.rejectionReason!);
    }

    final updated = existing.transitionTo(
      PrintJobStatus.cancelled,
      error: 'ألغيت بواسطة $cancelledBy: $reason',
    );
    await _jobRepository.saveJob(updated);

    onAudit?.call(PrintingAuditRecord(
      action: 'PRINT_CANCELLED',
      businessId: businessId,
      branchId: updated.branchId,
      actor: cancelledBy,
      documentId: updated.documentId,
      printerId: updated.printerId,
      jobId: updated.id,
      reason: reason,
      timestamp: DateTime.now(),
    ));

    return updated;
  }
}
