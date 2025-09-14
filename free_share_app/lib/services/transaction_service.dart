import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../models/rating_model.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===== 原有方法保持不變 =====

  // 創建交易請求
  Future<String> createTransaction({
    required String itemId,
    required String giverId,
    required String receiverId,
    String? meetingLocation,
    DateTime? meetingTime,
    String? notes,
  }) async {
    try {
      QuerySnapshot existingQuery = await _firestore
          .collection('transactions')
          .where('itemId', isEqualTo: itemId)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', whereIn: ['pending', 'confirmed'])
          .get();

      if (existingQuery.docs.isNotEmpty) {
        throw Exception('該物品已有進行中的交易請求');
      }

      TransactionModel transaction = TransactionModel(
        id: '',
        itemId: itemId,
        giverId: giverId,
        receiverId: receiverId,
        status: TransactionStatus.pending,
        createdAt: DateTime.now(),
        meetingLocation: meetingLocation,
        meetingTime: meetingTime,
        notes: notes,
      );

      DocumentReference docRef = await _firestore
          .collection('transactions')
          .add(transaction.toFirestore());

      print('交易創建成功: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('創建交易失敗: $e');
      rethrow;
    }
  }

  // 更新交易狀態
  Future<void> updateTransactionStatus(
    String transactionId,
    TransactionStatus status,
    String currentUserId,
  ) async {
    try {
      TransactionModel? transaction = await getTransaction(transactionId);
      if (transaction == null) {
        throw Exception('交易不存在');
      }

      if (status == TransactionStatus.confirmed) {
        if (currentUserId != transaction.giverId) {
          throw Exception('只有分享者可以確認交易');
        }
      } else if (status == TransactionStatus.cancelled) {
        if (currentUserId != transaction.giverId && currentUserId != transaction.receiverId) {
          throw Exception('您沒有權限取消此交易');
        }
      } else if (status == TransactionStatus.completed) {
        if (currentUserId != transaction.giverId && currentUserId != transaction.receiverId) {
          throw Exception('您沒有權限完成此交易');
        }
      }

      Map<String, dynamic> updateData = {
        'status': status.toString().split('.').last,
      };

      if (status == TransactionStatus.completed) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection('transactions')
          .doc(transactionId)
          .update(updateData);

      print('交易狀態更新成功: $status');
    } catch (e) {
      print('更新交易狀態失敗: $e');
      rethrow;
    }
  }

  // 獲取用戶的交易記錄
  Future<List<TransactionModel>> getUserTransactions(String userId) async {
    try {
      QuerySnapshot giverQuery = await _firestore
          .collection('transactions')
          .where('giverId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      QuerySnapshot receiverQuery = await _firestore
          .collection('transactions')
          .where('receiverId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      List<TransactionModel> transactions = [];
      
      for (var doc in giverQuery.docs) {
        transactions.add(TransactionModel.fromFirestore(doc));
      }
      
      for (var doc in receiverQuery.docs) {
        transactions.add(TransactionModel.fromFirestore(doc));
      }

      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return transactions;
    } catch (e) {
      print('獲取交易記錄失敗: $e');
      return [];
    }
  }

  // 獲取物品的交易記錄
  Future<List<TransactionModel>> getItemTransactions(String itemId) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('transactions')
          .where('itemId', isEqualTo: itemId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('獲取物品交易記錄失敗: $e');
      return [];
    }
  }

  // 獲取單個交易
  Future<TransactionModel?> getTransaction(String transactionId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('transactions')
          .doc(transactionId)
          .get();

      if (doc.exists) {
        return TransactionModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('獲取交易詳情失敗: $e');
      return null;
    }
  }

  // 創建評價（原版本，基於 transactionId）
  Future<String> createRating({
    required String raterId,
    required String ratedUserId,
    required String transactionId,
    required String itemId,
    required int rating,
    String? comment,
  }) async {
    try {
      QuerySnapshot existingQuery = await _firestore
          .collection('ratings')
          .where('raterId', isEqualTo: raterId)
          .where('transactionId', isEqualTo: transactionId)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        throw Exception('您已經評價過這次交易了');
      }

      RatingModel ratingModel = RatingModel(
        id: '',
        raterId: raterId,
        ratedUserId: ratedUserId,
        transactionId: transactionId,
        itemId: itemId,
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
      );

      DocumentReference docRef = await _firestore
          .collection('ratings')
          .add(ratingModel.toFirestore());

      await _updateUserRatingStats(ratedUserId);

      print('評價創建成功: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('創建評價失敗: $e');
      rethrow;
    }
  }

  // ===== 新增：增強的評價功能 =====

  // 檢查是否可以評價物品
  Future<bool> canRateItem(String raterId, String itemId) async {
    try {
      var ratingQuery = await _firestore
          .collection('ratings')
          .where('raterId', isEqualTo: raterId)
          .where('itemId', isEqualTo: itemId)
          .get();

      return ratingQuery.docs.isEmpty;
    } catch (e) {
      print('檢查評價權限失敗: $e');
      return false;
    }
  }

  // 獲取用戶對特定物品的評價
  Future<RatingModel?> getUserRatingForItem(String raterId, String itemId) async {
    try {
      var ratingQuery = await _firestore
          .collection('ratings')
          .where('raterId', isEqualTo: raterId)
          .where('itemId', isEqualTo: itemId)
          .limit(1)
          .get();

      if (ratingQuery.docs.isNotEmpty) {
        return RatingModel.fromFirestore(ratingQuery.docs.first);
      }
      return null;
    } catch (e) {
      print('獲取用戶評價失敗: $e');
      return null;
    }
  }

  // 獲取兩個用戶之間關於特定物品的所有評價
  Future<Map<String, RatingModel?>> getRatingsBetweenUsers(String user1Id, String user2Id, String itemId) async {
    try {
      // 查詢 user1 對 user2 的評價
      var rating1Query = await _firestore
          .collection('ratings')
          .where('raterId', isEqualTo: user1Id)
          .where('ratedUserId', isEqualTo: user2Id)
          .where('itemId', isEqualTo: itemId)
          .limit(1)
          .get();

      // 查詢 user2 對 user1 的評價
      var rating2Query = await _firestore
          .collection('ratings')
          .where('raterId', isEqualTo: user2Id)
          .where('ratedUserId', isEqualTo: user1Id)
          .where('itemId', isEqualTo: itemId)
          .limit(1)
          .get();

      return {
        user1Id: rating1Query.docs.isNotEmpty 
            ? RatingModel.fromFirestore(rating1Query.docs.first) 
            : null,
        user2Id: rating2Query.docs.isNotEmpty 
            ? RatingModel.fromFirestore(rating2Query.docs.first) 
            : null,
      };
    } catch (e) {
      print('獲取雙方評價失敗: $e');
      return {user1Id: null, user2Id: null};
    }
  }

  // 根據物品創建評價
  Future<String> createRatingByItem({
    required String raterId,
    required String ratedUserId,
    required String itemId,
    required int rating,
    String? comment,
  }) async {
    try {
      bool canRate = await canRateItem(raterId, itemId);
      if (!canRate) {
        throw Exception('您已經評價過此物品');
      }

      String ratingId = _firestore.collection('ratings').doc().id;

      await _firestore.collection('ratings').doc(ratingId).set({
        'id': ratingId,
        'raterId': raterId,
        'ratedUserId': ratedUserId,
        'itemId': itemId,
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _updateUserRatingStats(ratedUserId);

      print('基於物品的評價創建成功: $ratingId');
      return ratingId;
    } catch (e) {
      print('創建評價失敗: $e');
      rethrow;
    }
  }

  // 更新基於物品的評價
  Future<bool> updateRatingByItem({
    required String raterId,
    required String itemId,
    required int rating,
    String? comment,
  }) async {
    try {
      // 查找現有評價
      var ratingQuery = await _firestore
          .collection('ratings')
          .where('raterId', isEqualTo: raterId)
          .where('itemId', isEqualTo: itemId)
          .limit(1)
          .get();

      if (ratingQuery.docs.isEmpty) {
        throw Exception('找不到要更新的評價');
      }

      String ratingId = ratingQuery.docs.first.id;
      String ratedUserId = ratingQuery.docs.first.data()['ratedUserId'];

      // 更新評價
      await _firestore.collection('ratings').doc(ratingId).update({
        'rating': rating,
        'comment': comment,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 重新計算被評價用戶的統計
      await _updateUserRatingStats(ratedUserId);

      print('評價更新成功: $ratingId');
      return true;
    } catch (e) {
      print('更新評價失敗: $e');
      return false;
    }
  }

  // 刪除基於物品的評價
  Future<bool> deleteRatingByItem(String raterId, String itemId) async {
    try {
      var ratingQuery = await _firestore
          .collection('ratings')
          .where('raterId', isEqualTo: raterId)
          .where('itemId', isEqualTo: itemId)
          .limit(1)
          .get();

      if (ratingQuery.docs.isEmpty) {
        throw Exception('找不到要刪除的評價');
      }

      String ratingId = ratingQuery.docs.first.id;
      String ratedUserId = ratingQuery.docs.first.data()['ratedUserId'];

      await _firestore.collection('ratings').doc(ratingId).delete();

      // 重新計算被評價用戶的統計
      await _updateUserRatingStats(ratedUserId);

      print('評價刪除成功: $ratingId');
      return true;
    } catch (e) {
      print('刪除評價失敗: $e');
      return false;
    }
  }

  // ===== 其他原有方法保持不變 =====

  // 獲取用戶收到的評價
  Future<List<RatingModel>> getUserRatings(String userId) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('ratings')
          .where('ratedUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs
          .map((doc) => RatingModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('獲取用戶評價失敗: $e');
      return [];
    }
  }

  // 獲取用戶評價統計
  Future<UserRatingStats> getUserRatingStats(String userId) async {
    try {
      List<RatingModel> ratings = await getUserRatings(userId);
      return UserRatingStats.fromRatings(ratings);
    } catch (e) {
      print('獲取評價統計失敗: $e');
      return UserRatingStats.fromRatings([]);
    }
  }

  // 檢查是否可以評價（基於 transactionId）
  Future<bool> canRate(String raterId, String transactionId) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('ratings')
          .where('raterId', isEqualTo: raterId)
          .where('transactionId', isEqualTo: transactionId)
          .get();

      return query.docs.isEmpty;
    } catch (e) {
      print('檢查評價權限失敗: $e');
      return false;
    }
  }

  // 更新用戶評分統計（私有方法）
  Future<void> _updateUserRatingStats(String userId) async {
    try {
      UserRatingStats stats = await getUserRatingStats(userId);
      
      await _firestore.collection('users').doc(userId).update({
        'rating': {
          'averageRating': stats.averageRating,
          'totalRatings': stats.totalRatings,
          'positiveCount': stats.positiveCount,
          'negativeCount': stats.negativeCount,
        }
      });
    } catch (e) {
      print('更新用戶評分統計失敗: $e');
    }
  }

  // 監聽交易狀態變化
  Stream<List<TransactionModel>> watchUserTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('participants', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList());
  }
}
