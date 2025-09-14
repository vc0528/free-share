import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  bool _isSubmitting = false;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    print('=== _loadUserData 開始 ===');

    try {
      print('1. 獲取 AuthProvider');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      print('2. 當前用戶: ${authProvider.currentUser?.uid}');

      final userData = authProvider.userData;
      print('3. 現有 userData: ${authProvider.userData?.username}');

      if (mounted) {  //check widget 

        if (userData != null) {
          setState(() {
            _currentUser = userData;
            _usernameController.text = userData.username;
            _isLoading = false;
            print('4. 用戶資料設置成功');
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          print('5.用戶資料為空，但繼續顯示頁面');
        }
      }
    } catch (e) {
      print('=== _loadUserData 異常 ===');
      print('錯誤詳情: $e');
      print('錯誤類型: ${e.runtimeType}');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  // 圖片選擇方法
  Future<void> _showImageSourceDialog() async {
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
                '選擇頭像來源',
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
              if (_currentUser?.avatarUrl != null) ...[
                SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _removeAvatar();
                  },
                  icon: Icon(Icons.delete, color: Colors.red),
                  label: Text('移除頭像', style: TextStyle(color: Colors.red)),
                ),
              ],
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
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: Colors.green),
            SizedBox(height: 6),
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
        maxWidth: 512,
        maxHeight: 512,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('選擇圖片時發生錯誤: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _removeAvatar() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<String?> _uploadAvatar() async {
    if (_selectedImage == null) return null;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser!.uid;
      
      String fileName = 'avatar_$userId.jpg';
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('users/$userId/$fileName');
      
      UploadTask uploadTask = ref.putFile(
        _selectedImage!,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'max-age=60',
        ),
      );
      
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('頭像上傳失敗: $e');
      throw e;
    }
  }

/*
  Future<void> sendPasswordResetEmail() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final email = authProvider.currentUser?.email;

      if (email != null) {
        await authProvider.resetPassword(email);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('密碼重設郵件已發送到 $email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('發送失敗: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
*/
  Future<void> _submitChanges() async {
    setState(() {
      _isSubmitting = true;
    });
  
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
  
      // 處理頭像上傳
      String? avatarUrl;
      if (_selectedImage != null) {
        avatarUrl = await _uploadAvatar();
      } else if (_currentUser?.avatarUrl != null) {
        avatarUrl = _currentUser!.avatarUrl;
      }
  
      // 更新頭像（如果有變更）
      if (_selectedImage != null || avatarUrl != _currentUser?.avatarUrl) {
        await authProvider.updateUserProfile(avatarUrl: avatarUrl);
      }
  
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('個人資料已更新'), backgroundColor: Colors.green),
      );
  
      await Future.delayed(Duration(milliseconds: 1000));
      if (mounted) {
        Navigator.pop(context);
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
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('編輯個人資料'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('載入用戶資料失敗'),
              ElevatedButton(
                onPressed: _loadUserData,
                child: Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('編輯個人資料'),
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
                  children: [
                    // 頭像區域
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                          GestureDetector(
                            onTap: _showImageSourceDialog,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundImage: _selectedImage != null
                                      ? FileImage(_selectedImage!) as ImageProvider<Object>
                                      : (_currentUser?.avatarUrl != null
                                          ? NetworkImage(_currentUser!.avatarUrl!) as ImageProvider<Object>
                                          : null),
                                  child: (_selectedImage == null && _currentUser?.avatarUrl == null)
                                      ? Icon(Icons.person, size: 50, color: Colors.grey[600])
                                      : null,
                                  backgroundColor: Colors.grey[200],
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '點擊更換頭像',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // 基本資訊
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                            '基本資訊',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          // 用戶名
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '用戶名',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _currentUser?.username ?? '',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.lock, color: Colors.grey[400], size: 16),
                                  ],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '用戶名無法修改',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 16),
                          
                          // 密碼變更區塊
                          /*
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '發送重設密碼通知信',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: sendPasswordResetEmail,
                                      child: Text('發送重設密碼郵件'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          */
                          
                          SizedBox(height: 16),
                          
                          // Email (只讀)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _currentUser?.email ?? '',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.lock, color: Colors.grey[400], size: 16),
                                  ],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Email 無法修改',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 24),
                    
                    // 帳戶統計
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                            '帳戶統計',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStatItem(
                                '加入天數',
                                '${DateTime.now().difference(_currentUser!.createdAt).inDays}',
                                Icons.calendar_today,
                              ),
                              SizedBox(width: 16),
                              _buildStatItem(
                                '分享物品',
                                '${_currentUser!.transactionStats.totalPosted}',
                                Icons.inventory_2,
                              ),
                              SizedBox(width: 16),
                              _buildStatItem(
                                '完成交易',
                                '${_currentUser!.transactionStats.completedTransactions}',
                                Icons.check_circle,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green[100]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.green[600], size: 20),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
            onPressed: _isSubmitting ? null : _submitChanges,
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
