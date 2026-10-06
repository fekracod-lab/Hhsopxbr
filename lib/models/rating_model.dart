import 'package:cloud_firestore/cloud_firestore.dart';

enum RatingTargetType {
  captain,
  customer,
  restaurant,
  store,
}

class RatingModel {
  final String id;
  final String targetId;
  final RatingTargetType targetType;
  final String targetName;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String referenceId; // rideId or orderId
  final double rating; // 1.0 to 5.0
  final List<String> tags;
  final String comment;
  final DateTime createdAt;
  final String? reply;
  final DateTime? repliedAt;

  const RatingModel({
    required this.id,
    required this.targetId,
    required this.targetType,
    required this.targetName,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.referenceId,
    required this.rating,
    this.tags = const [],
    this.comment = '',
    required this.createdAt,
    this.reply,
    this.repliedAt,
  });

  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RatingModel.fromMap(data, doc.id);
  }

  factory RatingModel.fromMap(Map<String, dynamic> data, String id) {
    final rawType = data['targetType']?.toString() ?? 'captain';
    RatingTargetType type;
    switch (rawType) {
      case 'customer':
        type = RatingTargetType.customer;
        break;
      case 'restaurant':
        type = RatingTargetType.restaurant;
        break;
      case 'store':
        type = RatingTargetType.store;
        break;
      case 'captain':
      default:
        type = RatingTargetType.captain;
        break;
    }

    DateTime created = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      created = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
    }

    DateTime? replied;
    if (data['repliedAt'] is Timestamp) {
      replied = (data['repliedAt'] as Timestamp).toDate();
    }

    return RatingModel(
      id: id,
      targetId: data['targetId']?.toString() ?? '',
      targetType: type,
      targetName: data['targetName']?.toString() ?? '',
      authorId: data['authorId']?.toString() ?? '',
      authorName: data['authorName']?.toString() ?? 'زبون مدار',
      authorRole: data['authorRole']?.toString() ?? 'customer',
      referenceId: data['referenceId']?.toString() ?? '',
      rating: (data['rating'] is num) ? (data['rating'] as num).toDouble() : 5.0,
      tags: List<String>.from(data['tags'] ?? []),
      comment: data['comment']?.toString() ?? '',
      createdAt: created,
      reply: data['reply']?.toString(),
      repliedAt: replied,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetId': targetId,
      'targetType': targetType.name,
      'targetName': targetName,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'referenceId': referenceId,
      'rating': rating,
      'tags': tags,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
      'reply': reply,
      'repliedAt': repliedAt != null ? Timestamp.fromDate(repliedAt!) : null,
    };
  }
}
