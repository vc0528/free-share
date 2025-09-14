import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_model.dart';
import '../models/item_model.dart';


class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ChatRoomModel>> getUserChatRooms(String userId) async {
    try {
      // 1. 先查詢所有聊天室
      QuerySnapshot chatQuery = await _firestore
          .collection('chatRooms')
          .where('participants', arrayContains: userId)
          .orderBy('createdAt', descending: true)
          .get();
  
      List<ChatRoomModel> allChatRooms = chatQuery.docs
          .map((doc) => ChatRoomModel.fromFirestore(doc))
          .toList();
  
      // 2. 收集所有非空的 itemId
      List<String> itemIds = allChatRooms
          .where((room) => room.itemId.isNotEmpty)
          .map((room) => room.itemId)
          .toSet()
          .toList();
  
      // 3. 批次查詢物品狀態
      Map<String, String> itemStatuses = {};
      if (itemIds.isNotEmpty) {
        // Firebase 限制 in 查詢最多10個，需要分批
        for (int i = 0; i < itemIds.length; i += 10) {
          List<String> batch = itemIds.sublist(
            i, 
            (i + 10 < itemIds.length) ? i + 10 : itemIds.length
          );
          
          QuerySnapshot itemQuery = await _firestore
              .collection('items')
              .where(FieldPath.documentId, whereIn: batch)
              .get();
          
          for (var doc in itemQuery.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            itemStatuses[doc.id] = data['status'] ?? 'available';
          }
        }
      }
  
      // 4. 過濾聊天室
      List<ChatRoomModel> activeChatRooms = allChatRooms.where((chatRoom) {
        if (chatRoom.itemId.isEmpty) return true;
        String status = itemStatuses[chatRoom.itemId] ?? 'available';
        return status != 'completed';
      }).toList();
  
      print('ChatService: 過濾後剩餘 ${activeChatRooms.length} 個活躍聊天室');
      return activeChatRooms;
  
    } catch (e) {
      print('Error getting chat rooms: $e');
      return [];
    }
  }

  Future<String?> createOrGetChatRoom(
      String currentUserId, String otherUserId, String itemId) async {
    try {
      // 檢查是否已存在聊天室
      QuerySnapshot existing = await _firestore
          .collection('chatRooms')
          .where('participants', isEqualTo: [currentUserId, otherUserId])
          .where('itemId', isEqualTo: itemId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return existing.docs.first.id;
      }

      // 檢查反向參與者順序
      QuerySnapshot existingReverse = await _firestore
          .collection('chatRooms')
          .where('participants', isEqualTo: [otherUserId, currentUserId])
          .where('itemId', isEqualTo: itemId)
          .limit(1)
          .get();

      if (existingReverse.docs.isNotEmpty) {
        return existingReverse.docs.first.id;
      }

      // 創建新聊天室
      String chatRoomId = Uuid().v4();
      ChatRoomModel newChatRoom = ChatRoomModel(
        id: chatRoomId,
        participants: [currentUserId, otherUserId],
        itemId: itemId,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .set(newChatRoom.toFirestore());

      return chatRoomId;
    } catch (e) {
      print('Error creating chat room: $e');
      return null;
    }
  }

  Future<void> sendMessage(String chatRoomId, String senderId, String text) async {
    try {
      String messageId = Uuid().v4();
      MessageModel message = MessageModel(
        id: messageId,
        text: text,
        senderId: senderId,
        timestamp: DateTime.now(),
        type: 'text',
      );

      // 添加消息
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .doc(messageId)
          .set(message.toFirestore());

      // 更新聊天室的最後消息
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': {
          'text': text,
          'senderId': senderId,
          'timestamp': Timestamp.now(),
        },
      });
    } catch (e) {
      print('Error sending message: $e');
      throw e;
    }
  }

  Stream<List<MessageModel>> getMessagesStream(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
    });
  }
}
