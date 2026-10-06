// كيانات طبقة النطاق للوحة تحكم المتجر والتاجر (Store Dashboard Domain Entities)
// Pure Dart — Zero Flutter / Firebase Dependencies

/// حالات طلبات المتجر (Store Order Status Enum)
enum StoreOrderStatus {
  pending,
  accepted,
  ready,
  delivering,
  pickedUp,
  completed,
  cancelled,
  unknown;

  static StoreOrderStatus fromString(String? status) {
    if (status == null) return StoreOrderStatus.unknown;
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return StoreOrderStatus.pending;
      case 'accepted':
        return StoreOrderStatus.accepted;
      case 'ready':
        return StoreOrderStatus.ready;
      case 'delivering':
        return StoreOrderStatus.delivering;
      case 'picked_up':
      case 'pickedup':
        return StoreOrderStatus.pickedUp;
      case 'completed':
        return StoreOrderStatus.completed;
      case 'cancelled':
      case 'canceled':
        return StoreOrderStatus.cancelled;
      default:
        return StoreOrderStatus.unknown;
    }
  }

  String toDbString() {
    switch (this) {
      case StoreOrderStatus.pending:
        return 'pending';
      case StoreOrderStatus.accepted:
        return 'accepted';
      case StoreOrderStatus.ready:
        return 'ready';
      case StoreOrderStatus.delivering:
        return 'delivering';
      case StoreOrderStatus.pickedUp:
        return 'picked_up';
      case StoreOrderStatus.completed:
        return 'completed';
      case StoreOrderStatus.cancelled:
        return 'cancelled';
      case StoreOrderStatus.unknown:
        return 'unknown';
    }
  }

  bool get isTerminal =>
      this == StoreOrderStatus.completed || this == StoreOrderStatus.cancelled;

  bool get isActive =>
      this == StoreOrderStatus.pending ||
      this == StoreOrderStatus.accepted ||
      this == StoreOrderStatus.ready ||
      this == StoreOrderStatus.delivering ||
      this == StoreOrderStatus.pickedUp;
}

/// بيانات المتجر الأساسية (Store Dashboard Entity)
class StoreDashboardEntity {
  final String storeId;
  final String name;
  final String logoUrl;
  final String coverUrl;
  final double? latitude;
  final double? longitude;
  final String address;
  final String ownerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> rawData;

  const StoreDashboardEntity({
    required this.storeId,
    required this.name,
    this.logoUrl = '',
    this.coverUrl = '',
    this.latitude,
    this.longitude,
    this.address = '',
    this.ownerId = '',
    this.createdAt,
    this.updatedAt,
    this.rawData = const {},
  });

  StoreDashboardEntity copyWith({
    String? storeId,
    String? name,
    String? logoUrl,
    String? coverUrl,
    double? latitude,
    double? longitude,
    String? address,
    String? ownerId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? rawData,
  }) {
    return StoreDashboardEntity(
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rawData: rawData ?? this.rawData,
    );
  }
}

/// عنصر داخل طلب المتجر (Store Order Item Entity)
class StoreOrderItemEntity {
  final String itemId;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final String size;
  final String options;
  final String notes;

  const StoreOrderItemEntity({
    required this.itemId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.imageUrl = '',
    this.size = '',
    this.options = '',
    this.notes = '',
  });

  double get totalPrice => (price < 0 ? 0.0 : price) * (quantity < 0 ? 0 : quantity);
}

/// طلب المتجر (Store Order Entity)
class StoreOrderEntity {
  final String orderId;
  final String status;
  final StoreOrderStatus orderStatus;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String address;
  final double total;
  final List<StoreOrderItemEntity> items;
  final int pointsEarned;
  final int pointsUsed;
  final String paymentStatus;
  final bool readByStore;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> rawData;

  const StoreOrderEntity({
    required this.orderId,
    required this.status,
    required this.orderStatus,
    this.customerId = '',
    this.customerName = '',
    this.customerPhone = '',
    this.address = '',
    required this.total,
    this.items = const [],
    this.pointsEarned = 0,
    this.pointsUsed = 0,
    this.paymentStatus = '',
    this.readByStore = false,
    this.createdAt,
    this.updatedAt,
    this.rawData = const {},
  });

  bool get isPaidWithWallet => paymentStatus == 'paid_wallet';
  bool get isCompleted => orderStatus == StoreOrderStatus.completed;
  bool get isCancelled => orderStatus == StoreOrderStatus.cancelled;
  bool get isPending => orderStatus == StoreOrderStatus.pending;
}

/// منتج المتجر (Store Product Entity)
class StoreProductEntity {
  final String productId;
  final String name;
  final double price;
  final String description;
  final String category;
  final String imageUrl;
  final bool isAvailable;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> rawData;

  const StoreProductEntity({
    required this.productId,
    required this.name,
    required this.price,
    this.description = '',
    this.category = 'عام',
    this.imageUrl = '',
    this.isAvailable = true,
    this.createdAt,
    this.updatedAt,
    this.rawData = const {},
  });

  StoreProductEntity copyWith({
    String? productId,
    String? name,
    double? price,
    String? description,
    String? category,
    String? imageUrl,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? rawData,
  }) {
    return StoreProductEntity(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rawData: rawData ?? this.rawData,
    );
  }
}

/// فئة / تصنيف منتجات المتجر (Store Category Entity)
class StoreCategoryEntity {
  final String categoryId;
  final String name;
  final int iconCode;
  final int colorValue;
  final DateTime? createdAt;

  const StoreCategoryEntity({
    required this.categoryId,
    required this.name,
    this.iconCode = 0xe148, // Icons.category_rounded default codePoint
    this.colorValue = 0xFFF5F5F5,
    this.createdAt,
  });
}

/// إعلان ترويجي للمتجر (Store Banner Entity)
class StoreBannerEntity {
  final String bannerId;
  final String title;
  final String subtitle;
  final String imageUrl;
  final DateTime? createdAt;

  const StoreBannerEntity({
    required this.bannerId,
    required this.title,
    this.subtitle = '',
    required this.imageUrl,
    this.createdAt,
  });
}

/// إحصائيات لوحة تحكم المتجر (Store Order Statistics Entity)
class StoreOrderStatisticsEntity {
  final int totalOrders;
  final int pendingOrders;
  final int acceptedOrders;
  final int readyOrders;
  final int deliveringOrders;
  final int pickedUpOrders;
  final int completedOrders;
  final int cancelledOrders;
  final double totalRevenue;
  final double todayRevenue;

  const StoreOrderStatisticsEntity({
    this.totalOrders = 0,
    this.pendingOrders = 0,
    this.acceptedOrders = 0,
    this.readyOrders = 0,
    this.deliveringOrders = 0,
    this.pickedUpOrders = 0,
    this.completedOrders = 0,
    this.cancelledOrders = 0,
    this.totalRevenue = 0.0,
    this.todayRevenue = 0.0,
  });

  static const empty = StoreOrderStatisticsEntity();
}

/// الأثر المالي لنقاط مدار والمحفظة عند تغيير حالة الطلب (Store Order Financial Effect)
class StoreOrderFinancialEffect {
  final String customerId;
  final int pointsDelta;
  final double walletBalanceDelta;
  final bool isPointsAwarded;
  final bool isPointsRefunded;
  final bool isWalletRefunded;

  const StoreOrderFinancialEffect({
    required this.customerId,
    this.pointsDelta = 0,
    this.walletBalanceDelta = 0.0,
    this.isPointsAwarded = false,
    this.isPointsRefunded = false,
    this.isWalletRefunded = false,
  });

  static const none = StoreOrderFinancialEffect(customerId: '');
}
