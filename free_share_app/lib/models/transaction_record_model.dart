import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// 簡化的交易記錄模型
// 專注於：歷史記錄 + 評價入口
class TransactionRecord {
  final String id;
  final String itemId;              // 物品ID
  final String tag;                 // 物品標題
  final String? firstImageUrl;      // 第一張圖片URL
  final String giverId;             // 贈送者ID
  final String giverName;           // 贈送者姓名
  final String receiverId;          // 接收者ID
  final String receiverName;        // 接收者姓名
  final DateTime completedAt;       // 交易完成時間
  final DateTime createdAt;         // 記錄創建時間
  
  // 評價狀態追蹤
  final Map<String, bool> ratingStatus; // {"giverId": true, "receiverId": false}

  TransactionRecord({
    required this.id,
    required this.itemId,
    required this.tag,
    this.firstImageUrl,
    required this.giverId,
    required this.giverName,
    required this.receiverId,
    required this.receiverName,
    required this.completedAt,
    required this.createdAt,
    required this.ratingStatus,
  });

  factory TransactionRecord.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return TransactionRecord(
      id: doc.id,
      itemId: data['itemId'] ?? '',
      tag: data['tag'] ?? '',
      firstImageUrl: data['firstImageUrl'],
      giverId: data['giverId'] ?? '',
      giverName: data['giverName'] ?? '',
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? '',
      completedAt: (data['completedAt'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      ratingStatus: Map<String, bool>.from(data['ratingStatus'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'tag': tag,
      'firstImageUrl': firstImageUrl,
      'giverId': giverId,
      'giverName': giverName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'completedAt': Timestamp.fromDate(completedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'ratingStatus': ratingStatus,
      'participants': [giverId, receiverId], // 用於查詢
    };
  }

  // 工廠方法：從 ItemModel 創建交易記錄
  factory TransactionRecord.fromItem({
    required String itemId,
    required String tag,
    required String? firstImageUrl,
    required String giverId,
    required String giverName,
    required String receiverId,
    required String receiverName,
    required DateTime completedAt,
  }) {
    return TransactionRecord(
      id: '', // 由 Firestore 自動生成
      itemId: itemId,
      tag: tag,
      firstImageUrl: firstImageUrl,
      giverId: giverId,
      giverName: giverName,
      receiverId: receiverId,
      receiverName: receiverName,
      completedAt: completedAt,
      createdAt: DateTime.now(),
      ratingStatus: {
        giverId: false,
        receiverId: false,
      },
    );
  }

  // 檢查用戶是否參與此交易
  bool isParticipant(String userId) {
    return userId == giverId || userId == receiverId;
  }

  // 獲取交易對方的資訊
  String getOtherUserId(String currentUserId) {
    return currentUserId == giverId ? receiverId : giverId;
  }

  String getOtherUserName(String currentUserId) {
    return currentUserId == giverId ? receiverName : giverName;
  }

  // 檢查當前用戶的角色
  bool isGiver(String userId) => userId == giverId;
  bool isReceiver(String userId) => userId == receiverId;

  // 檢查是否已評價
  bool hasRated(String userId) {
    return ratingStatus[userId] ?? false;
  }

  // 檢查是否可以評價
  bool canRate(String userId) {
    return isParticipant(userId) && !hasRated(userId);
  }

  // 更新評價狀態
  TransactionRecord markAsRated(String userId) {
    final newRatingStatus = Map<String, bool>.from(ratingStatus);
    newRatingStatus[userId] = true;
    
    return TransactionRecord(
      id: id,
      itemId: itemId,
      tag: tag,
      firstImageUrl: firstImageUrl,
      giverId: giverId,
      giverName: giverName,
      receiverId: receiverId,
      receiverName: receiverName,
      completedAt: completedAt,
      createdAt: createdAt,
      ratingStatus: newRatingStatus,
    );
  }

  // 格式化交易時間顯示
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(completedAt);

    if (difference.inDays > 30) {
      return '${completedAt.year}/${completedAt.month}/${completedAt.day}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小時前';
    } else {
      return '剛剛完成';
    }
  }

  // 獲取評價狀態文字
  String getRatingStatusText(String userId) {
    if (!isParticipant(userId)) return '';
    
    if (hasRated(userId)) {
      return '已評價';
    } else {
      return '待評價';
    }
  }

  // 獲取評價按鈕文字
  String getRatingButtonText(String userId) {
    if (!isParticipant(userId)) return '';
    
    if (hasRated(userId)) {
      return '修改評價';
    } else {
      return '評價對方';
    }
  }

  // ===== 新增：雙方評價查詢方法 =====

  // 檢查雙方是否都已評價
  bool bothUsersRated() {
    return ratingStatus[giverId] == true && ratingStatus[receiverId] == true;
  }

  // 獲取評價完成度文字
  String getRatingCompletionText() {
    int ratedCount = ratingStatus.values.where((rated) => rated == true).length;
    return '$ratedCount/2 已評價';
  }

  // 獲取對方的評價狀態
  bool hasOtherUserRated(String currentUserId) {
    if (!isParticipant(currentUserId)) return false;
    
    String otherUserId = getOtherUserId(currentUserId);
    return ratingStatus[otherUserId] ?? false;
  }

  // 獲取對方評價狀態文字
  String getOtherUserRatingStatusText(String currentUserId) {
    if (!isParticipant(currentUserId)) return '';
    
    if (hasOtherUserRated(currentUserId)) {
      return '對方已評價';
    } else {
      return '對方未評價';
    }
  }

  // 獲取雙方評價狀態顏色
  Color getRatingStatusColor(String userId) {
    if (hasRated(userId)) {
      return Colors.green;
    } else {
      return Colors.orange;
    }
  }

  Color getOtherUserRatingStatusColor(String currentUserId) {
    if (hasOtherUserRated(currentUserId)) {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }

  // 檢查是否可以查看對方評價（對方已評價且自己也已評價）
  bool canViewOtherUserRating(String currentUserId) {
    return hasRated(currentUserId) && hasOtherUserRated(currentUserId);
  }

  // 獲取查看對方評價的按鈕文字
  String getViewOtherRatingButtonText(String currentUserId) {
    if (!canViewOtherUserRating(currentUserId)) {
      return '對方未評價';
    }
    return '查看對方評價';
  }
}

// 簡化的交易統計類
class TransactionStats {
  final int totalGiven;           // 總分享次數
  final int totalReceived;        // 總接收次數
  final int totalTransactions;    // 總交易次數
  final DateTime? lastTransactionDate;  // 最後交易時間

  TransactionStats({
    required this.totalGiven,
    required this.totalReceived,
    required this.totalTransactions,
    this.lastTransactionDate,
  });

  factory TransactionStats.fromRecords(List<TransactionRecord> records, String userId) {
    final givenRecords = records.where((r) => r.giverId == userId).toList();
    final receivedRecords = records.where((r) => r.receiverId == userId).toList();
    
    // 按時間排序
    final sortedRecords = List<TransactionRecord>.from(records)
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    
    return TransactionStats(
      totalGiven: givenRecords.length,
      totalReceived: receivedRecords.length,
      totalTransactions: records.length,
      lastTransactionDate: records.isNotEmpty ? sortedRecords.first.completedAt : null,
    );
  }
}
