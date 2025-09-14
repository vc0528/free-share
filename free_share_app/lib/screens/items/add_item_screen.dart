import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../../providers/auth_provider.dart';
import '../../providers/map_provider.dart';
import '../../providers/item_provider.dart';

class AddItemScreen extends StatefulWidget {
  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  
  List<File> _images = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

//  List<String> _predefinedTags = [
//    '家具', '電器', '書籍', '玩具', '衣物', 
//    '廚具', '運動用品', '文具', '裝飾品', '其他'
//  ];
//  String? _selectedTag;

  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    if (mapProvider.currentPosition == null) {
      await mapProvider.getCurrentLocation();
    }
  }

  Future<void> _showImageSourceDialog() async {
    if (_images.length >= 5) {
      _showSnackBar('最多只能上傳5張圖片', Colors.orange);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Container(
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
                '選擇圖片來源',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSourceOption(
                      icon: Icons.camera_alt,
                      label: '拍照',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildSourceOption(
                      icon: Icons.photo_library,
                      label: '相冊',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.green),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        setState(() {
          _images.add(File(pickedFile.path));
        });
        _showSnackBar('圖片已添加', Colors.green);
      }
    } catch (e) {
      _showSnackBar('選擇圖片時發生錯誤: $e', Colors.red);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _submitItem() async {
    print('=== 開始上架流程 ===');
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_images.isEmpty) {
      _showSnackBar('請至少添加一張圖片', Colors.orange);
      return;
    }

//    if (_selectedTag == null) {
//      _showSnackBar('請選擇物品標籤', Colors.orange);
//      return;
//    }
    if (_tagController.text.trim().isEmpty) {
      _showSnackBar('請輸入物品標籤', Colors.orange);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);

    print('當前用戶: ${authProvider.currentUser?.uid}');
    print('位置信息: ${mapProvider.currentPosition}');
    print('輸入標籤: ${_tagController.text.trim()}');
    print('圖片數量: ${_images.length}');

    if (authProvider.currentUser == null) {
      _showSnackBar('請先登入', Colors.red);
      context.go('/login');
      return;
    }

    if (mapProvider.currentPosition == null) {
      _showSnackBar('正在獲取位置信息...', Colors.orange);
      await mapProvider.getCurrentLocation();
      
      if (mapProvider.currentPosition == null) {
        _showSnackBar('無法獲取位置信息，請檢查GPS權限', Colors.red);
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      print('開始調用 itemProvider.addItem...');
      String? itemId = await itemProvider.addItem(
        ownerId: authProvider.currentUser!.uid,
        description: _descriptionController.text.trim(),
//        tag: _selectedTag!,
        tag: _tagController.text.trim(),
        imageFiles: _images,
        latitude: mapProvider.currentPosition!.latitude,
        longitude: mapProvider.currentPosition!.longitude,
      );

      if (itemId != null) {
        _showSnackBar('物品上架成功！', Colors.green);
        await Future.delayed(Duration(milliseconds: 1500));
        
        if (mounted) {
          context.go('/map');
        }
      } else {
        _showSnackBar('上架失敗，請重試', Colors.red);
      }
    } catch (e) {
      _showSnackBar('上架失敗: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('免費分享物品'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.green,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Consumer2<ItemProvider, MapProvider>(
        builder: (context, itemProvider, mapProvider, child) {
          return Form(
            key: _formKey,
            child: Column(
              children: [
                if (_isSubmitting || itemProvider.isLoading)
                  LinearProgressIndicator(
                    backgroundColor: Colors.green[100],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (mapProvider.currentPosition != null)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(12),
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.blue),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '位置已自動獲取 (±200m模糊化保護隱私)',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        _buildImageSection(),
                        SizedBox(height: 24),
                        _buildDescriptionForm(),
                        SizedBox(height: 24),
                        _buildTagSection(),
                        SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                
                _buildBottomButton(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_camera, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Text(
              '物品圖片',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        SizedBox(height: 4),
        Text(
          '最多可上傳5張圖片',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        SizedBox(height: 12),
        
        Container(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: Container(
                  width: 100,
                  height: 100,
                  margin: EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _images.isEmpty ? Colors.red[300]! : Colors.grey[300]!,
                      width: _images.isEmpty ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        color: _images.isEmpty ? Colors.red[400] : Colors.grey[400],
                        size: 32,
                      ),
                      SizedBox(height: 4),
                      Text(
                        '添加圖片',
                        style: TextStyle(
                          color: _images.isEmpty ? Colors.red[400] : Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              ..._images.asMap().entries.map((entry) {
                int index = entry.key;
                File image = entry.value;
                return Container(
                  width: 100,
                  height: 100,
                  margin: EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: FileImage(image),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (index == 0)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '主圖',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Text(
              '物品描述',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            hintText: '描述物品的狀況、使用情況、注意事項等...\n例如：九成新的書桌，無刮傷，需自取',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
            alignLabelWithHint: true,
          ),
          maxLines: 5,
          maxLength: 500,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '請輸入物品描述';
            }
            if (value.trim().length < 10) {
              return '描述至少需要10個字符';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTagSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_offer, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Text(
              '物品標籤',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        SizedBox(height: 4),
        Text(
          '標籤將顯示在地圖圖釘旁，也用於過濾搜尋 (8字以內)',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        SizedBox(height: 12),

        TextFormField(
          controller: _tagController,
          decoration: InputDecoration(
            hintText: '例如：二手書桌、小家電、童書等',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(Icons.label, color: Colors.green),
          ),
          maxLength: 8,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '請輸入物品標籤';
            }
            if (value.trim().length < 2) {
              return '標籤至少需要2個字符';
            }
            return null;
          },
        ),
      ],
    );
  }
//  Widget _buildTagSection() {
//    return Column(
//      crossAxisAlignment: CrossAxisAlignment.start,
//      children: [
//        Row(
//          children: [
//            Icon(Icons.local_offer, color: Colors.green, size: 20),
//            SizedBox(width: 8),
//            Text(
//              '物品標籤',
//              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//            ),
//            Text(' *', style: TextStyle(color: Colors.red)),
//          ],
//        ),
//        SizedBox(height: 4),
//        Text(
//          '標籤將顯示在地圖圖釘旁，也用於過濾搜尋',
//          style: TextStyle(color: Colors.grey[600], fontSize: 12),
//        ),
//        SizedBox(height: 12),
//        
//        Wrap(
//          spacing: 8,
//          runSpacing: 8,
//          children: _predefinedTags.map((tag) {
//            bool isSelected = _selectedTag == tag;
//            return FilterChip(
//              label: Text(tag),
//              selected: isSelected,
//              onSelected: (selected) {
//                setState(() {
//                  _selectedTag = selected ? tag : null;
//                });
//              },
//              selectedColor: Colors.green[200],
//              checkmarkColor: Colors.green[700],
//              backgroundColor: Colors.white,
//              shape: RoundedRectangleBorder(
//                borderRadius: BorderRadius.circular(20),
//                side: BorderSide(
//                  color: isSelected ? Colors.green : Colors.grey[300]!,
//                ),
//              ),
//            );
//          }).toList(),
//        ),
//        
//        if (_selectedTag != null)
//          Container(
//            margin: EdgeInsets.only(top: 8),
//            padding: EdgeInsets.all(8),
//            decoration: BoxDecoration(
//              color: Colors.green[50],
//              borderRadius: BorderRadius.circular(8),
//              border: Border.all(color: Colors.green[200]!),
//            ),
//            child: Row(
//              mainAxisSize: MainAxisSize.min,
//              children: [
//                Icon(Icons.check_circle, color: Colors.green, size: 16),
//                SizedBox(width: 4),
//                Text(
//                  '已選擇: $_selectedTag',
//                  style: TextStyle(
//                    color: Colors.green[700],
//                    fontSize: 12,
//                    fontWeight: FontWeight.w500,
//                  ),
//                ),
//              ],
//            ),
//          ),
//      ],
//    );
//  }

  Widget _buildBottomButton() {
    return Container(
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
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _tagController,
          builder: (context, tagValue, child) {
            return SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (_isSubmitting || _images.isEmpty || tagValue.text.trim().isEmpty)
                    ? null
                    : _submitItem,
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
                          Text('上架中...'),
                        ],
                      )
                    : Text(
                        '免費分享物品',
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
            );
          },
        ),
      ),
    );
  }
}
