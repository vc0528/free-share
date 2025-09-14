import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime lastActive;
  final RatingData rating;
  final TransactionStats transactionStats;
  final UserPreferences preferences;
  final LocationData? location;
  final bool isAdmin;
  final bool isBanned;
  
  // 新增：email驗證狀態
  final bool emailVerified;
  final DateTime? emailVerifiedAt;
  
  // 推播訂閱相關
  final List<String> subscribedKeywords;
  final List<String> notifiedItemIds;
  final NotificationSettings notificationSettings;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.avatarUrl,
    required this.createdAt,
    required this.lastActive,
    required this.rating,
    required this.transactionStats,
    required this.preferences,
    this.location,
    this.isAdmin = false,
    this.isBanned = false,
    // 新增屬性的預設值
    this.emailVerified = false,
    this.emailVerifiedAt,
    this.subscribedKeywords = const [],
    this.notifiedItemIds = const [],
    NotificationSettings? notificationSettings,
  }) : notificationSettings = notificationSettings ?? NotificationSettings();

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      avatarUrl: data['avatarUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastActive: (data['lastActive'] as Timestamp).toDate(),
      rating: RatingData.fromMap(data['rating'] ?? {}),
      transactionStats: TransactionStats.fromMap(data['transactionStats'] ?? {}),
      preferences: UserPreferences.fromMap(data['preferences'] ?? {}),
      location: data['location'] != null 
          ? LocationData.fromMap(data['location']) 
          : null,
      isAdmin: data['isAdmin'] ?? false,
      isBanned: data['isBanned'] ?? false,
      // 新增屬性的解析
      emailVerified: data['emailVerified'] ?? false,
      emailVerifiedAt: data['emailVerifiedAt'] != null 
          ? (data['emailVerifiedAt'] as Timestamp).toDate()
          : null,
      subscribedKeywords: List<String>.from(data['subscribedKeywords'] ?? []),
      notifiedItemIds: List<String>.from(data['notifiedItemIds'] ?? []),
      notificationSettings: NotificationSettings.fromMap(data['notificationSettings'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'username': username,
      'avatarUrl': avatarUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': Timestamp.fromDate(lastActive),
      'rating': rating.toMap(),
      'transactionStats': transactionStats.toMap(),
      'preferences': preferences.toMap(),
      'location': location?.toMap(),
      'isAdmin': isAdmin,
      'isBanned': isBanned,
      // 新增屬性的序列化
      'emailVerified': emailVerified,
      'emailVerifiedAt': emailVerifiedAt != null 
          ? Timestamp.fromDate(emailVerifiedAt!)
          : null,
      'subscribedKeywords': subscribedKeywords,
      'notifiedItemIds': notifiedItemIds,
      'notificationSettings': notificationSettings.toMap(),
    };
  }

  // 新增：檢查是否可以執行需要驗證的操作
  bool canPerformVerifiedActions() {
    return emailVerified && !isBanned;
  }

  // 新增：取得驗證狀態描述
  String getVerificationStatusMessage() {
    if (isBanned) return '帳戶已被停用';
    if (!emailVerified) return '請先驗證您的Email地址';
    return '帳戶已驗證';
  }

  // 關鍵字管理方法
  UserModel addKeyword(String keyword) {
    final newKeywords = List<String>.from(subscribedKeywords);
    final cleanKeyword = keyword.trim().toLowerCase();
    if (cleanKeyword.isNotEmpty && !newKeywords.contains(cleanKeyword)) {
      newKeywords.add(cleanKeyword);
    }
    return copyWith(subscribedKeywords: newKeywords);
  }

  UserModel removeKeyword(String keyword) {
    final newKeywords = List<String>.from(subscribedKeywords);
    newKeywords.remove(keyword.toLowerCase());
    return copyWith(subscribedKeywords: newKeywords);
  }

  UserModel updateKeywords(List<String> keywords) {
    final cleanKeywords = keywords
        .map((k) => k.trim().toLowerCase())
        .where((k) => k.isNotEmpty)
        .toSet()
        .toList();
    return copyWith(subscribedKeywords: cleanKeywords);
  }

  // 通知相關方法
  bool shouldReceiveNotification(String itemId, double itemLat, double itemLng) {
    if (!preferences.enableNotifications || !notificationSettings.enabled) {
      return false;
    }
    
    if (notifiedItemIds.contains(itemId)) {
      return false;
    }
    
    if (notificationSettings.isQuietHours()) {
      return false;
    }
    
    if (location != null) {
      double distance = _calculateDistance(
        location!.latitude,
        location!.longitude,
        itemLat,
        itemLng,
      );
      if (distance > notificationSettings.notificationRadius) {
        return false;
      }
    }
    
    return true;
  }

  bool itemMatchesKeywords(String itemTag, String itemDescription) {
    if (subscribedKeywords.isEmpty) return false;
    
    final itemText = '$itemTag $itemDescription'.toLowerCase();
    return subscribedKeywords.any((keyword) => itemText.contains(keyword));
  }

  List<String> getMatchedKeywords(String itemTag, String itemDescription) {
    if (subscribedKeywords.isEmpty) return [];
    
    final itemText = '$itemTag $itemDescription'.toLowerCase();
    return subscribedKeywords
        .where((keyword) => itemText.contains(keyword))
        .toList();
  }

  UserModel markItemNotified(String itemId) {
    final newNotifiedIds = List<String>.from(notifiedItemIds);
    if (!newNotifiedIds.contains(itemId)) {
      newNotifiedIds.add(itemId);
      
      if (newNotifiedIds.length > 500) {
        newNotifiedIds.removeRange(0, newNotifiedIds.length - 500);
      }
    }
    return copyWith(notifiedItemIds: newNotifiedIds);
  }

  UserModel updateLocation(double latitude, double longitude, {String? address}) {
    final newLocation = LocationData(
      latitude: latitude,
      longitude: longitude,
      address: address ?? location?.address,
      lastUpdated: DateTime.now(),
    );
    return copyWith(location: newLocation);
  }

  // 新增：標記email已驗證
  UserModel markEmailVerified() {
    return copyWith(
      emailVerified: true,
      emailVerifiedAt: DateTime.now(),
    );
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? lastActive,
    RatingData? rating,
    TransactionStats? transactionStats,
    UserPreferences? preferences,
    LocationData? location,
    bool? isAdmin,
    bool? isBanned,
    // 新增email驗證相關參數
    bool? emailVerified,
    DateTime? emailVerifiedAt,
    List<String>? subscribedKeywords,
    List<String>? notifiedItemIds,
    NotificationSettings? notificationSettings,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      rating: rating ?? this.rating,
      transactionStats: transactionStats ?? this.transactionStats,
      preferences: preferences ?? this.preferences,
      location: location ?? this.location,
      isAdmin: isAdmin ?? this.isAdmin,
      isBanned: isBanned ?? this.isBanned,
      emailVerified: emailVerified ?? this.emailVerified,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      subscribedKeywords: subscribedKeywords ?? this.subscribedKeywords,
      notifiedItemIds: notifiedItemIds ?? this.notifiedItemIds,
      notificationSettings: notificationSettings ?? this.notificationSettings,
    );
  }
}

