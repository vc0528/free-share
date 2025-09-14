import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/item_model.dart';
import '../models/user_model.dart';  // 添加這行來導入 LocationData
import '../services/item_service.dart';

class ItemProvider extends ChangeNotifier {
  final ItemService _itemService = ItemService();
  
  List<ItemModel> _nearbyItems = [];
  List<ItemModel> _userItems = [];
  List<Map<String, dynamic>> _transactionRecords = [];
  bool _isLoading = false;
  bool _isReporting = false; // 檢舉進行中狀態
  String? _error;

  List<ItemModel> get nearbyItems => _nearbyItems;
  List<ItemModel> get userItems => _userItems;
  List<Map<String, dynamic>> get transactionRecords => _transactionRecords;
  bool get isLoading => _isLoading;
  bool get isReporting => _isReporting;
  String? get error => _error;

  Future<String?> addItem({
    required String ownerId,
    required String description,
    required String tag,
    required List<File> imageFiles,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    print('ItemProvider: 開始上架物品');
    print('ItemProvider: ownerId=$ownerId, tag=$tag, 圖片數=${imageFiles.length}');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('ItemProvider: 調用 ItemService.addItem');
      String itemId = await _itemService.addItem(
        ownerId: ownerId,
        description: description,
        tag: tag,
        imageFiles: imageFiles,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      
      _isLoading = false;
      notifyListeners();
      print('ItemProvider: 上架成功，itemId=$itemId');
      return itemId;
    } catch (e) {
      print('ItemProvider: 上架失敗，錯誤=$e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadNearbyItems(double latitude, double longitude) async {
    _isLoading = true;
    notifyListeners();

    try {
      _nearbyItems = await _itemService.getNearbyItems(latitude, longitude, 2.0);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // 載入地圖可顯示的物品
  Future<void> loadMapVisibleItems(double latitude, double longitude) async {
    _isLoading = true;
    notifyListeners();

    try {
      _nearbyItems = await _itemService.getMapVisibleItems(latitude, longitude, 2.0);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserItems(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _userItems = await _itemService.getUserItems(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadItemsByTag(String tag, double latitude, double longitude) async {
    _isLoading = true;
    notifyListeners();

    try {
      _nearbyItems = await _itemService.getItemsByTag(tag, latitude, longitude, 2.0);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ItemModel?> getItemById(String itemId) async {
    try {
      return await _itemService.getItemById(itemId);
    } catch (e) {
      print('獲取物品詳情失敗: $e');
      return null;
    }
  }

  // ===== 檢舉功能 =====

  /// 檢舉物品
  /// [itemId] 物品ID
  /// [reporterUid] 檢舉者用戶名
  /// [reason] 檢舉原因
  Future<void> reportItem(String itemId, String reporterUid, String reason) async {
    try {
      _isReporting = true;
      _error = null;
      notifyListeners();

      await _itemService.reportItem(itemId, reporterUid, reason);

      // 更新本地物品狀態（移除被檢舉的物品或更新狀態）
      _updateLocalItemAfterReport(itemId, reporterUid, reason);
      
      _isReporting = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isReporting = false;
      notifyListeners();
      rethrow;
    }
  }

  /// 檢查用戶是否已檢舉某物品
  /// [itemId] 物品ID
  /// [username] 用戶名
  Future<bool> hasUserReportedItem(String itemId, String username) async {
    try {
      return await _itemService.hasUserReportedItem(itemId, username);
    } catch (e) {
      print('檢查檢舉狀態失敗: $e');
      return false;
    }
  }

  /// 檢查本地物品是否已被用戶檢舉
  /// [itemId] 物品ID
  /// [username] 用戶名
  bool hasUserReportedItemLocally(String itemId, String username) {
    // 先在附近物品中查找
    final nearbyItem = _nearbyItems.firstWhere(
      (item) => item.id == itemId,
      orElse: () => ItemModel(
        id: '',
        ownerId: '',
        description: '',
        tag: '',
        imageUrls: [],
        location: LocationData(latitude: 0, longitude: 0),
        originalLocation: LocationData(latitude: 0, longitude: 0),
        createdAt: DateTime.now(),
        geoHash: '',
      ),
    );
    
    if (nearbyItem.id.isNotEmpty) {
      return nearbyItem.hasUserReported(username);
    }

    // 再在用戶物品中查找
    final userItem = _userItems.firstWhere(
      (item) => item.id == itemId,
      orElse: () => ItemModel(
        id: '',
        ownerId: '',
        description: '',
        tag: '',
        imageUrls: [],
        location: LocationData(latitude: 0, longitude: 0),
        originalLocation: LocationData(latitude: 0, longitude: 0),
        createdAt: DateTime.now(),
        geoHash: '',
      ),
    );
    
    return userItem.id.isNotEmpty ? userItem.hasUserReported(username) : false;
  }

  // 物品編輯
  Future<void> updateItem({
    required String itemId,
    required String description,
    required String tag,
    required List<String> existingImageUrls,
    required List<File> newImageFiles,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _itemService.updateItem(
        itemId: itemId,
        description: description,
        tag: tag,
        existingImageUrls: existingImageUrls,
        newImageFiles: newImageFiles,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ===== 物品狀態管理方法 =====

  // 上架物品
  Future<void> putItemOnline(String itemId) async {
    try {
      await _itemService.putItemOnline(itemId);
      // 更新本地狀態
      _updateLocalItemStatus(itemId, ItemStatus.available);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // 下架物品
  Future<void> takeItemOffline(String itemId) async {
    try {
      await _itemService.takeItemOffline(itemId);
      // 更新本地狀態
      _updateLocalItemStatus(itemId, ItemStatus.offline);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // 預約物品
  Future<void> reserveItem(String itemId, String reserverUserId) async {
    try {
      await _itemService.reserveItem(itemId, reserverUserId);
      // 更新本地狀態
      _updateLocalItemStatus(itemId, ItemStatus.reserved, reserverUserId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // 標記交易完成
  Future<void> markItemCompleted(String itemId) async {
    try {
      await _itemService.markItemCompleted(itemId);
      // 更新本地狀態
      _updateLocalItemStatus(itemId, ItemStatus.completed);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // 更新評價狀態
  Future<void> updateRatingStatus(String itemId, bool isOwnerRating) async {
    try {
      await _itemService.updateRatingStatus(itemId, isOwnerRating);
      // 更新本地評價狀態
      _updateLocalRatingStatus(itemId, isOwnerRating);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // 更新狀態
  Future<void> updateItemStatus(String itemId, ItemStatus status) async {
    try {
      await _itemService.updateItemStatus(itemId, status);
      _updateLocalItemStatus(itemId, status);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
  
  Future<void> deleteItem(String itemId) async {
    try {
      await _itemService.deleteItem(itemId);
      _userItems.removeWhere((item) => item.id == itemId);
      _nearbyItems.removeWhere((item) => item.id == itemId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ===== 交易記錄相關 =====

  // 載入用戶交易記錄
  Future<void> loadUserTransactionRecords(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _transactionRecords = await _itemService.getUserTransactionRecords(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===== 統計和篩選方法 =====

  Future<Map<String, int>> getUserItemStats(String userId) async {
    try {
      return await _itemService.getUserItemStats(userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return {
        'total': 0,
        'available': 0,
        'offline': 0,
        'reserved': 0,
        'completed': 0,
        'banned': 0,
      };
    }
  }

  List<ItemModel> searchUserItems(String query) {
    if (query.isEmpty) return _userItems;
    return _userItems.where((item) {
      return item.tag.toLowerCase().contains(query.toLowerCase()) ||
             item.description.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // 支援新的狀態系統（包含 banned）
  List<ItemModel> filterUserItemsByStatus(ItemStatus? status) {
    if (status == null) return _userItems;
    return _userItems.where((item) => item.status == status).toList();
  }

  // 舊版本兼容（更新支援 banned 狀態）
  List<ItemModel> filterUserItemsByStatusString(String status) {
    if (status == 'all') return _userItems;
    ItemStatus? statusEnum = _stringToStatus(status);
    if (statusEnum == null) return _userItems;
    return filterUserItemsByStatus(statusEnum);
  }

  // 獲取用戶可執行的操作
  List<ItemAction> getAvailableActions(String itemId, String currentUserId) {
    final item = _userItems.firstWhere(
      (item) => item.id == itemId,
      orElse: () => _nearbyItems.firstWhere(
        (item) => item.id == itemId,
        orElse: () => throw Exception('Item not found'),
      ),
    );
    return item.getAvailableActions(currentUserId);
  }

  // ===== 輔助方法 =====

  // 更新本地物品狀態
  void _updateLocalItemStatus(String itemId, ItemStatus status, [String? reserverUserId]) {
    // 更新用戶物品列表
    int userIndex = _userItems.indexWhere((item) => item.id == itemId);
    if (userIndex != -1) {
      _userItems[userIndex] = _userItems[userIndex].copyWith(
        status: status,
        reservedByUserId: reserverUserId,
        reservedAt: reserverUserId != null ? DateTime.now() : null,
      );
    }

    // 更新附近物品列表
    int nearbyIndex = _nearbyItems.indexWhere((item) => item.id == itemId);
    if (nearbyIndex != -1) {
      _nearbyItems[nearbyIndex] = _nearbyItems[nearbyIndex].copyWith(
        status: status,
        reservedByUserId: reserverUserId,
        reservedAt: reserverUserId != null ? DateTime.now() : null,
      );
    }
  }

  // 更新本地評價狀態
  void _updateLocalRatingStatus(String itemId, bool isOwnerRating) {
    // 更新用戶物品列表
    int userIndex = _userItems.indexWhere((item) => item.id == itemId);
    if (userIndex != -1) {
      _userItems[userIndex] = _userItems[userIndex].copyWith(
        hasOwnerRated: isOwnerRating ? true : _userItems[userIndex].hasOwnerRated,
        hasReserverRated: !isOwnerRating ? true : _userItems[userIndex].hasReserverRated,
      );
    }

    // 更新附近物品列表
    int nearbyIndex = _nearbyItems.indexWhere((item) => item.id == itemId);
    if (nearbyIndex != -1) {
      _nearbyItems[nearbyIndex] = _nearbyItems[nearbyIndex].copyWith(
        hasOwnerRated: isOwnerRating ? true : _nearbyItems[nearbyIndex].hasOwnerRated,
        hasReserverRated: !isOwnerRating ? true : _nearbyItems[nearbyIndex].hasReserverRated,
      );
    }
  }

  // 更新檢舉後的本地物品狀態
  void _updateLocalItemAfterReport(String itemId, String reporterUid, String reason) {
    final newReport = ReportData(
      timestamp: DateTime.now(),
      reporterUid: reporterUid,
      reason: reason,
    );

    // 更新附近物品列表
    int nearbyIndex = _nearbyItems.indexWhere((item) => item.id == itemId);
    if (nearbyIndex != -1) {
      final item = _nearbyItems[nearbyIndex];
      final updatedReports = [...item.reports, newReport];
      final newStatus = updatedReports.length >= 3 ? ItemStatus.banned : item.status;
      
      _nearbyItems[nearbyIndex] = item.copyWith(
        reports: updatedReports,
        reportCount: updatedReports.length,
        isReported: true,
        status: newStatus,
      );
    }

    // 更新用戶物品列表
    int userIndex = _userItems.indexWhere((item) => item.id == itemId);
    if (userIndex != -1) {
      final item = _userItems[userIndex];
      final updatedReports = [...item.reports, newReport];
      final newStatus = updatedReports.length >= 3 ? ItemStatus.banned : item.status;
      
      _userItems[userIndex] = item.copyWith(
        reports: updatedReports,
        reportCount: updatedReports.length,
        isReported: true,
        status: newStatus,
      );
    }
  }

  // 字符串轉狀態枚舉（向後兼容，新增 banned 支援）
  ItemStatus? _stringToStatus(String status) {
    switch (status) {
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
        return null;
    }
  }

  // ===== 清理方法 =====

  void clearUserItems() {
    _userItems.clear();
    notifyListeners();
  }

  void clearTransactionRecords() {
    _transactionRecords.clear();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearAll() {
    _userItems.clear();
    _nearbyItems.clear();
    _transactionRecords.clear();
    _error = null;
    _isLoading = false;
    _isReporting = false;
    notifyListeners();
  }
}
