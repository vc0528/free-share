import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_record_model.dart';
import '../models/item_model.dart';

class TransactionRecordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 創建交易記錄（從 ItemModel 創建）
  Future<String> createFromItem({
    required ItemModel item,
    required String giverName,
    required String receiverName,
  }) async {
    try {
      // 驗證必要資料
      if (item.reservedByUserId == null) {
        throw Exception('物品沒有接收者');
      }

      TransactionRecord record = TransactionRecord.fromItem(
        itemId: item.id,
        tag: item.tag,
        firstImageUrl: item.imageUrls.isNotEmpty ? item.imageUrls.first : null,
        giverId: item.ownerId,
        giverName: giverName,
        receiverId: item.reservedByUserId!,
        receiverName: receiverName,
        completedAt: item.completedAt ?? DateTime.now(),
      );

      DocumentReference docRef = await _firestore
          .collection('transaction_records')
          .add(record.toFirestore());

      print('交易記錄創建成功: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('創建交易記錄失敗: $e');
      rethrow;
    }
  }

  // 獲取用戶的交易記錄
  Future<List<TransactionRecord>> getUserTransactionRecords(String userId) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('transaction_records')
          .where('participants', arrayContains: userId)
          .orderBy('completedAt', descending: true)
          .get();

      return query.docs
          .map((doc) => TransactionRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('獲取交易記錄失敗: $e');
      return [];
    }
  }

  // 獲取特定物品的交易記錄
  Future<TransactionRecord?> getItemTransactionRecord(String itemId) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('transaction_records')
          .where('itemId', isEqualTo: itemId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return TransactionRecord.fromFirestore(query.docs.first);
      }
      
      return null;
    } catch (e) {
      print('獲取物品交易記錄失敗: $e');
      return null;
    }
  }

  // 檢查用戶是否已評價此物品
  Future<bool> hasUserRatedItem(String userId, String itemId) async {
    try {
      TransactionRecord? record = await getItemTransactionRecord(itemId);
      if (record == null) return false;
      
      return record.hasRated(userId);
    } catch (e) {
      print('檢查評價狀態失敗: $e');
      return false;
    }
  }

  // 更新評價狀態
  Future<bool> updateRatingStatus(String itemId, String userId) async {
    try {
      // 找到交易記錄
      QuerySnapshot query = await _firestore
          .collection('transaction_records')
          .where('itemId', isEqualTo: itemId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('找不到交易記錄');
      }

      DocumentSnapshot doc = query.docs.first;
      TransactionRecord record = TransactionRecord.fromFirestore(doc);
      
      // 更新評價狀態
      TransactionRecord updatedRecord = record.markAsRated(userId);
      
      await _firestore
          .collection('transaction_records')
          .doc(doc.id)
          .update({'ratingStatus': updatedRecord.ratingStatus});

      print('評價狀態更新成功: $itemId, $userId');
      return true;
    } catch (e) {
      print('更新評價狀態失敗: $e');
      return false;
    }
  }

  // 獲取用戶交易統計
  Future<TransactionStats> getUserTransactionStats(String userId) async {
    try {
      List<TransactionRecord> records = await getUserTransactionRecords(userId);
      return TransactionStats.fromRecords(records, userId);
    } catch (e) {
      print('獲取交易統計失敗: $e');
      return TransactionStats.fromRecords([], userId);
    }
  }

  // 監聽用戶交易記錄變化
  Stream<List<TransactionRecord>> watchUserTransactionRecords(String userId) {
    return _firestore
        .collection('transaction_records')
        .where('participants', arrayContains: userId)
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionRecord.fromFirestore(doc))
            .toList());
  }

  // 檢查兩個用戶之間是否有交易記錄
  Future<bool> hasTransactionBetween(String userId1, String userId2) async {
    try {
      // 查詢方式1: userId1 給 userId2
      QuerySnapshot query1 = await _firestore
          .collection('transaction_records')
          .where('giverId', isEqualTo: userId1)
          .where('receiverId', isEqualTo: userId2)
          .limit(1)
          .get();

      if (query1.docs.isNotEmpty) return true;

      // 查詢方式2: userId2 給 userId1
      QuerySnapshot query2 = await _firestore
          .collection('transaction_records')
          .where('giverId', isEqualTo: userId2)
          .where('receiverId', isEqualTo: userId1)
          .limit(1)
          .get();

      return query2.docs.isNotEmpty;
    } catch (e) {
      print('檢查用戶間交易失敗: $e');
      return false;
    }
  }

  // 直接創建交易記錄（供 Provider 使用）
  Future<String> createTransactionRecord(TransactionRecord record) async {
    try {
      DocumentReference docRef = await _firestore
          .collection('transaction_records')
          .add(record.toFirestore());

      print('交易記錄創建成功: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('創建交易記錄失敗: $e');
      rethrow;
    }
  }

  // 獲取最近的交易記錄（用於首頁動態）
  Future<List<TransactionRecord>> getRecentTransactionRecords({int limit = 10}) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('transaction_records')
          .orderBy('completedAt', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => TransactionRecord.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('獲取最近交易記錄失敗: $e');
      return [];
    }
  }

// 獲取用戶接收記錄（用於聊天室查看對方最近10筆記錄）
  Future<List<Map<String, dynamic>>> getUserReceivedHistory(String userId, {int limit = 10}) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('transaction_records')
          .where('receiverId', isEqualTo: userId)
          .orderBy('completedAt', descending: true)
          .limit(limit)
          .get();
  
      return query.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'tag': data['tag'] ?? '未知物品',
          'completedAt': (data['completedAt'] as Timestamp).toDate(),
          'giverId': data['giverId'],
          'giverName': data['giverName'],
        };
      }).toList();
    } catch (e) {
      print('Error getting user received history: $e');
      return [];
    }
  }


}

