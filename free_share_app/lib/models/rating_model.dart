import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String id;
  final String raterId;  // 評價者
  final String ratedUserId;  // 被評價者
  final String transactionId;
  final int rating;  // 1-5 星
  final String? comment;
  final DateTime createdAt;
  final String itemId;  // 相關物品ID
  
  RatingModel({
    required this.id,
    required this.raterId,
    required this.ratedUserId,
    required this.transactionId,
    required this.rating,
    this.comment,
    required this.createdAt,
    required this.itemId,
  });

  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return RatingModel(
      id: doc.id,
      raterId: data['raterId'] ?? '',
      ratedUserId: data['ratedUserId'] ?? '',
      transactionId: data['transactionId'] ?? '',
      rating: data['rating'] ?? 5,
      comment: data['comment'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      itemId: data['itemId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'raterId': raterId,
      'ratedUserId': ratedUserId,
      'transactionId': transactionId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'itemId': itemId,
    };
  }

  bool get isPositive => rating >= 4;
  bool get isNeutral => rating == 3;
  bool get isNegative => rating <= 2;

  String get ratingDescription {
    switch (rating) {
      case 5:
        return '非常滿意';
      case 4:
        return '滿意';
      case 3:
        return '普通';
      case 2:
        return '不滿意';
      case 1:
        return '非常不滿意';
      default:
        return '未評分';
    }
  }
}

// 用戶評價統計類
class UserRatingStats {
  final double averageRating;
  final int totalRatings;
  final int fiveStarCount;
  final int fourStarCount;
  final int threeStarCount;
  final int twoStarCount;
  final int oneStarCount;
  final List<RatingModel> recentRatings;

  UserRatingStats({
    required this.averageRating,
    required this.totalRatings,
    required this.fiveStarCount,
    required this.fourStarCount,
    required this.threeStarCount,
    required this.twoStarCount,
    required this.oneStarCount,
    required this.recentRatings,
  });

  int get positiveCount => fiveStarCount + fourStarCount;
  int get neutralCount => threeStarCount;
  int get negativeCount => twoStarCount + oneStarCount;

  double get positivePercentage => 
      totalRatings > 0 ? (positiveCount / totalRatings) * 100 : 0;
  
  double get negativePercentage => 
      totalRatings > 0 ? (negativeCount / totalRatings) * 100 : 0;

  factory UserRatingStats.fromRatings(List<RatingModel> ratings) {
    if (ratings.isEmpty) {
      return UserRatingStats(
        averageRating: 0.0,
        totalRatings: 0,
        fiveStarCount: 0,
        fourStarCount: 0,
        threeStarCount: 0,
        twoStarCount: 0,
        oneStarCount: 0,
        recentRatings: [],
      );
    }

    final total = ratings.length;
    final sum = ratings.fold<int>(0, (sum, rating) => sum + rating.rating);
    
    final fiveStar = ratings.where((r) => r.rating == 5).length;
    final fourStar = ratings.where((r) => r.rating == 4).length;
    final threeStar = ratings.where((r) => r.rating == 3).length;
    final twoStar = ratings.where((r) => r.rating == 2).length;
    final oneStar = ratings.where((r) => r.rating == 1).length;

    // 按時間排序，取最近的5個評價
    final sortedRatings = List<RatingModel>.from(ratings)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recent = sortedRatings.take(5).toList();

    return UserRatingStats(
      averageRating: sum / total,
      totalRatings: total,
      fiveStarCount: fiveStar,
      fourStarCount: fourStar,
      threeStarCount: threeStar,
      twoStarCount: twoStar,
      oneStarCount: oneStar,
      recentRatings: recent,
    );
  }
}
