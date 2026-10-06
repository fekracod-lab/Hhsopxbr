/// نوع ومصدر طلب المتجر
enum StoreRequestSource {
  storeRequests,
  users,
  unknown;

  static StoreRequestSource fromString(String? source) {
    switch (source) {
      case 'store_requests':
        return StoreRequestSource.storeRequests;
      case 'users':
        return StoreRequestSource.users;
      default:
        return StoreRequestSource.unknown;
    }
  }
}

/// سجل المتجر وطلب الانضمام المجرد (Immutable Store Record Entity)
class StoreRecord {
  final String id;
  final String storeName;
  final String ownerName;
  final String phone;
  final String email;
  final String category;
  final String governorateName;
  final String regionName;
  final String address;
  final String workingHours;
  final bool isApproved;
  final String status;
  final String? logoUrl;
  final StoreRequestSource source;
  final Map<String, dynamic> rawData;

  const StoreRecord({
    required this.id,
    required this.storeName,
    required this.ownerName,
    required this.phone,
    this.email = 'غير محدد',
    this.category = 'عام',
    this.governorateName = 'غير محدد',
    this.regionName = '',
    this.address = 'غير محدد',
    this.workingHours = 'من 9:00 ص إلى 11:00 م',
    required this.isApproved,
    required this.status,
    this.logoUrl,
    this.source = StoreRequestSource.users,
    this.rawData = const {},
  });

  bool get isPending => !isApproved && status.toLowerCase() != 'rejected';
  bool get isActive => isApproved && status.toLowerCase() == 'active';
  bool get isRejected => status.toLowerCase() == 'rejected';
}

/// سجل طلب المتجر المالي (Store Order Entity)
class StoreOrderRecord {
  final String id;
  final String storeId;
  final double totalPrice;
  final String status;
  final DateTime? createdAt;
  final Map<String, dynamic> rawData;

  const StoreOrderRecord({
    required this.id,
    required this.storeId,
    required this.totalPrice,
    required this.status,
    this.createdAt,
    this.rawData = const {},
  });

  bool get isCompleted {
    final st = status.toLowerCase().trim();
    return st == 'completed' || st == 'delivered' || st == 'تم التسليم';
  }
}

/// إحصائيات المتجر الفردي (Single Store Analytics Summary)
class StoreSalesMetric {
  final StoreRecord store;
  final double totalSalesRevenue;
  final int completedOrdersCount;

  const StoreSalesMetric({
    required this.store,
    required this.totalSalesRevenue,
    required this.completedOrdersCount,
  });
}

/// ملخص الإحصائيات العامة للمتاجر والطلبات (Overall Store Analytics Metric Summary)
class OverallStoreAnalyticsSummary {
  final int pendingRequestsCount;
  final int totalRegisteredStoresCount;
  final double totalSalesRevenue;
  final int completedOrdersCount;

  const OverallStoreAnalyticsSummary({
    required this.pendingRequestsCount,
    required this.totalRegisteredStoresCount,
    required this.totalSalesRevenue,
    required this.completedOrdersCount,
  });

  factory OverallStoreAnalyticsSummary.empty() => const OverallStoreAnalyticsSummary(
        pendingRequestsCount: 0,
        totalRegisteredStoresCount: 0,
        totalSalesRevenue: 0.0,
        completedOrdersCount: 0,
      );
}
