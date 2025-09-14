import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/map_provider.dart';
import '../../providers/item_provider.dart';
import '../../models/item_model.dart';
import '../../models/user_model.dart';
import '../../services/item_service.dart';
import '../chat/chat_room_screen.dart';
import '../chat/chat_list_screen.dart';
import '../auth/edit_profile_screen.dart';
import '../../providers/chat_provider.dart';

class MapScreen extends StatefulWidget {
  final bool notificationMode;
  final String? highlightItemId;
  final String? notificationType;

  MapScreen({
    this.notificationMode = false,
    this.highlightItemId,
    this.notificationType,
  });

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  String? _errorMessage;
  ItemModel? _selectedItem;
  
  String _searchKeyword = '';
  bool _isSearching = false;
  
  bool _isNotificationMode = false;
  String? _highlightItemId;
  String? _notificationType;
  List<String> _notificationKeywords = [];
  
  List<String> _subscribedKeywords = [];
  
  double? _lastNotifiedLat;
  double? _lastNotifiedLng;
  
  Map<String, BitmapDescriptor> _thumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _initNotificationMode();
    _loadUserSubscriptions();
    _initializeMap();
  }

  void _initNotificationMode() {
    _isNotificationMode = widget.notificationMode;
    _highlightItemId = widget.highlightItemId;
    _notificationType = widget.notificationType;
    
    if (_isNotificationMode && _highlightItemId != null) {
      print('MapScreen: 進入通知模式 - itemId: $_highlightItemId, type: $_notificationType');
      _loadNotificationKeywords();
    }
  }

  Future<void> _loadNotificationKeywords() async {
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;
    if (currentUserId != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
        
        if (userDoc.exists) {
          UserModel user = UserModel.fromFirestore(userDoc);
          _notificationKeywords = List.from(user.subscribedKeywords);
        }
      } catch (e) {
        print('載入通知關鍵字失敗: $e');
      }
    }
  }

  Future<void> _loadUserSubscriptions() async {
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;
    if (currentUserId != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
        
        if (userDoc.exists) {
          UserModel user = UserModel.fromFirestore(userDoc);
          setState(() {
            _subscribedKeywords = List.from(user.subscribedKeywords);
          });
        }
      } catch (e) {
        print('載入用戶訂閱失敗: $e');
      }
    }
  }

  Future<void> _initializeMap() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final mapProvider = Provider.of<MapProvider>(context, listen: false);
      await mapProvider.getCurrentLocation();
      
      if (mapProvider.currentPosition != null) {
        print('Map: 當前位置 lat=${mapProvider.currentPosition!.latitude}, lng=${mapProvider.currentPosition!.longitude}');
        final itemProvider = Provider.of<ItemProvider>(context, listen: false);
        print('Map: 開始載入附近物品');
        
        await itemProvider.loadMapVisibleItems(
          mapProvider.currentPosition!.latitude,
          mapProvider.currentPosition!.longitude,
        );
        print('Map: 載入完成，物品數量=${itemProvider.nearbyItems.length}');
        
        await _checkLocationChangeNotifications(
          mapProvider.currentPosition!.latitude,
          mapProvider.currentPosition!.longitude,
        );
        
        if (mounted) {
          await _updateMarkers();
        }
      } else {
        setState(() {
          _errorMessage = '無法獲取當前位置，請檢查位置權限設定';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '載入地圖時發生錯誤：${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkLocationChangeNotifications(double newLat, double newLng) async {
    try {
      final currentUserId = context.read<AuthProvider>().currentUser?.uid;
      if (currentUserId == null) return;

      if (_lastNotifiedLat != null && _lastNotifiedLng != null) {
        double distance = _calculateDistance(
          _lastNotifiedLat!, _lastNotifiedLng!,
          newLat, newLng,
        );
        
        if (distance < 0.5) return;
      }

      final itemService = ItemService();
      await itemService.checkLocationChangeNotifications(currentUserId, newLat, newLng);
      
      await _updateUserLocation(newLat, newLng);
      
      _lastNotifiedLat = newLat;
      _lastNotifiedLng = newLng;
      
    } catch (e) {
      print('位置變化推播檢查失敗: $e');
    }
  }

  Future<void> _updateUserLocation(double lat, double lng) async {
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;
    if (currentUserId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({
          'location': {
            'latitude': lat,
            'longitude': lng,
            'lastUpdated': FieldValue.serverTimestamp(),
          }
        });
      } catch (e) {
        print('更新用戶位置失敗: $e');
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    
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

  List<ItemModel> _getFilteredItems() {
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;
    
    List<ItemModel> baseItems = itemProvider.nearbyItems.where((item) {
      return currentUserId != null && 
             item.isVisibleToUser(currentUserId) && 
             item.status == ItemStatus.available && 
             !item.isReported;
    }).toList();

    if (_isNotificationMode && _notificationKeywords.isNotEmpty) {
      return baseItems.where((item) {
        final itemText = '${item.tag} ${item.description}'.toLowerCase();
        return _notificationKeywords.any((keyword) => 
          itemText.contains(keyword.toLowerCase()));
      }).toList();
    }

    if (_isSearching && _searchKeyword.trim().isNotEmpty) {
      final keyword = _searchKeyword.toLowerCase();
      return baseItems.where((item) {
        final tagMatch = item.tag.toLowerCase().contains(keyword);
        final descriptionMatch = item.description.toLowerCase().contains(keyword);
        return tagMatch || descriptionMatch;
      }).toList();
    }

    return baseItems;
  }

  void _showKeywordSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        List<String> tempKeywords = List.from(_subscribedKeywords);
        TextEditingController keywordController = TextEditingController();
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('管理關鍵字訂閱'),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '訂閱關鍵字，當有符合條件的物品上架時會收到通知',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: keywordController,
                            decoration: InputDecoration(
                              hintText: '輸入新關鍵字...',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (value) {
                              final keyword = value.trim().toLowerCase();
                              if (keyword.isNotEmpty && !tempKeywords.contains(keyword)) {
                                setDialogState(() {
                                  tempKeywords.add(keyword);
                                });
                                keywordController.clear();
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 8),

                        // 添加關鍵字按鈕
                        IconButton(
                          onPressed: () {
                            final keyword = keywordController.text.trim().toLowerCase();
                            if (keyword.isNotEmpty && !tempKeywords.contains(keyword)) {
                              setDialogState(() {
                                tempKeywords.add(keyword);
                              });
                              keywordController.clear();
                            }
                          },
                          icon: Icon(Icons.add),
                          tooltip: '添加關鍵字',
                        ),

                        // 推薦關鍵字按鈕
                        SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            _showPopularKeywords(setDialogState, tempKeywords);
                          },
                          icon: Icon(Icons.add_circle_outline),
                          tooltip: '常用關鍵字',
                        ),

                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      height: 200,
                      child: tempKeywords.isEmpty
                          ? Center(
                              child: Text(
                                '尚未訂閱任何關鍵字\n點擊上方輸入框添加關鍵字',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: tempKeywords.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  dense: true,
                                  leading: Icon(Icons.label, color: Colors.blue),
                                  title: Text(tempKeywords[index]),
                                  trailing: IconButton(
                                    icon: Icon(Icons.remove_circle, color: Colors.red),
                                    onPressed: () {
                                      setDialogState(() {
                                        tempKeywords.removeAt(index);
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _saveKeywordSubscriptions(tempKeywords);
                    Navigator.pop(context);
                  },
                  child: Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPopularKeywords(StateSetter setDialogState, List<String> tempKeywords) {
    List<String> popularKeywords = [
      '書籍', '衣服', '家具', '電器', '玩具', '運動用品', 
      '廚具', '文具', '植物', '裝飾品', '包包', '鞋子'
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('常用關鍵字'),
        content: Wrap(
          spacing: 8,
          children: popularKeywords.map((keyword) => 
            FilterChip(
              label: Text(keyword),
              selected: tempKeywords.contains(keyword),
              onSelected: (selected) {
                if (selected && !tempKeywords.contains(keyword)) {
                  setDialogState(() {
                    tempKeywords.add(keyword);
                  });
                }
                Navigator.pop(context);
              },
            )
          ).toList(),
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

  Future<void> _saveKeywordSubscriptions(List<String> keywords) async {
    try {
      final currentUserId = context.read<AuthProvider>().currentUser?.uid;
      print('保存關鍵字: $keywords, 用戶ID: $currentUserId');

      if (currentUserId != null) {

        final KeywordsList = List<String>.from(keywords);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({
          'subscribedKeywords': KeywordsList,
        });

        print('Firestore 寫入數據: $KeywordsList');
        
        setState(() {
          _subscribedKeywords = List.from(keywords);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('關鍵字訂閱已更新')),
        );
      } else {
        print('用戶ID為空');
      }

    } catch (e) {
      print('保存失敗詳細錯誤: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失敗：${e.toString()}')),
      );
    }
  }

  void _exitNotificationMode() {
    setState(() {
      _isNotificationMode = false;
      _highlightItemId = null;
      _notificationType = null;
      _notificationKeywords.clear();
    });
    _updateMarkers();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String tempKeyword = _searchKeyword;
        return AlertDialog(
          title: Text('搜尋物品'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '輸入關鍵字搜尋標籤或描述...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  tempKeyword = value;
                },
                onSubmitted: (value) {
                  Navigator.pop(context);
                  _performSearch(value);
                },
                controller: TextEditingController(text: _searchKeyword)
                  ..selection = TextSelection.fromPosition(
                    TextPosition(offset: _searchKeyword.length),
                  ),
              ),
              if (tempKeyword.isNotEmpty) ...[
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.notifications, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '將此關鍵字加入訂閱以接收推播？',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            if (_searchKeyword.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _clearSearch();
                },
                child: Text('清除', style: TextStyle(color: Colors.red)),
              ),
            if (tempKeyword.isNotEmpty && !_subscribedKeywords.contains(tempKeyword.toLowerCase()))
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _addToSubscription(tempKeyword);
                  _performSearch(tempKeyword);
                },
                child: Text('搜尋+訂閱', style: TextStyle(color: Colors.orange)),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _performSearch(tempKeyword);
              },
              child: Text('搜尋'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addToSubscription(String keyword) async {
    final cleanKeyword = keyword.trim().toLowerCase();
    if (!_subscribedKeywords.contains(cleanKeyword)) {
      List<String> newKeywords = List.from(_subscribedKeywords)..add(cleanKeyword);
      await _saveKeywordSubscriptions(newKeywords);
    }
  }

  void _performSearch(String keyword) async {
    setState(() {
      _searchKeyword = keyword.trim();
      _isSearching = _searchKeyword.isNotEmpty;
      _isLoading = true;
    });

    try {
      await _updateMarkers();
      
      if (_isSearching) {
        final filteredItems = _getFilteredItems();
        print('搜尋結果：關鍵字="$_searchKeyword"，找到 ${filteredItems.length} 個物品');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '搜尋時發生錯誤：${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    setState(() {
      _searchKeyword = '';
      _isSearching = false;
    });
    _updateMarkers();
  }

  Future<BitmapDescriptor> _createThumbnailMarker(String imageUrl, bool isSelected, {bool isHighlighted = false}) async {
    String cacheKey = '${imageUrl}_${isSelected}_${isHighlighted}';
    if (_thumbnailCache.containsKey(cacheKey)) {
      return _thumbnailCache[cacheKey]!;
    }

    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('無法下載圖片');
      }
      
      final bytes = response.bodyBytes;
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 320,
        targetHeight: 320,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      final size = 200.0;
      final center = Offset(size / 2, size / 2);
      
      Color borderColor;
      if (isHighlighted) {
        borderColor = Colors.amber;
      } else if (isSelected) {
        borderColor = Colors.orange;
      } else {
        borderColor = Colors.green;
      }
      
      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, size / 2, borderPaint);
      
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, (size / 2) - 4, innerPaint);
      
      final clipPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: (size / 2) - 6));
      canvas.clipPath(clipPath);
      
      final imageRect = Rect.fromLTWH(6, 6, size - 12, size - 12);
      final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      canvas.drawImageRect(image, srcRect, imageRect, Paint());
      
      canvas.restore();
      final pinPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.fill;
      
      final pinPath = Path();
      pinPath.moveTo(center.dx - 8, size - 4);
      pinPath.lineTo(center.dx + 8, size - 4);
      pinPath.lineTo(center.dx, size + 10);
      pinPath.close();
      canvas.drawPath(pinPath, pinPaint);
      
      final picture = pictureRecorder.endRecording();
      final finalImage = await picture.toImage(size.toInt(), (size + 32).toInt());
      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      final uint8List = byteData!.buffer.asUint8List();
      
      final bitmapDescriptor = BitmapDescriptor.fromBytes(uint8List);
      _thumbnailCache[cacheKey] = bitmapDescriptor;
      
      return bitmapDescriptor;
    } catch (e) {
      print('創建縮圖失敗: $e');
      double hue;
      if (isHighlighted) {
        hue = BitmapDescriptor.hueYellow;
      } else if (isSelected) {
        hue = BitmapDescriptor.hueOrange;
      } else {
        hue = BitmapDescriptor.hueGreen;
      }
      
      final defaultIcon = BitmapDescriptor.defaultMarkerWithHue(hue);
      _thumbnailCache[cacheKey] = defaultIcon;
      return defaultIcon;
    }
  }

  Future<void> _updateMarkers() async {
    Set<Marker> markers = {};
    List<ItemModel> itemsToShow = _getFilteredItems();
    print('Map: 開始更新標記，物品數量=${itemsToShow.length}');
    
    for (ItemModel item in itemsToShow) {
      final isSelected = _selectedItem?.id == item.id;
      final isHighlighted = _highlightItemId == item.id;
      BitmapDescriptor icon;
      
      if (item.imageUrls.isNotEmpty) {
        icon = await _createThumbnailMarker(
          item.imageUrls.first, 
          isSelected, 
          isHighlighted: isHighlighted
        );
      } else {
        double hue;
        if (isHighlighted) {
          hue = BitmapDescriptor.hueYellow;
        } else if (isSelected) {
          hue = BitmapDescriptor.hueOrange;
        } else {
          hue = BitmapDescriptor.hueGreen;
        }
        icon = BitmapDescriptor.defaultMarkerWithHue(hue);
      }
      
      markers.add(
        Marker(
          markerId: MarkerId(item.id),
          position: LatLng(item.location.latitude, item.location.longitude),
          onTap: () => _onMarkerTapped(item),
          icon: icon,
          infoWindow: InfoWindow(
            title: item.tag,
            snippet: '點擊查看詳情',
          ),
          anchor: Offset(0.5, 1.0),
        ),
      );
    }

    print('Map: 標記創建完成，標記數量=${markers.length}');
    setState(() {
      _markers = markers;
    });
  }

  void _onMarkerTapped(ItemModel item) {
    setState(() {
      _selectedItem = item;
    });
    _updateMarkers();

    if (_mapController != null) {
      _mapController!.showMarkerInfoWindow(MarkerId(item.id));
    }

    _showItemDetail(item);
  }

  void _showItemDetail(ItemModel item) {
    final currentUserId = context.read<AuthProvider>().currentUser?.uid;
    final availableActions = currentUserId != null ? item.getAvailableActions(currentUserId) : <ItemAction>[];
    
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
                          width: 160,
                          height: 160,
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
                              Text(
                                '發佈時間：${_formatDateTime(item.createdAt)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(item.status),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getStatusText(item.status),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (_isNotificationMode && _notificationKeywords.isNotEmpty) ...[
                                SizedBox(height: 4),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    '匹配: ${_notificationKeywords.join(', ')}',
                                    style: TextStyle(
                                      color: Colors.orange[800],
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    
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
                        '更多圖片',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: item.imageUrls.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 240,
                              height: 240,
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
                      SizedBox(height: 16),
                    ],
                    
                    SizedBox(height: 24),
                    
                    if (currentUserId != item.ownerId) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _startChatWithOwner(item);
                              },
                              icon: Icon(Icons.chat),
                              label: Text('聯絡分享者'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showReportDialog(item),
                              icon: Icon(Icons.flag),
                              label: Text('檢舉'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

//過早的程式,評價和檢舉都修改過
/*
  Widget _buildActionButtons(ItemModel item, List<ItemAction> availableActions, String currentUserId) {
    List<Widget> buttons = [];
    
    if (currentUserId == item.ownerId || currentUserId == item.reservedByUserId) {
      for (ItemAction action in availableActions) {
        switch (action) {
          case ItemAction.rate:
            buttons.add(
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showRatingDialog(item),
                  icon: Icon(Icons.star),
                  label: Text('評價'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            );
            break;
          default:
            break;
        }
      }
    }
    
    if (currentUserId != item.ownerId) {
      buttons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _startChatWithOwner(item);
            },
            icon: Icon(Icons.chat),
            label: Text('聯絡分享者'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      );
    }
    
    return Row(
      children: buttons.map((button) {
        if (button != buttons.last) {
          return Row(children: [button, SizedBox(width: 12)]);
        }
        return button;
      }).toList(),
    );
  }
*/
  void _showRatingDialog(ItemModel item) {
    Navigator.pop(context);
    context.push('/rating/${item.id}');
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

  void _startChatWithOwner(ItemModel item) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.uid;
    
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('請先登入')),
      );
      return;
    }

    if (currentUserId == item.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('這是您自己的物品')),
      );
      return;
    }

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final chatRoomId = await chatProvider.createOrGetChatRoom(
        currentUserId, 
        item.ownerId,
        item.id,
      );

      if (chatRoomId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(
              chatRoomId: chatRoomId,
              otherUserId: item.ownerId,
              itemTitle: item.tag,
              itemId: item.id,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('創建聊天室失敗')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('啟動聊天失敗：${e.toString()}')),
      );
    }
  }


// 移除舊的 _showReportDialog 和 _reportItem 方法
// 替換為以下新的檢舉功能
// 在您的 map_screen.dart 中，將 _showReportDialog、_confirmReport、_submitReport 方法替換為：

  void _showReportDialog(ItemModel item) {
    Navigator.pop(context); // 關閉 BottomSheet
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser; 
    
    if (currentUser?.uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('請先登入')),
      );
      return;
    }
  
    // 檢查是否已經檢舉過
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);
    if (itemProvider.hasUserReportedItemLocally(item.id, currentUser!.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('您已經檢舉過此物品')),
      );
      return;
    }
  
    // 檢舉原因選項
    final reportReasons = [
      {'title': '有違法物品', 'subtitle': '包含違法、危險或禁止物品'},
      {'title': '涉及金錢交易', 'subtitle': '要求付費或進行商業交易'},
      {'title': '不符規定', 'subtitle': '違反平台使用條款'},
      {'title': '虛假資訊', 'subtitle': '提供不實或誤導性資訊'},
      {'title': '其他問題', 'subtitle': '其他不當行為或內容'},
    ];
  
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.flag, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('檢舉物品'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          image: item.imageUrls.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(item.imageUrls.first),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: Colors.grey[300],
                        ),
                        child: item.imageUrls.isEmpty
                            ? Icon(Icons.image, color: Colors.grey[600], size: 24)
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
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '發布時間：${_formatDateTime(item.createdAt)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 16),
                Text(
                  '請選擇檢舉原因：',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                
                // 檢舉原因列表
                Container(
                  height: 300, // 限制高度，可滾動
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: reportReasons.length,
                    itemBuilder: (context, index) {
                      final reason = reportReasons[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 2),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red[50],
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            reason['title']!,
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            reason['subtitle']!,
                            style: TextStyle(fontSize: 12),
                          ),
                          onTap: () => _confirmReport(
                            dialogContext, 
                            item, 
                            reason['title']!, 
                            currentUser
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('取消'),
            ),
          ],
        );
      },
    );
  }
  
  // 確認檢舉的對話框
  void _confirmReport(BuildContext dialogContext, ItemModel item, String reason, currentUser) {
    showDialog(
      context: dialogContext,
      builder: (BuildContext confirmContext) {
        return AlertDialog(
          title: Text('確認檢舉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('確定要檢舉此物品嗎？'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red[600], size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '檢舉原因：$reason',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.red[800],
                            ),
                          ),
                          Text(
                            '物品：${item.tag}',
                            style: TextStyle(
                              color: Colors.red[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                '我們會審核您的檢舉，如果發現違規將採取相應措施。',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(confirmContext).pop(),
              child: Text('取消'),
            ),
            Consumer<ItemProvider>(
              builder: (context, itemProvider, child) {
                return ElevatedButton(
                  onPressed: itemProvider.isReporting 
                      ? null 
                      : () => _submitReport(confirmContext, dialogContext, item, reason, currentUser),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: itemProvider.isReporting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text('確認檢舉'),
                );
              },
            ),
          ],
        );
      },
    );
  }
  
  // 提交檢舉
  Future<void> _submitReport(BuildContext confirmContext, BuildContext dialogContext, 
      ItemModel item, String reason, currentUser) async {
    try {
      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      
      if (currentUser?.uid == null) {
        throw Exception('用戶資訊不完整');
      }
  
      // 再次檢查是否已經檢舉過（遠端檢查）
      final hasReported = await itemProvider.hasUserReportedItem(item.id, currentUser!.uid);
      if (hasReported) {
        throw Exception('您已經檢舉過此物品');
      }
  
      await itemProvider.reportItem(item.id, currentUser.uid, reason);
      
      // 關閉所有對話框
      Navigator.of(confirmContext).pop();
      Navigator.of(dialogContext).pop();
      
      // 顯示成功訊息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('檢舉已提交，感謝您的回報'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
      // 更新地圖標記
      await _updateMarkers();
      
    } catch (e) {
      // 關閉確認對話框
      Navigator.of(confirmContext).pop();
      
      // 顯示錯誤訊息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('檢舉失敗: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
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

  Widget _buildPopupMenu() {
    return PopupMenuButton<String>(
      onSelected: (String result) {
        Future.microtask(() {
          switch (result) {
            case 'my_items':
              context.push('/my-items');
              break;
            case 'edit_profile':
              context.push('/edit-profile');
              break;
            case 'chat_list':
              context.push('/chat-list');
              break;
            case 'transaction_history':
              context.push('/transaction_history');
              break;
            case 'keyword_subscription':
              _showKeywordSubscriptionDialog();
              break;
            case 'logout':
              _logout();
              break;
          }
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'my_items',
          child: Row(
            children: [
              Icon(Icons.inventory_2, size: 20),
              SizedBox(width: 8),
              Text('我的物品'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'edit_profile',
          child: Row(
            children: [
              Icon(Icons.person, size: 20),
              SizedBox(width: 8),
              Text('個人資料'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'chat_list',
          child: Row(
            children: [
              Icon(Icons.chat, size: 20),
              SizedBox(width: 8),
              Text('聊天室'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'transaction_history',
          child: Row(
            children: [
              Icon(Icons.history, size: 20),
              SizedBox(width: 8),
              Text('交易記錄'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'keyword_subscription',
          child: Row(
            children: [
              Icon(Icons.notifications_active, size: 20, color: Colors.orange),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('關鍵字訂閱', style: TextStyle(color: Colors.orange)),
                  if (_subscribedKeywords.isNotEmpty)
                    Text(
                      '已訂閱 ${_subscribedKeywords.length} 個',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                ],
              ),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text('登出', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _logout() async {
    try {
      await context.read<AuthProvider>().signOut();
      context.go('/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登出失敗：${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40, 
              height: 40, 
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.share, 
                size: 32, 
                color: Colors.white,
              ),
            ),
//            Text('物品地圖'),
            if (_isNotificationMode) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active, size: 16, color: Colors.orange),
                    SizedBox(width: 4),
                    Text(
                      '通知模式',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_isSearching) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, size: 16, color: Colors.blue),
                    SizedBox(width: 4),
                    Text(
                      '"$_searchKeyword"',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          if (_isNotificationMode)
            IconButton(
              icon: Icon(Icons.clear_all, color: Colors.orange),
              onPressed: _exitNotificationMode,
              tooltip: '回到正常顯示',
            )
          else if (_isSearching)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.red),
              onPressed: _clearSearch,
              tooltip: '清除搜尋',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _initializeMap,
          ),
          _buildPopupMenu(),
        ],
      ),
      body: Stack(
        children: [
          Consumer2<MapProvider, ItemProvider>(
            builder: (context, mapProvider, itemProvider, child) {
              if (mapProvider.currentPosition == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在獲取位置...'),
                    ],
                  ),
                );
              }

              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    mapProvider.currentPosition!.latitude,
                    mapProvider.currentPosition!.longitude,
                  ),
                  zoom: 15.0,
                ),
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onTap: (_) {
                  setState(() {
                    _selectedItem = null;
                  });
                  _updateMarkers();
                },
                circles: {
                  Circle(
                    circleId: CircleId('search_radius'),
                    center: LatLng(
                      mapProvider.currentPosition!.latitude,
                      mapProvider.currentPosition!.longitude,
                    ),
                    radius: 2000,
                    strokeColor: Colors.blue.withOpacity(0.3),
                    strokeWidth: 2,
                    fillColor: Colors.blue.withOpacity(0.1),
                  ),
                },
              );
            },
          ),

          if (_isLoading)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(_isNotificationMode 
                            ? '正在載入通知相關物品...'
                            : _isSearching 
                                ? '正在搜尋物品...' 
                                : '正在載入附近的物品...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_errorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red[100],
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[800]),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_isNotificationMode)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '正在顯示符合推播條件的物品 (${_getFilteredItems().length} 個)',
                          style: TextStyle(color: Colors.orange[800]),
                        ),
                      ),
                      TextButton(
                        onPressed: _exitNotificationMode,
                        child: Text('顯示全部'),
                      ),
                    ],
                  ),
                ),
              ),
            )
//不顯示搜尋結果的文字提示
/*                
          else if (_isSearching)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '找到 ${_getFilteredItems().length} 個符合 "$_searchKeyword" 的物品',
                          style: TextStyle(color: Colors.blue[800]),
                        ),
                      ),
                      TextButton(
                        onPressed: _clearSearch,
                        child: Text('清除'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
*/            
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => context.go('/add-item'),
            tooltip: '上架物品',
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            child: Icon(Icons.add),
            heroTag: "add_item",
          ),
          SizedBox(height: 12),
          FloatingActionButton(
            onPressed: _showSearchDialog,
            tooltip: '搜尋物品',
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            child: Icon(Icons.search),
            heroTag: "search",
          ),
        ],
      ),
    );
  }
}
