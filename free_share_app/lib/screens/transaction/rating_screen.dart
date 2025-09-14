import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/item_provider.dart';
import '../../models/item_model.dart';
import '../../models/rating_model.dart';

class RatingScreen extends StatefulWidget {
  final String itemId;
  final String otherUserId;
  final String otherUserName;
  final String itemTitle;

  RatingScreen({
    required this.itemId,
    required this.otherUserId,
    required this.otherUserName,
    required this.itemTitle,
  });

  @override
  _RatingScreenState createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoading = true;
  ItemModel? _item;
  RatingModel? _existingRating;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await _loadItemDetails();
      await _loadExistingRating();
    } catch (e) {
      print('載入資料失敗: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadItemDetails() async {
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);
    _item = await itemProvider.getItemById(widget.itemId);
  }

  Future<void> _loadExistingRating() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.uid;
    
    if (currentUserId != null) {
      _existingRating = await transactionProvider.getUserRatingForItem(currentUserId, widget.itemId);
      
      if (_existingRating != null) {
        _isEditMode = true;
        _rating = _existingRating!.rating;
        _commentController.text = _existingRating!.comment ?? '';
      }
    }
  }

  Future<void> _submitRating() async {
    if (_isSubmitting) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.uid;
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    
    if (currentUserId == widget.otherUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('不能評價自己')),
      );
      return;
    }

    if (currentUserId == null || _item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交評價失敗：用戶信息或物品信息缺失')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      String? result;
      
      if (_isEditMode) {
        bool success = await transactionProvider.updateRatingByItem(
          raterId: currentUserId,
          itemId: widget.itemId,
          rating: _rating,
          comment: _commentController.text.trim().isEmpty 
              ? null 
              : _commentController.text.trim(),
        );
        
        if (success) {
          result = 'update_success';
        }
      } else {
        result = await transactionProvider.createRatingByItem(
          raterId: currentUserId,
          ratedUserId: widget.otherUserId,
          itemId: widget.itemId,
          rating: _rating,
          comment: _commentController.text.trim().isEmpty 
              ? null 
              : _commentController.text.trim(),
        );
      }

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? '評價修改成功' : '評價提交成功'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_isEditMode ? "修改" : "提交"}評價失敗: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('刪除評價'),
        content: Text('確定要刪除這個評價嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRating();
            },
            child: Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRating() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.uid;
    
    if (currentUserId == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      bool success = await transactionProvider.deleteRatingByItem(currentUserId, widget.itemId);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('評價已刪除'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('刪除評價失敗: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String get _ratingText {
    switch (_rating) {
      case 5:
        return '非常滿意';
      case 4:
        return '滿意';
      case 3:
        return '普通';
      case 2:
        return '不滿意';
      case 1:
        return '非常不滿意';
      default:
        return '';
    }
  }

  String get _ratingDescription {
    switch (_rating) {
      case 5:
        return '這次交易體驗很棒！';
      case 4:
        return '交易順利，推薦這位用戶';
      case 3:
        return '交易正常完成';
      case 2:
        return '交易過程有些問題';
      case 1:
        return '交易體驗不佳';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('${_isEditMode ? "修改" : "評價"} ${widget.otherUserName}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isEditMode)
            IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: _showDeleteConfirmation,
              tooltip: '刪除評價',
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 物品信息卡片
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.handshake, color: Colors.green, size: 24),
                              SizedBox(width: 8),
                              Text(
                                '交易信息',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            '物品：${widget.itemTitle}',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '交易對象：${widget.otherUserName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (_item != null) ...[
                            SizedBox(height: 4),
                            Text(
                              '完成時間：${_item!.completedAt != null ? _formatDate(_item!.completedAt!) : "剛剛"}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // 評分區域
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            _isEditMode ? '修改評價' : '請為這次交易體驗評分',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _isEditMode 
                                ? '您可以修改之前的評價內容'
                                : '您的評價將幫助其他用戶了解這位分享者',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 24),
                          
                          // 星級評分
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _rating = index + 1;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    index < _rating ? Icons.star : Icons.star_border,
                                    color: Colors.orange,
                                    size: 40,
                                  ),
                                ),
                              );
                            }),
                          ),
                          
                          SizedBox(height: 16),
                          
                          // 評分文字描述
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _ratingText,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[700],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _ratingDescription,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // 評價內容
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '評價內容（選填）',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: '分享您的交易體驗，幫助其他用戶...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            maxLines: 4,
                            maxLength: 200,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 提交按鈕
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
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRating,
                      child: _isSubmitting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('提交中...'),
                              ],
                            )
                          : Text(
                              _isEditMode ? '更新評價' : '提交評價',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: Text(
                      '暫不評價',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
