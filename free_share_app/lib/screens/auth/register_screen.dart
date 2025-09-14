import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    print('=== Register Debug ===');
    print('開始註冊流程');
    print('Email: ${_emailController.text.trim()}');
    print('Username: ${_usernameController.text.trim()}');

    if (!_formKey.currentState!.validate()) {
      print('表單驗證失敗');
      return;
    }

    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // 清除之前的錯誤
    authProvider.clearError();
    print('呼叫 authProvider.signUp');
    bool success = await authProvider.signUp(
      _emailController.text.trim(),
      _passwordController.text,
      _usernameController.text.trim(),
    );

    print('註冊結果: $success');

    if (success && mounted) {
      // 註冊成功後，強制登出確保用戶無法直接進入系統
      await authProvider.signOut();
      
      // 顯示註冊成功對話框
      _showEmailVerificationDialog();
    }
  }

  // 修改：顯示email驗證對話框，強調需要驗證後才能登入
  void _showEmailVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 不能點擊外部關閉
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.email, color: Colors.green),
            SizedBox(width: 8),
            Text('註冊成功'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '恭喜您註冊成功！',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '驗證郵件已發送到：',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              _emailController.text.trim(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '重要提醒：',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• 請先點擊郵件中的驗證連結\n• 驗證完成後才能登入系統\n• 請檢查垃圾郵件資料夾\n• 驗證後請重新登入',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            child: Text('前往登入'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('註冊'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 32),
                    Icon(
                      Icons.person_add,
                      size: 80,
                      color: Colors.green,
                    ),
                    SizedBox(height: 32),
                    
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: '用戶名',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      enabled: !authProvider.isLoading,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '請輸入用戶名';
                        }
                        if (value.trim().length < 3) {
                          return '用戶名至少需要3個字符';
                        }
                        if (value.trim().length > 20) {
                          return '用戶名不能超過20個字符';
                        }
                        // 檢查特殊字符
                        if (!RegExp(r'^[a-zA-Z0-9\u4e00-\u9fa5_-]+$').hasMatch(value.trim())) {
                          return '用戶名只能包含字母、數字、中文、底線和連字符';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !authProvider.isLoading,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '請輸入Email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                          return '請輸入有效的Email';
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
                        helperText: '至少8個字符，包含字母和數字', // 更新密碼要求提示
                      ),
                      obscureText: true,
                      enabled: !authProvider.isLoading,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '請輸入密碼';
                        }
                        if (value.length < 8) { // 更新為8個字符
                          return '密碼至少需要8個字符';
                        }
                        if (value.length > 50) {
                          return '密碼不能超過50個字符';
                        }
                        // 檢查是否包含數字
                        if (!RegExp(r'[0-9]').hasMatch(value)) {
                          return '密碼必須包含至少一個數字';
                        }
                        // 檢查是否包含字母
                        if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
                          return '密碼必須包含至少一個字母';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: '確認密碼',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      enabled: !authProvider.isLoading,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '請確認密碼';
                        }
                        if (value != _passwordController.text) {
                          return '密碼不一致';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),
                    
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
                        onPressed: authProvider.isLoading ? null : _register,
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
                                  Text('註冊中...'),
                                ],
                              )
                            : Text('註冊'),
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
                          : () => context.go('/login'),
                      child: Text('已有帳號？返回登入'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
