import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/item_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../models/item_model.dart';
import '../../models/transaction_model.dart';
import '../../services/transaction_record_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatRoomId;
  final String otherUserId;
  final String? itemTitle;
  final String? itemId;

  ChatRoomScreen({
    required this.chatRoomId,
    required this.otherUserId,
    this.itemTitle,
    this.itemId,
  });

  @override
  _ChatRoomScreenState createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  UserModel? _otherUserData;
  ItemModel? _itemData;
  String? _meetingLocation;

  @override
  void initState() {
    super.initState();
    _loadOtherUserData();
    _loadItemData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOtherUserData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _otherUserData = await authProvider.getUserById(widget.otherUserId);
      if (mounted) setState(() {});
    } catch (e) {
      print('載入對方用戶資料失敗: $e');
    }
  }

  Future<void> _loadItemData() async {
//    print('DEBUG: _loadItemData called, widget.itemId = ${widget.itemId}');
    
    String? itemIdToLoad = widget.itemId;
    
    // 如果沒有 itemId，嘗試從聊天室文檔獲取
    if (itemIdToLoad == null) {
//      print('DEBUG: widget.itemId is null, trying to get from chat room');
      try {
        final chatDoc = await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(widget.chatRoomId)
            .get();
        
        if (chatDoc.exists) {
          final chatData = chatDoc.data();
          itemIdToLoad = chatData?['itemId'] as String?;
//          print('DEBUG: Got itemId from chat room: $itemIdToLoad');
        }
      } catch (e) {
//        print('DEBUG: Failed to get itemId from chat room: $e');
        return;
      }
    }
    
    if (itemIdToLoad == null) {
//      print('DEBUG: No itemId available, cannot load item data');
      return;
    }
    
    try {
//      print('DEBUG: Loading item with ID: $itemIdToLoad');
      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      _itemData = await itemProvider.getItemById(itemIdToLoad);
      
//      print('DEBUG: Item loaded successfully: ${_itemData != null}');
      if (_itemData != null) {
//        print('DEBUG: Item status: ${_itemData!.status}');
//        print('DEBUG: Item owner: ${_itemData!.ownerId}');
      }
      
      if (mounted) setState(() {});
    } catch (e) {
//      print('DEBUG: Failed to load item data: $e');
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    final currentUserId = authProvider.currentUser?.uid;
    if (currentUserId == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    await chatProvider.sendMessage(
      widget.chatRoomId,
      currentUserId,
      messageText,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showReserveDialog() {
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;
    
    if (_itemData == null || currentUserId != _itemData!.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('只有物品擁有者可以進行預約操作')),
      );
      return;
    }

    if (_itemData!.status != ItemStatus.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('此物品目前無法預約')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('確認預約'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('確定要預約給 ${_otherUserData?.username ?? '對方'} 嗎？'),
            SizedBox(height: 16),
            Text(
              '物品：${_itemData!.tag}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '預約後，此物品將不再對其他用戶顯示，您可以與對方約定時間地點進行交付。',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _reserveItem();
            },
            child: Text('確認預約'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reserveItem() async {
    try {
//      print('DEBUG: 開始執行預約操作');
      final itemProvider = context.read<ItemProvider>();
      await itemProvider.reserveItem(widget.itemId!, widget.otherUserId);
      
//      print('DEBUG: 預約完成，重新載入物品資料');
      await _loadItemData();
      setState(() {}); // 強制重新構建 UI
//      print('DEBUG: UI 重新構建完成');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已成功預約給 ${_otherUserData?.username ?? '對方'}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
//      print('DEBUG: 預約失敗: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('預約失敗：${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCancelReserveDialog() {
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;
    
    if (_itemData == null || currentUserId != _itemData!.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('只有物品擁有者可以取消預約')),
      );
      return;
    }

    if (_itemData!.status != ItemStatus.reserved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('只有預約中的物品可以取消預約')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('取消預約'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('確定要取消與 ${_otherUserData?.username ?? '對方'} 的預約嗎？'),
            SizedBox(height: 16),
            Text(
              '物品：${_itemData!.tag}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '取消後，物品將重新上架，其他用戶可以看到此物品。',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('保留預約'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelReservation();
            },
            child: Text('確認取消'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelReservation() async {
    try {
//      print('DEBUG: 開始取消預約');
      final itemProvider = context.read<ItemProvider>();
      await itemProvider.putItemOnline(widget.itemId!);
      
//      print('DEBUG: 取消預約完成，重新載入物品資料');
      await _loadItemData();
      setState(() {}); // 強制重新構建 UI
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已取消預約，物品重新上架'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
//      print('DEBUG: 取消預約失敗: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('取消預約失敗：${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCompleteDialog() {
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;
    
    if (_itemData == null || currentUserId != _itemData!.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('只有物品擁有者可以標記交易完成')),
      );
      return;
    }

    if (_itemData!.status != ItemStatus.reserved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('只有預約中的物品可以標記為完成')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('確認交易完成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('確定已經完成與 ${_otherUserData?.username ?? '對方'} 的物品交付嗎？'),
            SizedBox(height: 16),
            Text(
              '物品：${_itemData!.tag}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '標記完成後，雙方都可以進行評價。',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _completeTransaction();
            },
            child: Text('確認完成'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _completeTransaction() async {
    try {
//      print('DEBUG: 開始標記交易完成');
      final itemProvider = context.read<ItemProvider>();
      final transactionProvider = context.read<TransactionProvider>(); // 添加這行
      final authProvider = context.read<AuthProvider>(); // 添加這行
  
      // 1. 標記物品完成
      await itemProvider.markItemCompleted(widget.itemId!);
  
      // 2. 創建交易記錄
      if (_itemData != null && _otherUserData != null) {
        final currentUser = authProvider.currentUser;
        final currentUserData = authProvider.userData;
  
        if (currentUser != null && currentUserData != null) {
          await transactionProvider.createTransactionRecord(
            itemId: _itemData!.id,
            tag: _itemData!.tag,
            firstImageUrl: _itemData!.imageUrls.isNotEmpty ? _itemData!.imageUrls.first : null,
            giverId: _itemData!.ownerId,
            giverName: currentUserData.username, // 物品主人的名稱
            receiverId: _itemData!.reservedByUserId!,
            receiverName: _otherUserData!.username, // 接收者名稱
            completedAt: DateTime.now(),
          );
//          print('DEBUG: 交易記錄創建成功');
        }
      }
  
//      print('DEBUG: 交易完成，重新載入物品資料');
      await _loadItemData();
      setState(() {}); // 強制重新構建 UI
  
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已標記交易完成'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
//      print('DEBUG: 標記交易完成失敗: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('操作失敗：${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildItemStatusCard() {
    if (_itemData == null) {
//      print('DEBUG: _itemData is null in _buildItemStatusCard');
      return SizedBox.shrink();
    }
    
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;
    final isOwner = currentUserId == _itemData!.ownerId;
    
//    print('DEBUG: 在 _buildItemStatusCard 中');
//    print('DEBUG: currentUserId = $currentUserId');
//    print('DEBUG: itemOwnerId = ${_itemData!.ownerId}');
//    print('DEBUG: isOwner = $isOwner');
//    print('DEBUG: item status = ${_itemData!.status}');
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (_itemData!.status) {
      case ItemStatus.available:
        statusColor = Colors.green;
        statusText = '可領取';
        statusIcon = Icons.check_circle;
        break;
      case ItemStatus.offline:
        statusColor = Colors.grey;
        statusText = '已下架';
        statusIcon = Icons.visibility_off;
        break;
      case ItemStatus.reserved:
        statusColor = Colors.orange;
        statusText = '預約中';
        statusIcon = Icons.book_online;
        break;
      case ItemStatus.completed:
        statusColor = Colors.blue;
        statusText = '已完成';
        statusIcon = Icons.check_circle_outline;
        break;
      case ItemStatus.banned:
        statusColor = Colors.red;
        statusText = '禁上架';
        statusIcon = Icons.check_circle_outline;
        break;
    }
    
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              SizedBox(width: 8),
              Text(
                '物品狀態：$statusText',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_itemData!.status == ItemStatus.reserved && _itemData!.reservedAt != null) ...[
            SizedBox(height: 4),
            Text(
              '預約時間：${_formatDateTime(_itemData!.reservedAt!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          if (_itemData!.status == ItemStatus.completed && _itemData!.completedAt != null) ...[
            SizedBox(height: 4),
            Text(
              '完成時間：${_formatDateTime(_itemData!.completedAt!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          
          // 調試信息
          /*
          SizedBox(height: 8),
          Text(
            'DEBUG: 是否為物品擁有者: $isOwner',
            style: TextStyle(fontSize: 10, color: Colors.red),
          ),
          Text(
            'DEBUG: 物品狀態: ${_itemData!.status}',
            style: TextStyle(fontSize: 10, color: Colors.red),
          ),
          Text(
            'DEBUG: 狀態比較 available: ${_itemData!.status == ItemStatus.available}',
            style: TextStyle(fontSize: 10, color: Colors.red),
          ),
          Text(
            'DEBUG: 狀態比較 reserved: ${_itemData!.status == ItemStatus.reserved}',
            style: TextStyle(fontSize: 10, color: Colors.red),
          ),
          Text(
            'DEBUG: 狀態比較 completed: ${_itemData!.status == ItemStatus.completed}',
            style: TextStyle(fontSize: 10, color: Colors.red),
          ),
          */

          if (isOwner) ...[
//            SizedBox(height: 12),
//            Text(
//              'DEBUG: 進入物品擁有者按鈕區域',
//              style: TextStyle(fontSize: 10, color: Colors.blue),
//            ),
            
            // 可領取狀態：顯示預約按鈕
            if (_itemData!.status == ItemStatus.available) ...[
//              Text(
//                'DEBUG: 顯示預約按鈕',
//                style: TextStyle(fontSize: 10, color: Colors.green),
//              ),
              Container(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showReserveDialog,
                  icon: Icon(Icons.book_online, size: 16),
                  label: Text('預約給對方'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
            
            // 預約中狀態：顯示取消預約和標記完成按鈕
            if (_itemData!.status == ItemStatus.reserved) ...[
//              Text(
//                'DEBUG: 顯示預約中按鈕組',
//                style: TextStyle(fontSize: 10, color: Colors.green),
//              ),
              Container(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showCancelReserveDialog,
                  icon: Icon(Icons.cancel, size: 16),
                  label: Text('取消預約（重新上架）'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showCompleteDialog,
                  icon: Icon(Icons.check, size: 16),
                  label: Text('確認交易完成'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            
            // 已完成狀態
/*            
            if (_itemData!.status == ItemStatus.completed) ...[
              Text(
                'DEBUG: 顯示交易完成狀態',
                style: TextStyle(fontSize: 10, color: Colors.green),
              ),
            ],
            
            // 已下架狀態
            if (_itemData!.status == ItemStatus.offline) ...[
              Text(
                'DEBUG: 顯示下架狀態',
                style: TextStyle(fontSize: 10, color: Colors.green),
              ),
            ],
          ] else ...[
            SizedBox(height: 8),
            Text(
              'DEBUG: 不是物品擁有者，無法看到操作按鈕',
              style: TextStyle(fontSize: 10, color: Colors.red),
            ),
          ],
*/
        ],
      ),
    );
  }

  void _showUserProfile() {
    if (_otherUserData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入使用者資料中...')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _otherUserData!.avatarUrl != null
                          ? NetworkImage(_otherUserData!.avatarUrl!)
                          : null,
                      child: _otherUserData!.avatarUrl == null
                          ? Icon(Icons.person, size: 50)
                          : null,
                    ),
                    SizedBox(height: 16),
                    Text(
                      _otherUserData!.username,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
//user系統id不顯示
/*                    
                    SizedBox(height: 8),
                    Text(
                      'ID: ${_otherUserData!.uid.substring(0, 8)}...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
*/                    
                    SizedBox(height: 24),
                    
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '用戶評價',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.orange, size: 20),
                              SizedBox(width: 4),
                              Text(
                                '${_otherUserData!.rating.averageRating.toStringAsFixed(1)}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(' (${_otherUserData!.rating.totalRatings} 評價)'),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text('正評: ${_otherUserData!.rating.positiveCount}'),
                          Text('負評: ${_otherUserData!.rating.negativeCount}'),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '交易記錄',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          _buildStatRow('加入時間', '${DateTime.now().difference(_otherUserData!.createdAt).inDays} 天前'),
                          _buildStatRow('分享物品', '${_otherUserData!.transactionStats.totalPosted} 次'),
                          _buildStatRow('完成交易', '${_otherUserData!.transactionStats.completedTransactions} 次'),
                          _buildStatRow('獲得物品', '${_otherUserData!.transactionStats.totalReceived} 次'),
                          if (_otherUserData!.transactionStats.lastTransactionDate != null)
                            _buildStatRow('最後交易', _formatDate(_otherUserData!.transactionStats.lastTransactionDate!)),
                        ],
                      ),
                    ),
//最近10筆記錄                    
                    SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.history, color: Colors.orange, size: 18),
                              SizedBox(width: 8),
                              Text(
                                '最近接收記錄',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[800],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: TransactionRecordService().getUserReceivedHistory(_otherUserData!.uid, limit: 10),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Container(
                                  height: 60,
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              }
                    
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '尚無接收記錄',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }
                    
                              return Container(
                                height: 160, // 固定高度，可滾動查看更多
                                child: ListView.builder(
                                  itemCount: snapshot.data!.length,
                                  itemBuilder: (context, index) {
                                    final record = snapshot.data![index];
                                    return Container(
                                      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                      margin: EdgeInsets.only(bottom: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.orange[100]!),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: Colors.orange[300],
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  record['tag'] ?? '未知物品',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '來自：${record['giverName'] ?? '未知用戶'}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            _formatDateTime(record['completedAt']),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('關閉'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} 天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} 小時前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} 分鐘前';
    } else {
      return '剛剛';
    }
  }

  String _formatTime(DateTime dateTime) {
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
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final currentUserId = authProvider.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _otherUserData != null
                ? Text(_otherUserData!.username)
                : Text('載入中...'),
            if (widget.itemTitle != null)
              Text(
                '關於：${widget.itemTitle}',
                style: TextStyle(fontSize: 12, color: Colors.grey[200]),
              ),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (_otherUserData != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'view_profile':
                    _showUserProfile();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view_profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('查看資料'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          _buildItemStatusCard(),
          
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: chatProvider.getMessagesStream(widget.chatRoomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('載入訊息時發生錯誤: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, 
                             size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          '開始對話吧！',
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
                  controller: _scrollController,
                  reverse: true,
                  padding: EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;

                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: isMe 
                            ? MainAxisAlignment.end 
                            : MainAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.green : Colors.grey[200],
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.text,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _formatTime(message.timestamp),
                                  style: TextStyle(
                                    color: isMe 
                                        ? Colors.white70 
                                        : Colors.grey[600],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '輸入訊息...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
