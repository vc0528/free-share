import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  newItemMatch,      // 新物品符合關鍵字
  locationUpdate,    // 位置變化發現新物品
  itemReserved,      // 物品被預約
  itemCompleted,     // 交易完成
  chatMessage,       // 聊天訊息
  system,           // 系統通知
}

enum NotificationStatus {
  unread,           // 未讀
  read,             // 已讀
  clicked,          // 已點擊查看
  dismissed,        // 已忽略
}

class NotificationModel {
  final String id;
  final String userId;                    // 接收通知的用戶ID
  final NotificationType type;
  final NotificationStatus status;
  final String title;
  final String body;
  final String? imageUrl;                 // 物品圖片URL
  final Map<String, dynamic> data;        // 額外數據
  final DateTime createdAt;
  final DateTime? readAt;                 // 讀取時間
  final DateTime? clickedAt;              // 點擊時間
  
  // 物品相關資訊
  final String? itemId;                   // 相關物品ID
  final String? itemTitle;                // 物品標題
  final List<String>? matchedKeywords;    // 符合的關鍵字
  final double? distanceKm;               // 距離（公里）

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    this.status = NotificationStatus.unread,
    required this.title,
    required this.body,
    this.imageUrl,
    this.data = const {},
    required this.createdAt,
    this.readAt,
    this.clickedAt,
    this.itemId,
    this.itemTitle,
    this.matchedKeywords,
    this.distanceKm,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: _stringToType(data['type'] ?? 'system'),
      status: _stringToStatus(data['status'] ?? 'unread'),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      imageUrl: data['imageUrl'],
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      clickedAt: (data['clickedAt'] as Timestamp?)?.toDate(),
      itemId: data['itemId'],
      itemTitle: data['itemTitle'],
      matchedKeywords: data['matchedKeywords'] != null 
          ? List<String>.from(data['matchedKeywords']) : null,
      distanceKm: data['distanceKm']?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': _typeToString(type),
      'status': _statusToString(status),
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'clickedAt': clickedAt != null ? Timestamp.fromDate(clickedAt!) : null,
      'itemId': itemId,
      'itemTitle': itemTitle,
      'matchedKeywords': matchedKeywords,
      'distanceKm': distanceKm,
    };
  }

  // 工廠方法：創建新物品匹配通知
  factory NotificationModel.newItemMatch({
    required String userId,
    required String itemId,
    required String itemTitle,
    required String itemDescription,
    required List<String> matchedKeywords,
    required double distanceKm,
    String? imageUrl,
  }) {
    return NotificationModel(
      id: '', // Firestore 會自動生成
      userId: userId,
      type: NotificationType.newItemMatch,
      title: '發現符合條件的物品！',
      body: '$itemTitle - 距離您 ${distanceKm.toStringAsFixed(1)}km',
      imageUrl: imageUrl,
      itemId: itemId,
      itemTitle: itemTitle,
      matchedKeywords: matchedKeywords,
      distanceKm: distanceKm,
      createdAt: DateTime.now(),
      data: {
        'itemDescription': itemDescription,
        'notificationType': 'newItemMatch',
      },
    );
  }

  // 工廠方法：創建位置更新通知
  factory NotificationModel.locationUpdate({
    required String userId,
    required String itemId,
    required String itemTitle,
    required List<String> matchedKeywords,
    required double distanceKm,
    String? imageUrl,
  }) {
    return NotificationModel(
      id: '',
      userId: userId,
      type: NotificationType.locationUpdate,
      title: '在新位置發現符合條件的物品！',
      body: '$itemTitle - 距離您 ${distanceKm.toStringAsFixed(1)}km',
      imageUrl: imageUrl,
      itemId: itemId,
      itemTitle: itemTitle,
      matchedKeywords: matchedKeywords,
      distanceKm: distanceKm,
      createdAt: DateTime.now(),
      data: {
        'notificationType': 'locationUpdate',
      },
    );
  }

  // 類型轉換方法
  static NotificationType _stringToType(String typeString) {
    switch (typeString) {
      case 'newItemMatch': return NotificationType.newItemMatch;
      case 'locationUpdate': return NotificationType.locationUpdate;
      case 'itemReserved': return NotificationType.itemReserved;
      case 'itemCompleted': return NotificationType.itemCompleted;
      case 'chatMessage': return NotificationType.chatMessage;
      default: return NotificationType.system;
    }
  }

  static String _typeToString(NotificationType type) {
    switch (type) {
      case NotificationType.newItemMatch: return 'newItemMatch';
      case NotificationType.locationUpdate: return 'locationUpdate';
      case NotificationType.itemReserved: return 'itemReserved';
      case NotificationType.itemCompleted: return 'itemCompleted';
      case NotificationType.chatMessage: return 'chatMessage';
      case NotificationType.system: return 'system';
    }
  }

  static NotificationStatus _stringToStatus(String statusString) {
    switch (statusString) {
      case 'read': return NotificationStatus.read;
      case 'clicked': return NotificationStatus.clicked;
      case 'dismissed': return NotificationStatus.dismissed;
      default: return NotificationStatus.unread;
    }
  }

  static String _statusToString(NotificationStatus status) {
    switch (status) {
      case NotificationStatus.unread: return 'unread';
      case NotificationStatus.read: return 'read';
      case NotificationStatus.clicked: return 'clicked';
      case NotificationStatus.dismissed: return 'dismissed';
    }
  }

  // 狀態更新方法
  NotificationModel markAsRead() {
    return copyWith(
      status: NotificationStatus.read,
      readAt: DateTime.now(),
    );
  }

  NotificationModel markAsClicked() {
    return copyWith(
      status: NotificationStatus.clicked,
      clickedAt: DateTime.now(),
      readAt: readAt ?? DateTime.now(),
    );
  }

  NotificationModel markAsDismissed() {
    return copyWith(
      status: NotificationStatus.dismissed,
      readAt: readAt ?? DateTime.now(),
    );
  }

  // 檢查方法
  bool get isUnread => status == NotificationStatus.unread;
  bool get isRead => status == NotificationStatus.read;
  bool get isClicked => status == NotificationStatus.clicked;
  bool get isDismissed => status == NotificationStatus.dismissed;

  // 獲取通知年齡
  Duration get age => DateTime.now().difference(createdAt);

  // 是否是今天的通知
  bool get isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notificationDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
    return today == notificationDate;
  }

  // 獲取時間顯示文字
  String get timeDisplayText {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return '剛剛';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分鐘前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小時前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${createdAt.month}/${createdAt.day}';
    }
  }

  // 獲取匹配關鍵字的顯示文字
  String get matchedKeywordsText {
    if (matchedKeywords == null || matchedKeywords!.isEmpty) {
      return '';
    }
    return matchedKeywords!.join(', ');
  }

  // 獲取通知圖標
  String get notificationIcon {
    switch (type) {
      case NotificationType.newItemMatch:
        return '🎁';
      case NotificationType.locationUpdate:
        return '📍';
      case NotificationType.itemReserved:
        return '📋';
      case NotificationType.itemCompleted:
        return '✅';
      case NotificationType.chatMessage:
        return '💬';
      case NotificationType.system:
        return '🔔';
    }
  }

  // 獲取通知類型描述
  String get typeDescription {
    switch (type) {
      case NotificationType.newItemMatch:
        return '新物品匹配';
      case NotificationType.locationUpdate:
        return '位置更新';
      case NotificationType.itemReserved:
        return '物品預約';
      case NotificationType.itemCompleted:
        return '交易完成';
      case NotificationType.chatMessage:
        return '聊天訊息';
      case NotificationType.system:
        return '系統通知';
    }
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    NotificationStatus? status,
    String? title,
    String? body,
    String? imageUrl,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? readAt,
    DateTime? clickedAt,
    String? itemId,
    String? itemTitle,
    List<String>? matchedKeywords,
    double? distanceKm,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      clickedAt: clickedAt ?? this.clickedAt,
      itemId: itemId ?? this.itemId,
      itemTitle: itemTitle ?? this.itemTitle,
      matchedKeywords: matchedKeywords ?? this.matchedKeywords,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }
}
