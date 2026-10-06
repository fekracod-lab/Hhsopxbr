/// سجل كلمة المرور السابقة للمالك (Password History Item)
class PasswordHistoryRecord {
  final String password;
  final DateTime changedAt;

  const PasswordHistoryRecord({
    required this.password,
    required this.changedAt,
  });

  factory PasswordHistoryRecord.fromMap(Map<String, dynamic> map) {
    DateTime date = DateTime.now();
    final rawDate = map['changedAt'];
    if (rawDate is String) {
      date = DateTime.tryParse(rawDate) ?? DateTime.now();
    }
    return PasswordHistoryRecord(
      password: map['password']?.toString() ?? '',
      changedAt: date,
    );
  }
}

/// سجل حساب مالك المطعم (Restaurant Owner Record)
class RestaurantOwnerRecord {
  final String id;
  final List<PasswordHistoryRecord> passwordHistory;
  final DateTime? passwordChangedAt;

  const RestaurantOwnerRecord({
    required this.id,
    this.passwordHistory = const [],
    this.passwordChangedAt,
  });
}

/// سجل بيانات المطعم المجرد (Immutable Restaurant Record Entity)
class RestaurantRecord {
  final String id;
  final String path;
  final String name;
  final String ownerId;
  final String imageUrl;
  final String status;
  final bool isSuspended;
  final double rating;
  final Map<String, dynamic> rawData;

  const RestaurantRecord({
    required this.id,
    required this.path,
    required this.name,
    required this.ownerId,
    required this.imageUrl,
    this.status = '',
    this.isSuspended = false,
    this.rating = 0.0,
    this.rawData = const {},
  });

  RestaurantRecord copyWith({
    String? id,
    String? path,
    String? name,
    String? ownerId,
    String? imageUrl,
    String? status,
    bool? isSuspended,
    double? rating,
    Map<String, dynamic>? rawData,
  }) {
    return RestaurantRecord(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      isSuspended: isSuspended ?? this.isSuspended,
      rating: rating ?? this.rating,
      rawData: rawData ?? this.rawData,
    );
  }
}
