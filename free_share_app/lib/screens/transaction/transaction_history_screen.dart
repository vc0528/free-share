import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction_record_model.dart';
import '../../models/rating_model.dart';
import 'rating_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  @override
  _TransactionHistoryScreenState createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactionRecords();
  }

  Future<void> _loadTransactionRecords() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    
    final currentUserId = authProvider.currentUser?.uid;
    if (currentUserId != null) {
      await transactionProvider.loadUserTransactionRecords(currentUserId);
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _refreshTransactionRecords() async {
    setState(() {
      _isLoading = true;
    });
    await _loadTransactionRecords();
  }

  // 查看對方評價
  Future<void> _viewOtherUserRating(TransactionRecord record) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.uid;
    
    if (currentUserId == null) return;

    try {
      // 獲取雙方評價
      String otherUserId = record.getOtherUserId(currentUserId);
      Map<String, RatingModel?> ratings = await transactionProvider.getRatingsBetweenUsers(
        currentUserId, 
        otherUserId, 
        record.itemId
      );

      RatingModel? otherUserRating = ratings[otherUserId];
      
      if (otherUserRating == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('對方還沒有評價')),
        );
        return;
      }

      _showRatingDetailsDialog(otherUserRating, record.getOtherUserName(currentUserId));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入評價失敗: $e')),
      );
    }
  }

  // 顯示評價詳情對話框
  void _showRatingDetailsDialog(RatingModel rating, String raterName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$raterName 的評價'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 星級顯示
            Row(
              children: [
                Text('評分：', style: TextStyle(fontWeight: FontWeight.bold)),
                ...List.generate(5, (index) {
                  return Icon(
                    index < rating.rating ? Icons.star : Icons.star_border,
                    color: Colors.orange,
                    size: 20,
                  );
                }),
                SizedBox(width: 8),
                Text('${rating.rating}/5'),
              ],
            ),
            SizedBox(height: 12),
            
            // 評論內容
            if (rating.comment != null && rating.comment!.isNotEmpty) ...[
              Text('評論：', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(rating.comment!),
              ),
            ] else ...[
              Text(
                '沒有留下評論',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            
            SizedBox(height: 12),
            
            // 評價時間
            Text(
              '評價時間：${_formatDetailedDate(rating.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('關閉'),
          ),
        ],
      ),
    );
  }

  String _formatDetailedDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // 檢查是否可以評價
  Future<bool> _checkCanRate(TransactionRecord record) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.uid;
  
    if (currentUserId == null) return false;
  
    return await transactionProvider.canRateItem(currentUserId, record.itemId);
  }

  // 導航到評價頁面
  Future<void> _navigateToRating(TransactionRecord record) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.uid;
    if (currentUserId == null) return;

    // 確定評價對象
    final otherUserId = record.getOtherUserId(currentUserId);
    final otherUserName = record.getOtherUserName(currentUserId);
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RatingScreen(
          itemId: record.itemId,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          itemTitle: record.tag,
        ),
      ),
    );
    
    if (result == true) {
      _refreshTransactionRecords();
    }
  }

  // 顯示評價狀態
  Future<void> _showRatingStatus(TransactionRecord record) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('評價狀態'),
        content: Text('您已經評價過此交易。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('確定'),
          ),
        ],
      ),
    );
  }

  // 構建交易記錄項目
  Widget _buildTransactionRecordItem(TransactionRecord record) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.uid;
    
    if (currentUserId == null || !record.isParticipant(currentUserId)) {
      return SizedBox.shrink();
    }

    final isGiver = record.isGiver(currentUserId);
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 交易基本信息
            Row(
              children: [
                // 物品圖片
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: record.firstImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(record.firstImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.grey[300],
                  ),
                  child: record.firstImageUrl == null
                      ? Icon(Icons.image, color: Colors.grey[600])
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.tag,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        isGiver ? '您分享給 ${record.receiverName}' : '您從 ${record.giverName} 獲得',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                          SizedBox(width: 4),
                          Text(
                            record.formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 評價狀態指示
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: record.hasRated(currentUserId) 
                        ? Colors.green[50] 
                        : Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: record.hasRated(currentUserId) 
                          ? Colors.green 
                          : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    record.getRatingStatusText(currentUserId),
                    style: TextStyle(
                      color: record.hasRated(currentUserId) 
                          ? Colors.green[700] 
                          : Colors.orange[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // 評價按鈕區域
            Row(
              children: [
                // 主要評價按鈕
                Expanded(
                  flex: 2,
                  child: FutureBuilder<bool>(
                    future: _checkCanRate(record),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ElevatedButton(
                          onPressed: null,
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      
                      bool canRate = snapshot.data ?? false;
                      bool hasRated = record.hasRated(currentUserId);
                      
                      return ElevatedButton.icon(
                        onPressed: () => _navigateToRating(record),
                        icon: Icon(
                          hasRated ? Icons.edit : Icons.star_outline,
                          size: 18,
                        ),
                        label: Text(record.getRatingButtonText(currentUserId)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasRated ? Colors.blue : Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      );
                    },
                  ),
                ),
                
                SizedBox(width: 8),
                
                // 查看對方評價按鈕
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: record.canViewOtherUserRating(currentUserId)
                        ? () => _viewOtherUserRating(record)
                        : null,
                    child: Text(
                      record.getViewOtherRatingButtonText(currentUserId),
                      style: TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: record.canViewOtherUserRating(currentUserId)
                          ? Colors.blue
                          : Colors.grey,
                      side: BorderSide(
                        color: record.canViewOtherUserRating(currentUserId)
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 構建交易記錄列表
  Widget _buildTransactionRecordList(List<TransactionRecord> records) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              '還沒有交易記錄',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              '完成物品交易後，記錄會出現在這裡',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshTransactionRecords,
      child: ListView.builder(
        itemCount: records.length,
        itemBuilder: (context, index) {
          return _buildTransactionRecordItem(records[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('交易記錄'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshTransactionRecords,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Consumer<TransactionProvider>(
              builder: (context, transactionProvider, child) {
                final authProvider = Provider.of<AuthProvider>(context);
                final currentUserId = authProvider.currentUser?.uid;
                
                if (currentUserId == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text('請先登入'),
                      ],
                    ),
                  );
                }

                return _buildTransactionRecordList(transactionProvider.userTransactionRecords);
              },
            ),
    );
  }
}