// 通知設定類別
class NotificationSettings {
  final bool enabled;
  final int quietHoursStart;
  final int quietHoursEnd;
  final int maxNotificationsPerHour;
  final double notificationRadius;
  final bool locationUpdateNotifications;

  NotificationSettings({
    this.enabled = true,
    this.quietHoursStart = 22,
    this.quietHoursEnd = 8,
    this.maxNotificationsPerHour = 3,
    this.notificationRadius = 2.0,
    this.locationUpdateNotifications = true,
  });

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      enabled: map['enabled'] ?? true,
      quietHoursStart: map['quietHoursStart'] ?? 22,
      quietHoursEnd: map['quietHoursEnd'] ?? 8,
      maxNotificationsPerHour: map['maxNotificationsPerHour'] ?? 3,
      notificationRadius: map['notificationRadius']?.toDouble() ?? 2.0,
      locationUpdateNotifications: map['locationUpdateNotifications'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'maxNotificationsPerHour': maxNotificationsPerHour,
      'notificationRadius': notificationRadius,
      'locationUpdateNotifications': locationUpdateNotifications,
    };
  }

  bool isQuietHours() {
    if (!enabled) return true;
    
    final now = DateTime.now();
    final currentHour = now.hour;
    
    if (quietHoursStart <= quietHoursEnd) {
      return currentHour < quietHoursStart || currentHour >= quietHoursEnd;
    } else {
      return currentHour >= quietHoursStart || currentHour < quietHoursEnd;
    }
  }

  NotificationSettings copyWith({
    bool? enabled,
    int? quietHoursStart,
    int? quietHoursEnd,
    int? maxNotificationsPerHour,
    double? notificationRadius,
    bool? locationUpdateNotifications,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      maxNotificationsPerHour: maxNotificationsPerHour ?? this.maxNotificationsPerHour,
      notificationRadius: notificationRadius ?? this.notificationRadius,
      locationUpdateNotifications: locationUpdateNotifications ?? this.locationUpdateNotifications,
    );
  }
}

