import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String itemId;
  final String giverId;  // 分享者
  final String receiverId;  // 接收者
  final TransactionStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? meetingLocation;
  final DateTime? meetingTime;
  final String? notes;
  
  TransactionModel({
    required this.id,
    required this.itemId,
    required this.giverId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.meetingLocation,
    this.meetingTime,
    this.notes,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return TransactionModel(
      id: doc.id,
      itemId: data['itemId'] ?? '',
      giverId: data['giverId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      status: TransactionStatus.values.firstWhere(
        (e) => e.toString() == 'TransactionStatus.${data['status']}',
        orElse: () => TransactionStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      meetingLocation: data['meetingLocation'],
      meetingTime: data['meetingTime'] != null
          ? (data['meetingTime'] as Timestamp).toDate()
          : null,
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'giverId': giverId,
      'receiverId': receiverId,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null 
          ? Timestamp.fromDate(completedAt!)
          : null,
      'meetingLocation': meetingLocation,
      'meetingTime': meetingTime != null
          ? Timestamp.fromDate(meetingTime!)
          : null,
      'notes': notes,
    };
  }

  TransactionModel copyWith({
    String? id,
    String? itemId,
    String? giverId,
    String? receiverId,
    TransactionStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? meetingLocation,
    DateTime? meetingTime,
    String? notes,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      giverId: giverId ?? this.giverId,
      receiverId: receiverId ?? this.receiverId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      meetingLocation: meetingLocation ?? this.meetingLocation,
      meetingTime: meetingTime ?? this.meetingTime,
      notes: notes ?? this.notes,
    );
  }
}

enum TransactionStatus {
  pending,     // 等待確認
  confirmed,   // 已確認
  completed,   // 已完成
  cancelled,   // 已取消
}

extension TransactionStatusExtension on TransactionStatus {
  String get displayName {
    switch (this) {
      case TransactionStatus.pending:
        return '等待確認';
      case TransactionStatus.confirmed:
        return '已確認';
      case TransactionStatus.completed:
        return '已完成';
      case TransactionStatus.cancelled:
        return '已取消';
    }
  }

  String get description {
    switch (this) {
      case TransactionStatus.pending:
        return '等待對方確認交易請求';
      case TransactionStatus.confirmed:
        return '交易已確認，可安排取貨';
      case TransactionStatus.completed:
        return '交易已完成';
      case TransactionStatus.cancelled:
        return '交易已取消';
    }
  }
}
