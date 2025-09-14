import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/item_provider.dart';
import '../../models/item_model.dart';
import '../../models/user_model.dart';
import 'edit_item_screen.dart';

class MyItemsScreen extends StatefulWidget {
  @override
  _MyItemsScreenState createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  String _selectedFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUserItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserItems() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);
    print('=== Debug: _loadUserItems ===');
    print('authProvider.currentUser: ${authProvider.currentUser}');
    print('authProvider.currentUser?.uid: ${authProvider.currentUser?.uid}');
    print('authProvider.currentUser?.email: ${authProvider.currentUser?.email}');
    print('authProvider.isAuthenticated: ${authProvider.isAuthenticated}');
    print('authProvider.userData: ${authProvider.userData}');
    
    if (authProvider.currentUser != null) {
      String userId = authProvider.currentUser!.uid;
      print('使用 userId: $userId 載入物品');
      await itemProvider.loadUserItems(userId);
      print('載入完成，物品數量：${itemProvider.userItems.length}');
    } else {
      print('ERROR: currentUser 為 null');
    }
  }

  // 狀態顯示方法 - 更新為支援新的狀態系統
  String _getStatusText(ItemStatus status) {
    switch (status) {
      case ItemStatus.available:
        return '可領取';
      case ItemStatus.offline:
        return '已下架';
      case ItemStatus.reserved:
        return '預約中';
      case ItemStatus.completed:
        return '已完成';
      case ItemStatus.banned:
        return '禁上架';
    }
  }

  Color _getStatusColor(ItemStatus status) {
    switch (status) {
      case ItemStatus.available:
        return Colors.green;
      case ItemStatus.offline:
        return Colors.grey;
      case ItemStatus.reserved:
        return Colors.orange;
      case ItemStatus.completed:
        return Colors.blue;
      case ItemStatus.banned:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    try {
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
    } catch (e) {
      return dateTime.toString();
    }
  }

  // 物品操作選單 - 更新為使用新的操作系統
  void _showItemOptions(ItemModel item) {
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;
    if (currentUserId == null) return;
    
    final availableActions = item.getAvailableActions(currentUserId);
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),
            Text(
              '物品管理',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            // 查看詳情（總是可用）
            ListTile(
              leading: Icon(Icons.info, color: Colors.green),
              title: Text('查看詳情'),
              onTap: () {
                Navigator.pop(context);
                _showItemDetail(item);
              },
            ),
            
            // 根據可用操作動態生成選項
            ...availableActions.map((action) => _buildActionListTile(item, action)),
            
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // 根據操作類型建立 ListTile
  Widget _buildActionListTile(ItemModel item, ItemAction action) {
    switch (action) {
      case ItemAction.putOnline:
        return ListTile(
          leading: Icon(Icons.visibility, color: Colors.green),
          title: Text('重新上架'),
          onTap: () {
            Navigator.pop(context);
            _putItemOnline(item);
          },
        );
      
      case ItemAction.takeOffline:
        return ListTile(
          leading: Icon(Icons.visibility_off, color: Colors.orange),
          title: Text('暫時下架'),
          onTap: () {
            Navigator.pop(context);
            _takeItemOffline(item);
          },
        );
      
      case ItemAction.markCompleted:
        return ListTile(
          leading: Icon(Icons.check_circle, color: Colors.blue),
          title: Text('標記為完成'),
          onTap: () {
            Navigator.pop(context);
            _markAsCompleted(item);
          },
        );
      
      case ItemAction.delete:
        return ListTile(
          leading: Icon(Icons.delete, color: Colors.red),
          title: Text('刪除物品'),
          onTap: () {
            Navigator.pop(context);
            _confirmDelete(item);
          },
        );
      
      default:
        return SizedBox.shrink();
    }
  }

  // 物品操作方法 - 更新為使用新的方法
  Future<void> _putItemOnline(ItemModel item) async {
    try {
      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      await itemProvider.putItemOnline(item.id);
      await _loadUserItems();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已重新上架')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失敗：${e.toString()}')),
      );
    }
  }

  Future<void> _takeItemOffline(ItemModel item) async {
    try {
      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      await itemProvider.takeItemOffline(item.id);
      await _loadUserItems();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已暫時下架')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失敗：${e.toString()}')),
      );
    }
  }

  Future<void> _markAsCompleted(ItemModel item) async {
    try {
      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      await itemProvider.markItemCompleted(item.id);
      await _loadUserItems();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已標記為完成')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失敗：${e.toString()}')),
      );
    }
  }

  void _showRatingDialog(ItemModel item) {
    // 導航到評價頁面
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;
    if (currentUserId == null) return;
    // 檢查條件
    if (item.status != ItemStatus.completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('只有已完成的物品才能評價')),
      );
      return;
    }
    if (item.reservedByUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('此物品沒有接收者')),
      );
      return;
    }

    //評價對象
    String otherUserId;
    if (item.ownerId == currentUserId) {
      otherUserId = item.reservedByUserId!;
    } else if (item.reservedByUserId == currentUserId) {
      otherUserId = item.ownerId;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('您沒有權限評價此交易')),
      );
      return;
    }

    context.push(
      '/rating/${item.id}',
      extra: {
        'otherUserId': otherUserId,
        'otherUserName': '用戶',
        'itemTitle': item.tag,
      },
    );
  }

  void _confirmDelete(ItemModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('確認刪除'),
        content: Text('確定要刪除這個物品嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(item);
            },
            child: Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(ItemModel item) async {
    try {
      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      await itemProvider.deleteItem(item.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('物品已刪除')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除失敗：${e.toString()}')),
      );
    }
  }

  // 詳情顯示
  void _showItemDetail(ItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: item.imageUrls.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(item.imageUrls.first),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: Colors.grey[300],
                          ),
                          child: item.imageUrls.isEmpty
                              ? Icon(Icons.image, color: Colors.grey[600])
                              : null,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.tag,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(item.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getStatusColor(item.status),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _getStatusText(item.status),
                                  style: TextStyle(
                                    color: _getStatusColor(item.status),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              SizedBox(height: 4),
                              Text(
                                '發布時間：${_formatDateTime(item.createdAt)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              if (item.reservedByUserId != null) ...[
                                SizedBox(height: 4),
                                Text(
                                  '預約時間：${item.reservedAt != null ? _formatDateTime(item.reservedAt!) : "未知"}',
                                  style: TextStyle(
                                    color: Colors.orange[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              if (item.completedAt != null) ...[
                                SizedBox(height: 4),
                                Text(
                                  '完成時間：${_formatDateTime(item.completedAt!)}',
                                  style: TextStyle(
                                    color: Colors.blue[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    // 顯示對方用戶資訊（預約中和已完成狀態）
                    if ((item.status == ItemStatus.reserved || item.status == ItemStatus.completed)
                        && item.reservedByUserId != null) ...[
                      SizedBox(height: 16),
                      Divider(),
                      SizedBox(height: 8),
                      Text(
                        item.status == ItemStatus.reserved ? '預約者資訊' : '接收者資訊',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      FutureBuilder<UserModel?>(
                        future: Provider.of<AuthProvider>(context, listen: false)
                            .getUserById(item.reservedByUserId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  CircularProgressIndicator(strokeWidth: 2),
                                  SizedBox(width: 12),
                                  Text('載入用戶資料中...'),
                                ],
                              ),
                            );
                          }
                    
                          if (snapshot.hasError || !snapshot.hasData) {
                            return Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Text('無法載入用戶資料'),
                            );
                          }
                    
                          final user = snapshot.data!;
                          return Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: user.avatarUrl != null
                                      ? NetworkImage(user.avatarUrl!)
                                      : null,
                                  child: user.avatarUrl == null
                                      ? Icon(Icons.person, size: 20)
                                      : null,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.username.isNotEmpty
                                            ? user.username
                                            : user.email.split('@')[0],
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.star, size: 14, color: Colors.amber),
                                          SizedBox(width: 4),
                                          Text(
                                            '${user.rating.averageRating.toStringAsFixed(1)} (${user.rating.totalRatings}次)',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    
                    SizedBox(height: 16),
                    
                    Text(
                      '物品描述',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    if (item.imageUrls.length > 1) ...[
                      Text(
                        '所有圖片',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: item.imageUrls.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 150,
                              height: 150,
                              margin: EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(item.imageUrls[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 過濾物品 - 更新為使用新的狀態系統
  List<ItemModel> _getFilteredItems() {
    final itemProvider = Provider.of<ItemProvider>(context);
    List<ItemModel> items;
    
    // 使用新的過濾方法
    switch (_selectedFilter) {
      case 'all':
        items = itemProvider.userItems;
        break;
      case 'available':
        items = itemProvider.filterUserItemsByStatus(ItemStatus.available);
        break;
      case 'offline':
        items = itemProvider.filterUserItemsByStatus(ItemStatus.offline);
        break;
      case 'reserved':
        items = itemProvider.filterUserItemsByStatus(ItemStatus.reserved);
        break;
      case 'completed':
        items = itemProvider.filterUserItemsByStatus(ItemStatus.completed);
        break;
      case 'banned':
        items = itemProvider.filterUserItemsByStatus(ItemStatus.banned);
        break;
      default:
        items = itemProvider.userItems;
    }
    
    if (_searchQuery.isNotEmpty) {
      items = items.where((item) {
        return item.tag.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               item.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('我的物品'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadUserItems,
          ),
        ],
      ),
      body: Consumer<ItemProvider>(
        builder: (context, itemProvider, child) {
          if (itemProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在載入...'),
                ],
              ),
            );
          }

          if (itemProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text('載入失敗'),
                  SizedBox(height: 8),
                  Text(
                    itemProvider.error!,
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadUserItems,
                    child: Text('重試'),
                  ),
                ],
              ),
            );
          }

          if (itemProvider.userItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2, color: Colors.grey[400], size: 64),
                  SizedBox(height: 16),
                  Text(
                    '您還沒有上架任何物品',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/add-item'),
                    child: Text('開始分享物品'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final filteredItems = _getFilteredItems();

          return Column(
            children: [
              // 搜尋和過濾區域
              Container(
                color: Colors.white,
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '搜尋物品...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', '全部'),
                          SizedBox(width: 8),
                          _buildFilterChip('available', '可領取'),
                          SizedBox(width: 8),
                          _buildFilterChip('offline', '已下架'),
                          SizedBox(width: 8),
                          _buildFilterChip('reserved', '預約中'),
                          SizedBox(width: 8),
                          _buildFilterChip('completed', '已完成'),
                          SizedBox(width: 8),
                          _buildFilterChip('banned', '禁上架'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 物品列表
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, color: Colors.grey[400], size: 48),
                            SizedBox(height: 16),
                            Text(
                              '沒有找到符合條件的物品',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUserItems,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return Container(
                              margin: EdgeInsets.only(bottom: 12),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () => _showItemOptions(item),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            image: item.imageUrls.isNotEmpty
                                                ? DecorationImage(
                                                    image: NetworkImage(item.imageUrls.first),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                            color: Colors.grey[300],
                                          ),
                                          child: item.imageUrls.isEmpty
                                              ? Icon(Icons.image, color: Colors.grey[600])
                                              : null,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      item.tag,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: _getStatusColor(item.status).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: _getStatusColor(item.status),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      _getStatusText(item.status),
                                                      style: TextStyle(
                                                        color: _getStatusColor(item.status),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                item.description,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 13,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    _formatDateTime(item.createdAt),
                                                    style: TextStyle(
                                                      color: Colors.grey[500],
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  if (item.reportCount > 0) ...[
                                                    SizedBox(width: 8),
                                                    Icon(Icons.flag, size: 12, color: Colors.orange),
                                                    SizedBox(width: 2),
                                                    Text(
                                                      '${item.reportCount}',
                                                      style: TextStyle(
                                                        color: Colors.orange,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                  // 更新：移除 isAvailable 檢查，改用狀態顯示
                                                  if (item.status == ItemStatus.offline) ...[
                                                    SizedBox(width: 8),
                                                    Icon(Icons.visibility_off, size: 12, color: Colors.grey),
                                                    SizedBox(width: 2),
                                                    Text(
                                                      '已下架',
                                                      style: TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                  if (item.status == ItemStatus.reserved) ...[
                                                    SizedBox(width: 8),
                                                    Icon(Icons.book_online, size: 12, color: Colors.orange),
                                                    SizedBox(width: 2),
                                                    Text(
                                                      '預約中',
                                                      style: TextStyle(
                                                        color: Colors.orange,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.more_vert, color: Colors.grey[400]),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/add-item'),
        backgroundColor: Colors.green,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    bool isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: Colors.green[200],
      checkmarkColor: Colors.green[700],
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.green : Colors.grey[300]!,
        ),
      ),
    );
  }
}
