import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/item_provider.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../models/item_model.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }

  Future<void> _loadChatRooms() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    print('ChatList: 載入使用者聊天室');
    print('ChatList: 當前使用者ID: ${authProvider.currentUser?.uid}');
    
    if (authProvider.currentUser != null) {
      await chatProvider.loadUserChatRooms(authProvider.currentUser!.uid);
      print('ChatList: 載入完成，聊天室數量: ${chatProvider.chatRooms.length}');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小時前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分鐘前';
    } else {
      return '剛剛';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('聊天室'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (chatProvider.chatRooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, 
                       size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    '還沒有聊天記錄',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chatProvider.chatRooms.length,
            itemBuilder: (context, index) {
              final chatRoom = chatProvider.chatRooms[index];
              final authProvider = Provider.of<AuthProvider>(context);
              final currentUserId = authProvider.currentUser?.uid;
              final otherUserId = chatRoom.participants
                  .firstWhere((id) => id != currentUserId, orElse: () => '');

              print('ChatList: currentUserId = $currentUserId');
              print('ChatList: participants = ${chatRoom.participants}');
              print('ChatList: otherUserId = $otherUserId');
              print('ChatList: itemId = ${chatRoom.itemId}'); // 添加調試

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Icon(Icons.person, color: Colors.green),
                  ),
                  title: FutureBuilder<UserModel?>(
                    future: Provider.of<AuthProvider>(context, listen: false).getUserById(otherUserId),
                    builder: (context, snapshot) {
                      print('FutureBuilder: otherUserId = $otherUserId');
                      print('FutureBuilder: snapshot.data = ${snapshot.data}');

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Text('載入中...');
                      }
                      if (snapshot.hasError) {
                        print('FutureBuilder error: ${snapshot.error}');
                        return Text('載入失敗');
                      }
                      if (snapshot.hasData && snapshot.data != null) {
                        final user = snapshot.data!;
                        final displayName = user.username.isNotEmpty
                            ? user.username
                            : user.email.split('@')[0];
                        return Text(displayName);
                      }
                      return Text('未知用戶($otherUserId)');
                    },
                  ),

                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 根據 itemId 獲取物品資訊
                      FutureBuilder<ItemModel?>(
                        future: chatRoom.itemId.isNotEmpty 
                            ? Provider.of<ItemProvider>(context, listen: false).getItemById(chatRoom.itemId)
                            : Future.value(null),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            final item = snapshot.data!;
                            return Row(
                              children: [
                                // 物品縮圖
                                Container(
                                  width: 40,
                                  height: 40,
                                  margin: EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    image: item.imageUrls.isNotEmpty
                                        ? DecorationImage(
                                            image: NetworkImage(item.imageUrls.first),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    color: Colors.grey[300],
                                  ),
                                  child: item.imageUrls.isEmpty
                                      ? Icon(Icons.inventory, size: 20, color: Colors.grey[600])
                                      : null,
                                ),
                                Expanded(
                                  child: Text(
                                    '關於：${item.tag}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ),
                              ],
                            );
                          }
                          return Text(
                            chatRoom.itemId.isNotEmpty ? '關於物品' : '一般聊天',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          );
                        },
                      ),
                      if (chatRoom.lastMessage != null) ...[
                        SizedBox(height: 4),
                        Text(
                          chatRoom.lastMessage!.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),

                  trailing: chatRoom.lastMessage != null
                      ? Text(
                          _formatDateTime(chatRoom.lastMessage!.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        )
                      : null,
                  onTap: () {
                    // 獲取物品標題用於顯示
                    String itemTitle = '物品聊天';
                    Provider.of<ItemProvider>(context, listen: false)
                        .getItemById(chatRoom.itemId)
                        .then((item) {
                      if (item != null) {
                        itemTitle = item.tag;
                      }
                    }).catchError((e) {
                      print('獲取物品標題失敗: $e');
                    });

                    print('DEBUG: 聊天列表跳轉 - chatRoomId: ${chatRoom.id}, itemId: ${chatRoom.itemId}, otherUserId: $otherUserId');
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatRoomScreen(
                          chatRoomId: chatRoom.id,
                          otherUserId: otherUserId,
                          itemTitle: itemTitle,
                          itemId: chatRoom.itemId.isNotEmpty ? chatRoom.itemId : null, // 重要：傳遞 itemId
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
