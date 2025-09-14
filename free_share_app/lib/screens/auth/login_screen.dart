import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(); // 改為username
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // 清除之前的錯誤
    authProvider.clearError();
    
    print('=== Login Debug ===');
    print('開始登入流程');
    print('Username: ${_usernameController.text.trim()}');
    
    bool success = await authProvider.signIn(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    print('登入結果: $success');
    print('錯誤狀態: ${authProvider.error}');
    print('是否為email未驗證: ${authProvider.isEmailNotVerified}');

    if (success && mounted) {
      print('登入成功，準備導航');
      // 等待路由系統自動處理導航
      await Future.delayed(Duration(milliseconds: 100));
    } else if (!success && mounted) {
      print('登入失敗，檢查錯誤類型');
      if (authProvider.isEmailNotVerified) {
        print('顯示email未驗證對話框');
        _showEmailNotVerifiedDialog();
        authProvider.clearError();
      } else {
        print('其他錯誤，顯示在UI上: ${authProvider.error}');
        // 其他錯誤會在UI中自動顯示
      }
    }
  }

  // 新增：顯示email未驗證對話框
  void _showEmailNotVerifiedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Email未驗證'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '您的Email尚未驗證，無法登入系統。',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '請檢查您的信箱：',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• 查看註冊時的驗證郵件\n• 點擊郵件中的驗證連結\n• 檢查垃圾郵件資料夾',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              '沒有收到驗證郵件？',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('我知道了'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _showResendVerificationDialog();
            },
            child: Text('重新發送驗證郵件'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // 新增：重新發送驗證郵件對話框
  void _showResendVerificationDialog() {
    final usernameOrEmailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('重新發送驗證郵件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '請輸入您的用戶名或Email來重新發送驗證郵件：',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: usernameOrEmailController,
              decoration: InputDecoration(
                labelText: '用戶名或Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_search),
                hintText: '例如：john123 或 john@example.com',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final input = usernameOrEmailController.text.trim();
              if (input.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('請輸入用戶名或Email')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              // 這裡需要實作重新發送驗證郵件的邏輯
              // 暫時顯示提示訊息
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('功能開發中，請聯繫客服協助'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: Text('發送'),
          ),
        ],
      ),
    );
  }

  // 新增：忘記密碼功能
  Future<void> _showForgotPasswordDialog() async {
    final usernameOrEmailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('忘記密碼'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '請輸入您的用戶名或Email，我們將發送密碼重設信件給您。',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: usernameOrEmailController,
              decoration: InputDecoration(
                labelText: '用戶名或Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_search),
                hintText: '例如：john123 或 john@example.com',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final input = usernameOrEmailController.text.trim();
              if (input.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('請輸入用戶名或Email')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              bool success = await authProvider.resetPassword(input);
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('密碼重設郵件已發送，請檢查您的信箱'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (mounted && authProvider.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(authProvider.error!),
                    backgroundColor: Colors.red,
                  ),
                );
                authProvider.clearError();
              }
            },
            child: Text('發送'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('登入'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            // 如果認證狀態尚未初始化，顯示載入畫面
            if (!authProvider.isInitialized) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在初始化...'),
                  ],
                ),
              );
            }

            return Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.share,
                    size: 80,
                    color: Colors.green,
                  ),
                  SizedBox(height: 32),
                  Text(
                    '免費物品分享',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 32),
                  
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: '用戶名', // 改為用戶名
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person), // 改為person圖標
                    ),
                    enabled: !authProvider.isLoading,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '請輸入用戶名';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: '密碼',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    enabled: !authProvider.isLoading,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '請輸入密碼';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  
                  // 新增：忘記密碼按鈕
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: authProvider.isLoading ? null : _showForgotPasswordDialog,
                      child: Text(
                        '忘記密碼？',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  
                  if (authProvider.error != null)
                    Container(
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authProvider.error!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.red),
                            onPressed: authProvider.clearError,
                          ),
                        ],
                      ),
                    ),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: authProvider.isLoading ? null : _login,
                      child: authProvider.isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('登入中...'),
                              ],
                            )
                          : Text('登入'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () => context.go('/register'),
                    child: Text('還沒有帳號？註冊新帳號'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
