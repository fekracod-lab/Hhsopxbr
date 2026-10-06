// محول أخطاء واستثناءات نقطة البيع إلى رسائل عربية ودية (MADAR SHOP POS Error Mapper)
// Presentation Layer — Clean User Guidance without Leaking Tech Details

import '../../../application/pos/failures/pos_failures.dart';
import '../../../domain/sync/failures/sync_failures.dart';

class PosErrorMapper {
  const PosErrorMapper._();

  static String toArabicMessage(Object error) {
    if (error is InvalidQuantityFailure) {
      return error.message;
    }
    if (error is ProductUnavailableFailure) {
      return error.message;
    }
    if (error is InvalidCartFailure) {
      return 'سلة المشتريات فارغة؛ يرجى إضافة منتجات قبل إتمام البيع.';
    }
    if (error is CreditCustomerRequiredFailure) {
      return 'البيع الآجل يتطلب تحديد حساب العميل أولاً.';
    }
    if (error is InvalidPaymentFailure) {
      return 'بيانات ومبالغ الدفع غير متسقة مع إجمالي الفاتورة.';
    }
    if (error is SessionExpiredFailure) {
      return 'جلسة العمل منتهية أو خاملة؛ يرجى تسجيل الدخول مجدداً.';
    }
    if (error is UnauthorizedCashierFailure) {
      return error.message.isNotEmpty ? error.message : 'ليس لديك صلاحية لتنفيذ هذا الإجراء.';
    }
    if (error is UnauthorizedTerminalFailure) {
      return 'هذه المحطة غير مصرح لها بالعمل على هذا الفرع.';
    }
    if (error is BranchMismatchFailure) {
      return 'الفرع المحدد لا يتطابق مع فرع الجلسة النشطة.';
    }
    if (error is TransactionConflictFailure) {
      return 'تعذر إتمام المعاملة؛ حدث تعارض مع حالة سابقة.';
    }
    if (error is SyncInsufficientStockFailure) {
      return 'الكمية المطلوبة غير متوفرة في المخزون المحلي (${error.availableQuantity} متاح).';
    }
    if (error is SyncOfflineBlockedFailure) {
      return 'هذه العملية تتطلب اتصالاً بالإنترنت وفق سياسة المتجر.';
    }
    if (error is SyncConflictFailure) {
      return 'حدث تعارض في المزامنة؛ تمت حماية العملية وستتم مراجعتها من قبل الإدارة.';
    }
    if (error is SyncAuthBlockedFailure) {
      return 'انتهت صلاحية مفاتيح المصادقة؛ يرجى إعادة تسجيل الدخول.';
    }
    if (error is SyncTenantViolationFailure) {
      return 'تم رفض العملية بسبب عدم تطابق بيانات المتجر أو الفرع.';
    }
    if (error is ArgumentError) {
      return error.message.toString();
    }

    // رسالة الخطأ العامة
    final str = error.toString();
    if (str.contains('InsufficientStock') || str.contains('out of stock')) {
      return 'الكمية المطلوبة غير متوفرة بالمخزون.';
    }
    if (str.contains('Printer') || str.contains('printer')) {
      return 'الطابعة غير متصلة؛ تم حفظ الفاتورة بنجاح ويمكن إعادة طباعتها.';
    }
    if (str.contains('Credit') || str.contains('credit')) {
      return 'البيع الآجل غير مسموح بدون تحديد العميل وفحص السقف الائتماني.';
    }

    return 'تعذر إتمام العملية. يرجى المحاولة مرة أخرى أو مراجعة المشرف.';
  }
}
