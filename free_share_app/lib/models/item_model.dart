import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';  // for LocationData

// 檢舉資料類別
class ReportData {
  final DateTime timestamp;
  final String reporterUid;
  final String reason;
  
  ReportData({
    required this.timestamp,
    required this.reporterUid,
    required this.reason,
  });
  
  factory ReportData.fromMap(Map<String, dynamic> map) {
    return ReportData(
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      reporterUid: map['reporterUid'] ?? '',
      reason: map['reason'] ?? '',
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'reporterUid': reporterUid,
      'reason': reason,
    };
  }
}

// 物品狀態枚舉
enum ItemStatus {
  available,  // 上架：大家可見，可以下架、刪除、預約
  offline,    // 下架：只有上架者可見，可以上架、刪除
  reserved,   // 預約中：上架者和預約者可見，可以上架、交易完成
  completed,  // 交易完成：上架者和預約者可見，自動下架、可評價、可刪除
  banned,     // 被檢舉禁用：只有上架者可見，只能刪除
}

class ItemModel {
  final String id;
  final String ownerId;
  final String description; // 物品描述 (用戶填寫)
  final String tag;         // 標籤 (用戶選擇，用於過濾和地圖顯示)
  final List<String> imageUrls;
  final LocationData location;        // 模糊化後的位置
  final LocationData originalLocation; // 真實位置 (僅管理員可見)
  final DateTime createdAt;
  final ItemStatus status;
  final String geoHash;
  final int reportCount;
  final bool isReported;
  
  // 預約相關欄位
  final String? reservedByUserId; // 預約者ID (預約中和交易完成時使用)
  final DateTime? reservedAt;     // 預約時間
  final DateTime? completedAt;    // 交易完成時間
  final bool hasOwnerRated;       // 物品擁有者是否已評價
  final bool hasReserverRated;    // 預約者是否已評價

  // 檢舉相關欄位
  final List<ReportData> reports; // 檢舉記錄列表

  ItemModel({
    required this.id,
    required this.ownerId,
    required this.description,
    required this.tag,
    required this.imageUrls,
    required this.location,
    required this.originalLocation,
    required this.createdAt,
    this.status = ItemStatus.available,
    required this.geoHash,
    this.reportCount = 0,
    this.isReported = false,
    this.reservedByUserId,
    this.reservedAt,
    this.completedAt,
    this.hasOwnerRated = false,
    this.hasReserverRated = false,
    this.reports = const [],
  });

