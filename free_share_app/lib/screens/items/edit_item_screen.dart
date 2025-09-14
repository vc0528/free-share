import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/item_provider.dart';
import '../../models/item_model.dart';

class EditItemScreen extends StatefulWidget {
  final String itemId;

  EditItemScreen({required this.itemId});

  @override
  _EditItemScreenState createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  
  List<String> _existingImageUrls = [];
  List<File> _newImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  bool _isSubmitting = false;
  ItemModel? _item;

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadItem() async {
    try {
      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      final item = await itemProvider.getItemById(widget.itemId);
      
      if (item != null) {
        // 檢查是否為物品擁有者
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser?.uid != item.ownerId) {
          _showError('您沒有權限編輯此物品');
          return;
        }

        setState(() {
          _item = item;
          _descriptionController.text = item.description;
          _tagController.text = item.tag;
          _existingImageUrls = List.from(item.imageUrls);
          _isLoading = false;
        });
      } else {
        _showError('找不到該物品');
      }
    } catch (e) {
      _showError('載入失敗：${e.toString()}');
    }
  }

  void _showError(String message) {
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
    context.pop();
  }

  // 圖片處理方法
  Future<void> _showImageSourceDialog() async {
    if (_existingImageUrls.length + _newImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('最多只能有5張圖片'), backgroundColor: Colors.orange),
      );
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
                      label: '相簿',
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
          _newImages.add(File(pickedFile.path));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('圖片已添加'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('選擇圖片時發生錯誤: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<void> _submitChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_existingImageUrls.isEmpty && _newImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('請至少保留一張圖片'), backgroundColor: Colors.orange),
      );
      return;
      }

    if (_tagController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('請輸入物品標籤'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final itemProvider = Provider.of<ItemProvider>(context, listen: false);
      await itemProvider.updateItem(
        itemId: widget.itemId,
        description: _descriptionController.text.trim(),
        tag: _tagController.text.trim(),
        existingImageUrls: _existingImageUrls,
        newImageFiles: _newImages,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('物品已更新'), backgroundColor: Colors.green),
      );

      await Future.delayed(Duration(milliseconds: 1000));
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失敗: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('編輯物品'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('編輯物品'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_isSubmitting)
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
      ),
    );
  }

  Widget _buildImageSection() {
    final totalImages = _existingImageUrls.length + _newImages.length;

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
          '最多可有5張圖片，當前有$totalImages張',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        SizedBox(height: 12),

        Container(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // 添加圖片按鈕
              if (totalImages < 5)
                GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, color: Colors.grey[400], size: 32),
                        SizedBox(height: 4),
                        Text(
                          '添加圖片',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

              // 現有圖片
              ..._existingImageUrls.asMap().entries.map((entry) {
                int index = entry.key;
                String imageUrl = entry.value;
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
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (index == 0 && _newImages.isEmpty)
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
                          onTap: () => _removeExistingImage(index),
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

              // 新添加的圖片
              ..._newImages.asMap().entries.map((entry) {
                int index = entry.key;
                File image = entry.value;
                bool isMainImage = _existingImageUrls.isEmpty && index == 0;
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
                      if (isMainImage)
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
                          onTap: () => _removeNewImage(index),
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
            hintText: '描述物品的狀況、使用情況、注意事項等...',
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
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: (_isSubmitting ||
                       (_existingImageUrls.isEmpty && _newImages.isEmpty) ||
                       _tagController.text.trim().isEmpty)
                ? null
                : _submitChanges,
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
                      Text('更新中...'),
                    ],
                  )
                : Text(
                    '保存更改',
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
      ),
    );
  }
}
