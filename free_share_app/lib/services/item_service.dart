import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/item_model.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';

class ItemService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GeoFlutterFire _geo = GeoFlutterFire();
  static const String _transactionRecordsCollection = 'transaction_records';

  // 獲取當前用戶ID
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<String> addItem({
    required String ownerId,
    required String description,
    required String tag,
    required List<File> imageFiles,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    try {
      print('ItemService: 開始上架物品流程');
      String itemId = Uuid().v4();
      print('ItemService: 生成 itemId=$itemId');
      
      List<String> imageUrls = await _uploadImages(itemId, imageFiles);
      
      LocationData originalLocation = LocationData(
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      
      LocationData fuzzyLocation = _addRandomOffset(originalLocation);
      
      GeoFirePoint geoPoint = _geo.point(
        latitude: originalLocation.latitude,
        longitude: originalLocation.longitude,
      );
      
      ItemModel item = ItemModel(
        id: itemId,
        ownerId: ownerId,
        description: description,
        tag: tag,
        imageUrls: imageUrls,
        location: fuzzyLocation,
        originalLocation: originalLocation,
        createdAt: DateTime.now(),
        status: ItemStatus.available,
        geoHash: geoPoint.hash,
      );

      Map<String, dynamic> itemData = item.toFirestore();
      itemData['g'] = geoPoint.data;

      await _firestore
          .collection('items')
          .doc(itemId)
          .set(itemData);

      print('ItemService: 物品上架成功，開始檢查推播對象');
      
      // 物品上架後檢查推播對象
      await _checkAndNotifySubscribers(
        itemId: itemId,
        tag: tag,
        description: description,
        latitude: originalLocation.latitude,
        longitude: originalLocation.longitude,
        imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
        ownerId: ownerId,
      );

      return itemId;
    } catch (e) {
      print('ItemService: 發生錯誤=$e');
      throw e;
    }
  }

  // 檢查推播對象
  Future<void> _checkAndNotifySubscribers({
    required String itemId,
    required String tag,
    required String description,
    required double latitude,
    required double longitude,
    String? imageUrl,
    required String ownerId,
  }) async {
    try {
      print('ItemService: 開始檢查推播對象，物品: $tag');

      // 1. 查詢附近的用戶（2km範圍內）
      List<UserModel> nearbyUsers = await _getNearbyUsers(
        latitude, 
        longitude, 
        radiusKm: 2.0
      );

      print('ItemService: 找到 ${nearbyUsers.length} 個附近用戶');

      // 2. 檢查每個用戶的訂閱條件並發送通知
      int notificationCount = 0;
      List<Future<void>> notificationTasks = [];

      for (UserModel user in nearbyUsers) {
        // 排除物品擁有者
        if (user.uid == ownerId) continue;

        // 檢查是否符合通知條件
        if (_shouldNotifyUser(user, itemId, tag, description, latitude, longitude)) {
          // 找出符合的關鍵字
          List<String> matchedKeywords = user.getMatchedKeywords(tag, description);
          
          // 計算距離
          double distance = _calculateDistance(
            user.location?.latitude ?? latitude,
            user.location?.longitude ?? longitude,
            latitude,
            longitude,
          );

          // 創建並發送通知
          notificationTasks.add(_sendNotificationToUser(
            user: user,
            itemId: itemId,
            itemTitle: tag,
            itemDescription: description,
            matchedKeywords: matchedKeywords,
            distance: distance,
            imageUrl: imageUrl,
          ));
          
          notificationCount++;
        }
      }

      // 3. 等待所有通知發送完成
      if (notificationTasks.isNotEmpty) {
        await Future.wait(notificationTasks);
      }
      
      print('ItemService: 推播檢查完成，發送了 $notificationCount 個通知');

    } catch (e) {
      print('ItemService: 推播檢查失敗: $e');
      // 推播失敗不應該影響物品上架，所以不 rethrow
    }
  }

  // 查詢附近用戶
  Future<List<UserModel>> _getNearbyUsers(double centerLat, double centerLng, {double radiusKm = 2.0}) async {
    try {
      // 計算查詢邊界
      double latRange = radiusKm / 111.0; // 大約1度 = 111km
      double lngRange = radiusKm / (111.0 * cos(centerLat * pi / 180));

      double minLat = centerLat - latRange;
      double maxLat = centerLat + latRange;
      double minLng = centerLng - lngRange;
      double maxLng = centerLng + lngRange;

      // 查詢有位置且開啟通知的用戶
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('preferences.enableNotifications', isEqualTo: true)
          .get();

      List<UserModel> nearbyUsers = [];
      
      for (DocumentSnapshot doc in querySnapshot.docs) {
        try {
          UserModel user = UserModel.fromFirestore(doc);
          
          // 檢查是否有位置資訊
          if (user.location == null) continue;
          
          // 檢查是否在範圍內
          if (user.location!.latitude >= minLat && user.location!.latitude <= maxLat &&
              user.location!.longitude >= minLng && user.location!.longitude <= maxLng) {
            
            // 精確距離檢查
            double distance = _calculateDistance(
              centerLat, centerLng,
              user.location!.latitude, user.location!.longitude,
            );
            
            if (distance <= radiusKm) {
              nearbyUsers.add(user);
            }
          }
        } catch (e) {
          print('ItemService: 解析用戶資料失敗: $e');
          continue;
        }
      }

      return nearbyUsers;
    } catch (e) {
      print('ItemService: 查詢附近用戶失敗: $e');
      return [];
    }
  }

  // 檢查是否應該通知用戶
  bool _shouldNotifyUser(UserModel user, String itemId, String tag, String description, double itemLat, double itemLng) {
    // 基本條件檢查
    if (!user.shouldReceiveNotification(itemId, itemLat, itemLng)) {
      return false;
    }

    // 檢查關鍵字匹配
    if (!user.itemMatchesKeywords(tag, description)) {
      return false;
    }

    return true;
  }

  // 發送通知給用戶
  Future<void> _sendNotificationToUser({
    required UserModel user,
    required String itemId,
    required String itemTitle,
    required String itemDescription,
    required List<String> matchedKeywords,
    required double distance,
    String? imageUrl,
  }) async {
    try {
      // 創建通知記錄
      NotificationModel notification = NotificationModel.newItemMatch(
        userId: user.uid,
        itemId: itemId,
        itemTitle: itemTitle,
        itemDescription: itemDescription,
        matchedKeywords: matchedKeywords,
        distanceKm: distance,
        imageUrl: imageUrl,
      );

      // 保存通知記錄到 Firestore
      await _firestore.collection('notifications').add(notification.toFirestore());

      // 更新用戶的已通知物品列表
      UserModel updatedUser = user.markItemNotified(itemId);
      await _firestore.collection('users').doc(user.uid).update({
        'notifiedItemIds': updatedUser.notifiedItemIds,
      });

      print('ItemService: 已通知用戶 ${user.username}，符合關鍵字: ${matchedKeywords.join(', ')}');

    } catch (e) {
      print('ItemService: 發送通知失敗: $e');
    }
  }

  // 計算兩點間距離（公里）
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // 地球半徑（公里）
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (pi / 180);
  }

  // 位置變更推播檢查
  Future<void> checkLocationChangeNotifications(String userId, double newLat, double newLng) async {
    try {
      print('ItemService: 檢查位置變更推播');
      
      // 獲取用戶資料
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;
      
      UserModel user = UserModel.fromFirestore(userDoc);
      if (!user.preferences.enableNotifications || !user.notificationSettings.locationUpdateNotifications) {
        return;
      }

      // 獲取新位置附近的物品
      List<ItemModel> nearbyItems = await getMapVisibleItems(newLat, newLng, 2.0);
      
      // 檢查每個物品是否符合用戶的關鍵字且未通知過
      List<Future<void>> notificationTasks = [];
      
      for (ItemModel item in nearbyItems) {
        if (user.shouldReceiveNotification(item.id, item.location.latitude, item.location.longitude) &&
            user.itemMatchesKeywords(item.tag, item.description)) {
          
          List<String> matchedKeywords = user.getMatchedKeywords(item.tag, item.description);
          double distance = _calculateDistance(newLat, newLng, item.location.latitude, item.location.longitude);
          
          // 創建位置更新通知
          NotificationModel notification = NotificationModel.locationUpdate(
            userId: userId,
            itemId: item.id,
            itemTitle: item.tag,
            matchedKeywords: matchedKeywords,
            distanceKm: distance,
            imageUrl: item.imageUrls.isNotEmpty ? item.imageUrls.first : null,
          );
          
          // 發送通知
          notificationTasks.add(_sendLocationUpdateNotification(user, notification));
        }
      }
      
      if (notificationTasks.isNotEmpty) {
        await Future.wait(notificationTasks);
        print('ItemService: 位置變更推播完成，發送了 ${notificationTasks.length} 個通知');
      }
      
    } catch (e) {
      print('ItemService: 位置變更推播檢查失敗: $e');
    }
  }

  // 發送位置更新通知
  Future<void> _sendLocationUpdateNotification(UserModel user, NotificationModel notification) async {
    try {
      // 保存通知記錄
      await _firestore.collection('notifications').add(notification.toFirestore());

      // 更新用戶已通知列表
      UserModel updatedUser = user.markItemNotified(notification.itemId!);
      await _firestore.collection('users').doc(user.uid).update({
        'notifiedItemIds': updatedUser.notifiedItemIds,
      });

    } catch (e) {
      print('ItemService: 發送位置更新通知失敗: $e');
    }
  }

  LocationData _addRandomOffset(LocationData originalLocation) {
    final random = Random();
    double latOffset = (random.nextDouble() - 0.5) * 2 * (0.2 / 111);
    double lonOffset = (random.nextDouble() - 0.5) * 2 * 
        (0.2 / (111 * cos(originalLocation.latitude * pi / 180)));
    
    return LocationData(
      latitude: originalLocation.latitude + latOffset,
      longitude: originalLocation.longitude + lonOffset,
      address: originalLocation.address,
    );
  }

  Future<List<String>> _uploadImages(String itemId, List<File> imageFiles) async {
    List<String> urls = [];
    
    for (int i = 0; i < imageFiles.length; i++) {
      try {
        String fileName = '${itemId}_$i.jpg';
        Reference ref = _storage.ref().child('items/$itemId/$fileName');
        
        UploadTask uploadTask = ref.putFile(
            imageFiles[i],
            SettableMetadata(
            contentType: 'image/jpeg',
            cacheControl: 'max-age=60',
          ),
        );
        TaskSnapshot snapshot = await uploadTask;
        String url = await snapshot.ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        print('_uploadImages: 第 ${i+1} 張圖片上傳失敗: $e');
        throw e;
      }
    }
    
    return urls;
  }

  // 獲取附近的物品
  Future<List<ItemModel>> getNearbyItems(
      double latitude, double longitude, double radiusInKm) async {
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) return [];

      GeoFirePoint center = _geo.point(latitude: latitude, longitude: longitude);
      
      Stream<List<DocumentSnapshot>> stream = _geo
          .collection(collectionRef: _firestore.collection('items'))
          .within(center: center, radius: radiusInKm, field: 'g');
      
      List<DocumentSnapshot> snapshots = await stream.first;
      
      List<ItemModel> items = snapshots
          .map((doc) => ItemModel.fromFirestore(doc))
          .where((item) => item.isVisibleToUser(currentUserId))
          .toList();
      return items;

    } catch (e) {
      print('Error getting nearby items: $e');
      return [];
    }
  }

  // 獲取地圖可顯示的物品（僅有上架狀態且未被檢舉）
  Future<List<ItemModel>> getMapVisibleItems(
      double latitude, double longitude, double radiusInKm) async {
    try {
      GeoFirePoint center = _geo.point(latitude: latitude, longitude: longitude);
      
      Stream<List<DocumentSnapshot>> stream = _geo
          .collection(collectionRef: _firestore.collection('items'))
          .within(center: center, radius: radiusInKm, field: 'g');
      
      List<DocumentSnapshot> snapshots = await stream.first;
      
      List<ItemModel> items = snapshots
          .map((doc) => ItemModel.fromFirestore(doc))
          .where((item) => 
            item.status == ItemStatus.available && 
            item.status != ItemStatus.banned
          )
          .toList();
      return items;

    } catch (e) {
      print('Error getting map visible items: $e');
      return [];
    }
  }

  Future<ItemModel?> getItemById(String itemId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('items')
          .doc(itemId)
          .get();
      
      if (doc.exists) {
        return ItemModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting item by ID: $e');
      return null;
    }
  }

  Future<List<ItemModel>> getUserItems(String userId) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('items')
          .where('ownerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => ItemModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting user items: $e');
      return [];
    }
  }

  Future<List<ItemModel>> getItemsByTag(String tag, double latitude, 
      double longitude, double radiusInKm) async {
    try {
      List<ItemModel> nearbyItems = await getNearbyItems(latitude, longitude, radiusInKm);
      return nearbyItems.where((item) => item.tag == tag).toList();
    } catch (e) {
      print('Error getting items by tag: $e');
      return [];
    }
  }

  // 更新物品狀態
  Future<void> updateItemStatus(String itemId, ItemStatus status) async {
    await _firestore.collection('items').doc(itemId).update({
      'status': status.name,
    });
  }

  // 上架物品
  Future<void> putItemOnline(String itemId) async {
    try {
      await _firestore.collection('items').doc(itemId).update({
        'status': ItemStatus.available.name,
        'reservedByUserId': null,
        'reservedAt': null,
      });
    } catch (e) {
      print('Error putting item online: $e');
      throw e;
    }
  }

  // 下架物品
  Future<void> takeItemOffline(String itemId) async {
    try {
      await _firestore.collection('items').doc(itemId).update({
        'status': ItemStatus.offline.name,
        'reservedByUserId': null,
        'reservedAt': null,
      });
    } catch (e) {
      print('Error taking item offline: $e');
      throw e;
    }
  }

  // 預約物品
  Future<void> reserveItem(String itemId, String reserverUserId) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('items').doc(itemId).update({
        'status': ItemStatus.reserved.name,
        'reservedByUserId': reserverUserId,
        'reservedAt': Timestamp.fromDate(now),
      });
    } catch (e) {
      print('Error reserving item: $e');
      throw e;
    }
  }

  // 標記交易完成
  Future<void> markItemCompleted(String itemId) async {
    try {
      final now = DateTime.now();
      await _firestore.collection('items').doc(itemId).update({
        'status': ItemStatus.completed.name,
        'completedAt': Timestamp.fromDate(now),
      });
    } catch (e) {
      print('Error marking item as completed: $e');
      throw e;
    }
  }

  // 更新評價狀態
  Future<void> updateRatingStatus(String itemId, bool isOwnerRating) async {
    try {
      final updateData = isOwnerRating 
          ? {'hasOwnerRated': true}
          : {'hasReserverRated': true};
      
      await _firestore.collection('items').doc(itemId).update(updateData);
    } catch (e) {
      print('Error updating rating status: $e');
      throw e;
    }
  }

  Future<void> updateItem({
    required String itemId,
    required String description,
    required String tag,
    required List<String> existingImageUrls,
    required List<File> newImageFiles,
  }) async {
    try {
      List<String> newImageUrls = [];
      if (newImageFiles.isNotEmpty) {
        newImageUrls = await _uploadImages(itemId, newImageFiles);
      }

      List<String> allImageUrls = [...existingImageUrls, ...newImageUrls];

      Map<String, dynamic> updates = {
        'description': description,
        'tag': tag,
        'imageUrls': allImageUrls,
      };

      await _firestore.collection('items').doc(itemId).update(updates);
    } catch (e) {
      print('Error updating item: $e');
      throw e;
    }
  }

  // 刪除物品
  Future<void> deleteItem(String itemId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('items')
          .doc(itemId)
          .get();
      
      if (doc.exists) {
        ItemModel item = ItemModel.fromFirestore(doc);
        
        // 如果是交易完成狀態，先保存交易記錄
        if (item.status == ItemStatus.completed) {
          await _saveTransactionRecord(item);
        }

        // 刪除圖片
        for (String imageUrl in item.imageUrls) {
          try {
            await FirebaseStorage.instance.refFromURL(imageUrl).delete();
          } catch (e) {
            print('Error deleting image: $e');
          }
        }
        
        // 刪除物品
        await _firestore.collection('items').doc(itemId).delete();
      }
    } catch (e) {
      print('Error deleting item: $e');
      throw e;
    }
  }

  // 保存交易記錄
  Future<void> _saveTransactionRecord(ItemModel item) async {
    if (item.reservedByUserId == null) return;

    try {
      final transactionRecord = {
        'itemId': item.id,
        'itemDescription': item.description,
        'itemTag': item.tag,
        'itemImageUrls': item.imageUrls,
        'ownerId': item.ownerId,
        'reserverUserId': item.reservedByUserId,
        'transactionDate': item.completedAt ?? DateTime.now(),
        'createdAt': DateTime.now(),
      };

      await _firestore
          .collection(_transactionRecordsCollection)
          .add(transactionRecord);
    } catch (e) {
      print('Error saving transaction record: $e');
      throw e;
    }
  }

  // 獲取用戶交易記錄
  Future<List<Map<String, dynamic>>> getUserTransactionRecords(String userId) async {
    try {
      // 獲取作為物品擁有者的記錄
      QuerySnapshot ownerQuery = await _firestore
          .collection(_transactionRecordsCollection)
          .where('ownerId', isEqualTo: userId)
          .orderBy('transactionDate', descending: true)
          .get();

      List<Map<String, dynamic>> ownerRecords = ownerQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['userRole'] = 'owner';
        return data;
      }).toList();

      // 獲取作為預約者的記錄
      QuerySnapshot reserverQuery = await _firestore
          .collection(_transactionRecordsCollection)
          .where('reserverUserId', isEqualTo: userId)
          .orderBy('transactionDate', descending: true)
          .get();

      List<Map<String, dynamic>> reserverRecords = reserverQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['userRole'] = 'reserver';
        return data;
      }).toList();

      // 合併並按日期排序
      List<Map<String, dynamic>> allRecords = [...ownerRecords, ...reserverRecords];
      allRecords.sort((a, b) {
        DateTime dateA = (a['transactionDate'] as Timestamp).toDate();
        DateTime dateB = (b['transactionDate'] as Timestamp).toDate();
        return dateB.compareTo(dateA);
      });

      return allRecords;
    } catch (e) {
      print('Error getting user transaction records: $e');
      return [];
    }
  }

  // 用戶物品統計
  Future<Map<String, int>> getUserItemStats(String userId) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('items')
          .where('ownerId', isEqualTo: userId)
          .get();

      Map<String, int> stats = {
        'total': 0,
        'available': 0,
        'offline': 0,
        'reserved': 0,
        'completed': 0,
        'banned': 0,
      };

      for (var doc in query.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'available';

        stats['total'] = stats['total']! + 1;
        stats[status] = (stats[status] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Error getting user item stats: $e');
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

  // ===== 檢舉功能 =====

  /// 檢舉物品
  /// [itemId] 物品ID
  /// [reporterUid] 檢舉者UID
  /// [reason] 檢舉原因
  Future<void> reportItem(String itemId, String reporterUid, String reason) async {
    try {
      final itemDoc = _firestore.collection('items').doc(itemId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(itemDoc);
        if (!snapshot.exists) throw Exception('物品不存在');
        
        final item = ItemModel.fromFirestore(snapshot);
        
        // 檢查是否已經檢舉過
        if (item.hasUserReported(reporterUid)) {
          throw Exception('您已經檢舉過此物品');
        }
        
        // 創建新的檢舉記錄
        final newReport = ReportData(
          timestamp: DateTime.now(),
          reporterUid: reporterUid,
          reason: reason,
        );
        
        final updatedReports = [...item.reports, newReport];
        final newReportCount = updatedReports.length;
        
        // 如果檢舉數達到 3 次，自動設為 banned 狀態
        final newStatus = newReportCount >= 3 ? ItemStatus.banned : item.status;
        
        // 更新物品資料
        transaction.update(itemDoc, {
          'reports': updatedReports.map((r) => r.toMap()).toList(),
          'reportCount': newReportCount,
          'isReported': true,
          'status': newStatus.name,
        });

        print('ItemService: 檢舉成功，當前檢舉數: $newReportCount，狀態: ${newStatus.name}');
      });
    } catch (e) {
      print('ItemService: 檢舉失敗: $e');
      throw Exception('檢舉失敗: $e');
    }
  }

  /// 檢查用戶是否已檢舉某物品
  /// [itemId] 物品ID
  /// [userUid] 用戶UID
  Future<bool> hasUserReportedItem(String itemId, String userUid) async {
    try {
      final item = await getItemById(itemId);
      if (item == null) return false;
      
      return item.hasUserReported(userUid);
    } catch (e) {
      print('ItemService: 檢查檢舉狀態失敗: $e');
      return false;
    }
  }
}