class RatingData {
  final double averageRating;
  final int totalRatings;
  final int positiveCount;
  final int negativeCount;

  RatingData({
    this.averageRating = 0.0,
    this.totalRatings = 0,
    this.positiveCount = 0,
    this.negativeCount = 0,
  });

  factory RatingData.fromMap(Map<String, dynamic> map) {
    return RatingData(
      averageRating: map['averageRating']?.toDouble() ?? 0.0,
      totalRatings: map['totalRatings'] ?? 0,
      positiveCount: map['positiveCount'] ?? 0,
      negativeCount: map['negativeCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'averageRating': averageRating,
      'totalRatings': totalRatings,
      'positiveCount': positiveCount,
      'negativeCount': negativeCount,
    };
  }
}

class TransactionStats {
  final DateTime joinDate;
  final int totalItemsShared;
  final int totalItemsReceived;
  final int completedTransactions;
  final int totalGiven;
  final int totalReceived;
  final int totalPosted;
  final int recentReceivedCount;
  final DateTime? lastTransactionDate;

  TransactionStats({
    required this.joinDate,
    this.totalItemsShared = 0,
    this.totalItemsReceived = 0,
    this.completedTransactions = 0,
    this.totalGiven = 0,
    this.totalReceived = 0,
    this.totalPosted = 0,
    this.recentReceivedCount = 0,
    this.lastTransactionDate,
  });

  factory TransactionStats.fromMap(Map<String, dynamic> map) {
    return TransactionStats(
      joinDate: map['joinDate'] != null 
          ? (map['joinDate'] as Timestamp).toDate()
          : DateTime.now(),
      totalItemsShared: map['totalItemsShared'] ?? 0,
      totalItemsReceived: map['totalItemsReceived'] ?? 0,
      completedTransactions: map['completedTransactions'] ?? 0,
      totalGiven: map['totalGiven'] ?? 0,
      totalReceived: map['totalReceived'] ?? 0,
      totalPosted: map['totalPosted'] ?? 0,
      recentReceivedCount: map['recentReceivedCount'] ?? 0,
      lastTransactionDate: map['lastTransactionDate'] != null
          ? (map['lastTransactionDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'joinDate': Timestamp.fromDate(joinDate),
      'totalItemsShared': totalItemsShared,
      'totalItemsReceived': totalItemsReceived,
      'completedTransactions': completedTransactions,
      'totalGiven': totalGiven,
      'totalReceived': totalReceived,
      'totalPosted': totalPosted,
      'recentReceivedCount': recentReceivedCount,
      'lastTransactionDate': lastTransactionDate != null
          ? Timestamp.fromDate(lastTransactionDate!)
          : null,
    };
  }
}

class UserPreferences {
  final double searchRadius;
  final bool enableNotifications;
  final bool enableLocationSharing;
  final List<String> favoriteCategories;
  final int maxDailyReceive;
  final bool publicProfile;

  UserPreferences({
    this.searchRadius = 2.0,
    this.enableNotifications = true,
    this.enableLocationSharing = true,
    this.favoriteCategories = const [],
    this.maxDailyReceive = 2,
    this.publicProfile = true,
  });

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      searchRadius: map['searchRadius']?.toDouble() ?? 2.0,
      enableNotifications: map['enableNotifications'] ?? true,
      enableLocationSharing: map['enableLocationSharing'] ?? true,
      favoriteCategories: List<String>.from(map['favoriteCategories'] ?? []),
      maxDailyReceive: map['maxDailyReceive'] ?? 2,
      publicProfile: map['publicProfile'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'searchRadius': searchRadius,
      'enableNotifications': enableNotifications,
      'enableLocationSharing': enableLocationSharing,
      'favoriteCategories': favoriteCategories,
      'maxDailyReceive': maxDailyReceive,
      'publicProfile': publicProfile,
    };
  }
}

class LocationData {
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime? lastUpdated;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.address,
    this.lastUpdated,
  });

  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      address: map['address'],
      lastUpdated: map['lastUpdated'] != null 
          ? (map['lastUpdated'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'lastUpdated': lastUpdated != null 
          ? Timestamp.fromDate(lastUpdated!)
          : null,
    };
  }
}