  factory ItemModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return ItemModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      description: data['description'] ?? '',
      tag: data['tag'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      location: LocationData.fromMap(data['location']),
      originalLocation: LocationData.fromMap(data['originalLocation']),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: _getStatusFromString(data['status'] ?? 'available'),
      geoHash: data['geoHash'] ?? '',
      reportCount: data['reportCount'] ?? 0,
      isReported: data['isReported'] ?? false,
      reservedByUserId: data['reservedByUserId'],
      reservedAt: data['reservedAt'] != null ? (data['reservedAt'] as Timestamp).toDate() : null,
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      hasOwnerRated: data['hasOwnerRated'] ?? false,
      hasReserverRated: data['hasReserverRated'] ?? false,
      reports: (data['reports'] as List<dynamic>?)
          ?.map((reportData) => ReportData.fromMap(reportData as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'description': description,
      'tag': tag,
      'imageUrls': imageUrls,
      'location': location.toMap(),
      'originalLocation': originalLocation.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.name,
      'geoHash': geoHash,
      'reportCount': reportCount,
      'isReported': isReported,
      'reservedByUserId': reservedByUserId,
      'reservedAt': reservedAt != null ? Timestamp.fromDate(reservedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'hasOwnerRated': hasOwnerRated,
      'hasReserverRated': hasReserverRated,
      'reports': reports.map((report) => report.toMap()).toList(),
    };
  }

  // 從字符串轉換為枚舉
  static ItemStatus _getStatusFromString(String statusString) {
    switch (statusString) {
      case 'available':
        return ItemStatus.available;
      case 'offline':
        return ItemStatus.offline;
      case 'reserved':
        return ItemStatus.reserved;
      case 'completed':
        return ItemStatus.completed;
      case 'banned':
        return ItemStatus.banned;
      default:
        return ItemStatus.available;
    }
  }

  // 可見性判斷
  bool isVisibleToUser(String currentUserId) {
    switch (status) {
      case ItemStatus.available:
        return true; // 所有人可見
      case ItemStatus.offline:
        return currentUserId == ownerId; // 只有物品擁有者可見
      case ItemStatus.reserved:
      case ItemStatus.completed:
        return currentUserId == ownerId || currentUserId == reservedByUserId; // 擁有者和預約者可見
      case ItemStatus.banned:
        return currentUserId == ownerId; // 被檢舉物品只有擁有者可見
    }
  }

  // 獲取可執行的操作
  List<ItemAction> getAvailableActions(String currentUserId) {
    if (currentUserId != ownerId && currentUserId != reservedByUserId) {
      // 非相關用戶
      if (status == ItemStatus.available) {
        return [ItemAction.reserve, ItemAction.report];
      }
      return [];
    }

    if (currentUserId == ownerId) {
      // 物品擁有者
      switch (status) {
        case ItemStatus.available:
          return [ItemAction.takeOffline, ItemAction.delete];
        case ItemStatus.offline:
          return [ItemAction.putOnline, ItemAction.delete];
        case ItemStatus.reserved:
          return [ItemAction.putOnline, ItemAction.markCompleted];
        case ItemStatus.completed:
          List<ItemAction> actions = [ItemAction.delete];
          if (!hasOwnerRated) actions.add(ItemAction.rate);
          return actions;
        case ItemStatus.banned:
          return [ItemAction.delete]; // 被檢舉物品只能刪除
      }
    } else if (currentUserId == reservedByUserId) {
      // 預約者
      if (status == ItemStatus.completed && !hasReserverRated) {
        return [ItemAction.rate];
      }
    }

    return [];
  }

  // 檢舉相關方法
  bool hasUserReported(String userUid) {
    return reports.any((report) => report.reporterUid == userUid);
  }

  bool get isReportBanned => reports.length >= 3;

  // 複製方法
  ItemModel copyWith({
    String? id,
    String? ownerId,
    String? description,
    String? tag,
    List<String>? imageUrls,
    LocationData? location,
    LocationData? originalLocation,
    DateTime? createdAt,
    ItemStatus? status,
    String? geoHash,
    int? reportCount,
    bool? isReported,
    String? reservedByUserId,
    DateTime? reservedAt,
    DateTime? completedAt,
    bool? hasOwnerRated,
    bool? hasReserverRated,
    List<ReportData>? reports,
  }) {
    return ItemModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      description: description ?? this.description,
      tag: tag ?? this.tag,
      imageUrls: imageUrls ?? this.imageUrls,
      location: location ?? this.location,
      originalLocation: originalLocation ?? this.originalLocation,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      geoHash: geoHash ?? this.geoHash,
      reportCount: reportCount ?? this.reportCount,
      isReported: isReported ?? this.isReported,
      reservedByUserId: reservedByUserId ?? this.reservedByUserId,
      reservedAt: reservedAt ?? this.reservedAt,
      completedAt: completedAt ?? this.completedAt,
      hasOwnerRated: hasOwnerRated ?? this.hasOwnerRated,
      hasReserverRated: hasReserverRated ?? this.hasReserverRated,
      reports: reports ?? this.reports,
    );
  }
}

// 可執行的操作枚舉
enum ItemAction {
  putOnline,    // 上架
  takeOffline,  // 下架
  reserve,      // 預約
  markCompleted, // 標記為交易完成
  rate,         // 評價
  delete,       // 刪除
  report,       // 檢舉
}
