import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  User? _user;
  UserModel? _userData;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

//  User? get user => _user;
  User? get currentUser => _user; // 添加這個 getter 給 MapScreen 使用
  UserModel? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null && !(_user?.isAnonymous ?? true);
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      // 等待 Firebase Auth 初始化完成
      await Future.delayed(Duration(milliseconds: 100));
      
      // 獲取當前用戶狀態
      _user = _authService.currentUser;
      if (_user != null) {
        await _loadUserData();
      }
      
      _isInitialized = true;
      notifyListeners();

      // 監聽認證狀態變化 - 使用 asyncMap 避免並發問題
      _authService.authStateChanges.listen((User? user) async {
        print('Auth state changed: ${user?.uid ?? "null"}');
        
        final previousUser = _user;
        _user = user;
        
        // 避免在build過程中調用notifyListeners
        if (_isInitialized) {
          // 延遲處理狀態變化，避免build衝突
          Future.microtask(() async {
            if (user != null && user.uid != previousUser?.uid) {
              // 新用戶登入或不同用戶
              await _loadUserData();
            } else if (user == null) {
              // 用戶登出
              _userData = null;
            }
            notifyListeners();
          });
        }
      });
      
    } catch (e) {
      print('Auth provider initialization error: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<UserModel?> getUserById(String uid) async {
    return await _authService.getUserById(uid);
  }

  Future<void> _loadUserData() async {
    if (_user != null) {
      try {
        _userData = await _authService.getCurrentUserData();
        if (_isInitialized) {
          notifyListeners();
        }
      } catch (e) {
        print('Error loading user data: $e');
        // 不設置錯誤狀態，因為這不是關鍵操作
      }
    }
  }

  // 修改：使用username登入
  Future<bool> signIn(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      UserCredential? result = await _authService
          .signInWithUsername(username, password);
      
      // 等待認證狀態穩定
      await Future.delayed(Duration(milliseconds: 500));
      
      _isLoading = false;
      notifyListeners();
      return result != null;
    } catch (e) {
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String username) async {
    print('=== AuthProvider.signUp ===');
    print('收到註冊請求: email=$email, username=$username');

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('呼叫 _authService.createUserWithEmailAndPassword');

      UserCredential? result = await _authService
          .createUserWithEmailAndPassword(email, password, username);

      print('AuthService 回傳結果: ${result != null}');
      
      // 等待認證狀態穩定
      await Future.delayed(Duration(milliseconds: 500));
      
      _isLoading = false;
      notifyListeners();
      
      // 檢查用戶是否真的創建成功（即使result為null）
      if (result != null || _authService.currentUser != null) {
        return true;
      }
      
      return false;
    } catch (e) {
      print('AuthProvider.signUp 發生錯誤: $e');
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _user = null;
      _userData = null;
      notifyListeners();
    } catch (e) {
      print('Sign out error: $e');

      // 即使有錯誤，也強制清除本地狀態
      if (e.toString().contains('PigeonUserDetails')) {
        print('強制清除登出狀態');
        _user = null;
        _userData = null;
        notifyListeners();
        return;
      }

      _error = '登出時發生錯誤';
      notifyListeners();
    }
  }

  // 新增：忘記密碼功能，支援username或email
  Future<bool> resetPassword(String usernameOrEmail) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.resetPassword(usernameOrEmail.trim());
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return '找不到該用戶';
        case 'wrong-password':
          return '密碼錯誤';
        case 'email-already-in-use':
          return 'Email已被使用';
        case 'weak-password':
          return error.message ?? '密碼太弱';
        case 'invalid-email':
          return 'Email格式錯誤';
        case 'too-many-requests':
          return '嘗試次數過多，請稍後再試';
        case 'network-request-failed':
          return '網路連接失敗';
        case 'username-already-exists':
          return '用戶名已存在';
        case 'email-not-verified':
          return 'email-not-verified'; // 特殊標記，需要特殊處理
        default:
          return error.message ?? '發生未知錯誤';
      }
    }
    return error.toString();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // 檢查是否是email未驗證錯誤
  bool get isEmailNotVerified {
    return _error == 'email-not-verified';
  }

  // 新增：檢查是否是註冊成功訊息
  bool get isRegistrationSuccess {
    return _error == 'registration_success';
  }

  // 新增：清除註冊成功狀態
  void clearRegistrationSuccess() {
    if (_error == 'registration_success') {
      _error = null;
      notifyListeners();
    }
  }

  // 新增：更新使用者個人資料
  Future<void> updateUserProfile({
    String? username,
    String? avatarUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
  
    try {
      await _authService.updateUserProfile(
        username: username,
        avatarUrl: avatarUrl,
      );
  
      // 重新載入使用者資料
      await _loadUserData();
  
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // 新增：變更密碼
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.changePassword(currentPassword, newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 添加重新載入用戶資料的方法
  Future<void> refreshUserData() async {
    if (_user != null) {
      await _loadUserData();
    }
  }

}
