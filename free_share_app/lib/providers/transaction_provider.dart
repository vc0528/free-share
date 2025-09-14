import 'package:flutter/foundation.dart';
import '../models/transaction_record_model.dart';
import '../services/transaction_record_service.dart';
import '../services/transaction_service.dart';
import '../models/rating_model.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionRecordService _recordService = TransactionRecordService();
  final TransactionService _transactionService = TransactionService(); // 保留原有評價功能

  List<TransactionRecord> _userTransactionRecords = [];
  List<RatingModel> _userRatings = [];
  UserRatingStats? _ratingStats;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<TransactionRecord> get userTransactionRecords => _userTransactionRecords;
  List<RatingModel> get userRatings => _userRatings;
  UserRatingStats? get ratingStats => _ratingStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ===== 交易記錄相關方法 =====

  // 載入用戶交易記錄
  Future<void> loadUserTransactionRecords(String userId) async {
    try {
      _setLoading(true);
      _clearError();

      _userTransactionRecords = await _recordService.getUserTransactionRecords(userId);
      notifyListeners();
    } catch (e) {
      _setError('載入交易記錄失敗: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // 創建交易記錄（從物品完成時呼叫）
  Future<String?> createTransactionRecord({
    required String itemId,
    required String tag,
    required String? firstImageUrl,
    required String giverId,
    required String giverName,
    required String receiverId,
    required String receiverName,
    required DateTime completedAt,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // 使用工廠方法創建記錄
      final record = TransactionRecord.fromItem(
        itemId: itemId,
        tag: tag,
        firstImageUrl: firstImageUrl,
        giverId: giverId,
        giverName: giverName,
        receiverId: receiverId,
        receiverName: receiverName,
        completedAt: completedAt,
      );

      // 使用 Service 創建記錄
      final recordId = await _recordService.createTransactionRecord(record);

      // 重新載入記錄
      await loadUserTransactionRecords(giverId);
      if (giverId != receiverId) {
        await loadUserTransactionRecords(receiverId);
      }

      return recordId;
    } catch (e) {
      _setError('創建交易記錄失敗: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // 獲取特定物品的交易記錄
  Future<TransactionRecord?> getItemTransactionRecord(String itemId) async {
    try {
      return await _recordService.getItemTransactionRecord(itemId);
    } catch (e) {
      _setError('獲取物品交易記錄失敗: ${e.toString()}');
      return null;
    }
  }

  // 獲取交易統計
  Future<TransactionStats> getUserTransactionStats(String userId) async {
    try {
      return await _recordService.getUserTransactionStats(userId);
    } catch (e) {
      _setError('獲取交易統計失敗: ${e.toString()}');
      return TransactionStats.fromRecords([], userId);
    }
  }

  // ===== 評價相關方法 =====

  // 檢查是否可以評價物品
  Future<bool> canRateItem(String userId, String itemId) async {
    try {
      bool hasRated = await _recordService.hasUserRatedItem(userId, itemId);
      return !hasRated;
    } catch (e) {
      _setError('檢查評價權限失敗: ${e.toString()}');
      return false;
    }
  }

  // 獲取用戶對特定物品的評價
  Future<RatingModel?> getUserRatingForItem(String userId, String itemId) async {
    try {
      return await _transactionService.getUserRatingForItem(userId, itemId);
    } catch (e) {
      _setError('獲取用戶評價失敗: ${e.toString()}');
      return null;
    }
  }

  // 獲取雙方評價
  Future<Map<String, RatingModel?>> getRatingsBetweenUsers(String user1Id, String user2Id, String itemId) async {
    try {
      return await _transactionService.getRatingsBetweenUsers(user1Id, user2Id, itemId);
    } catch (e) {
      _setError('獲取雙方評價失敗: ${e.toString()}');
      return {user1Id: null, user2Id: null};
    }
  }

  // 根據物品創建評價
  Future<String?> createRatingByItem({
    required String raterId,
    required String ratedUserId,
    required String itemId,
    required int rating,
    String? comment,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // 檢查是否已評價過
      bool canRate = await canRateItem(raterId, itemId);
      if (!canRate) {
        throw Exception('您已經評價過此物品');
      }

      // 創建評價（使用原有的 TransactionService）
      String ratingId = await _transactionService.createRatingByItem(
        raterId: raterId,
        ratedUserId: ratedUserId,
        itemId: itemId,
        rating: rating,
        comment: comment,
      );

      // 更新交易記錄的評價狀態
      await _recordService.updateRatingStatus(itemId, raterId);

      // 重新載入評價統計
      await loadUserRatings(ratedUserId);

      // 重新載入交易記錄（更新評價狀態）
      await loadUserTransactionRecords(raterId);

      return ratingId;
    } catch (e) {
      _setError('創建評價失敗: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // 更新評價
  Future<bool> updateRatingByItem({
    required String raterId,
    required String itemId,
    required int rating,
    String? comment,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      bool success = await _transactionService.updateRatingByItem(
        raterId: raterId,
        itemId: itemId,
        rating: rating,
        comment: comment,
      );

      if (success) {
        // 重新載入交易記錄
        await loadUserTransactionRecords(raterId);
      }

      return success;
    } catch (e) {
      _setError('更新評價失敗: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // 刪除評價
  Future<bool> deleteRatingByItem(String raterId, String itemId) async {
    try {
      _setLoading(true);
      _clearError();

      bool success = await _transactionService.deleteRatingByItem(raterId, itemId);

      if (success) {
        // 更新交易記錄的評價狀態
        await _recordService.updateRatingStatus(itemId, raterId);
        
        // 重新載入交易記錄
        await loadUserTransactionRecords(raterId);
      }

      return success;
    } catch (e) {
      _setError('刪除評價失敗: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ===== 保留原有的評價功能（向後兼容） =====

  // 載入用戶評價
  Future<void> loadUserRatings(String userId) async {
    try {
      _setLoading(true);
      _clearError();

      _userRatings = await _transactionService.getUserRatings(userId);
      _ratingStats = await _transactionService.getUserRatingStats(userId);
      notifyListeners();
    } catch (e) {
      _setError('載入評價記錄失敗: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // 監聽交易記錄變化
  Stream<List<TransactionRecord>> watchUserTransactionRecords(String userId) {
    return _recordService.watchUserTransactionRecords(userId);
  }

  // ===== 工具方法 =====

  // 獲取交易記錄統計
  Map<String, int> getTransactionRecordCounts() {
    return {
      'total': _userTransactionRecords.length,
      'asGiver': _userTransactionRecords.where((r) => r.isGiver(_getCurrentUserId() ?? '')).length,
      'asReceiver': _userTransactionRecords.where((r) => r.isReceiver(_getCurrentUserId() ?? '')).length,
    };
  }

  // 獲取最近的交易記錄
  List<TransactionRecord> getRecentTransactionRecords([int limit = 5]) {
    List<TransactionRecord> sorted = List.from(_userTransactionRecords);
    sorted.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return sorted.take(limit).toList();
  }

  // 檢查用戶間是否有交易記錄
  Future<bool> hasTransactionBetween(String userId1, String userId2) async {
    try {
      return await _recordService.hasTransactionBetween(userId1, userId2);
    } catch (e) {
      _setError('檢查用戶間交易失敗: ${e.toString()}');
      return false;
    }
  }

  // ===== 私有方法 =====

  String? _getCurrentUserId() {
    // 這裡需要從 AuthProvider 獲取當前用戶ID
    // 暫時返回 null，實際使用時需要注入 AuthProvider
    return null;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  // 重置狀態
  void reset() {
    _userTransactionRecords.clear();
    _userRatings.clear();
    _ratingStats = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
