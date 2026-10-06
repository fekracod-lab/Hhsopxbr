import 'package:intl/intl.dart';

/// ثوابت نظام الكاشير ومطاعم مدار
class PosConstants {
  static const String currency = 'د.ع';

  // أنواع الطلبات
  static const String orderTypeDineIn = 'dine_in';
  static const String orderTypeTakeaway = 'takeaway';
  static const String orderTypeDelivery = 'delivery';

  // طرق الدفع
  static const String paymentCash = 'cash';
  static const String paymentCard = 'card';
  static const String paymentZainCash = 'zain_cash';
  static const String paymentDebit = 'debit';

  // حالات الطلب
  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusPreparing = 'preparing';
  static const String statusReady = 'ready';
  static const String statusDelivering = 'delivering';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  // تنسيق المبالغ المالية
  static String formatMoney(dynamic amount) {
    if (amount == null) return '0 $currency';
    double val = 0;
    if (amount is num) {
      val = amount.toDouble();
    } else {
      val = double.tryParse(amount.toString()) ?? 0;
    }
    final formatter = NumberFormat('#,###', 'en_US');
    return '${formatter.format(val)} $currency';
  }

  // تسميات أنواع الطلب
  static String getOrderTypeName(String type) {
    switch (type) {
      case orderTypeDineIn:
        return 'محلي (صالة)';
      case orderTypeTakeaway:
        return 'سفري (استلام)';
      case orderTypeDelivery:
        return 'توصيل خارجي';
      default:
        return 'طلب مباشر';
    }
  }

  // تسميات طرق الدفع
  static String getPaymentMethodName(String method) {
    switch (method) {
      case paymentCash:
        return 'نقداً (كاش)';
      case paymentCard:
        return 'بطاقة / شبكة';
      case paymentZainCash:
        return 'زين كاش';
      case paymentDebit:
        return 'آجل (ذمة)';
      default:
        return 'نقداً';
    }
  }
}
