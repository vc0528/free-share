import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> getCurrentUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists && doc.data() != null) {
          return UserModel.fromFirestore(doc);
        }
      }
      return null;
    } catch (e) {
      print('Error getting current user data: $e');
      return null;
    }
  }

  // 新增：根據username查找用戶email
  Future<String?> getEmailByUsername(String username) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.trim())
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        Map<String, dynamic> userData = query.docs.first.data() as Map<String, dynamic>;
        return userData['email'];
      }
      return null;
    } catch (e) {
      print('Error finding email by username: $e');
      return null;
    }
  }

  // 修改：支援username登入，並檢查email驗證狀態
  Future<UserCredential?> signInWithUsername(String username, String password) async {
    try {
      // 先根據username查找email
      String? email = await getEmailByUsername(username);
      if (email == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: '找不到該用戶名',
        );
      }

      // 使用email進行登入
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // 檢查email是否已驗證
      if (result.user != null) {
        await result.user!.reload(); // 重新載入用戶狀態
        User? currentUser = _auth.currentUser;
        
        if (currentUser != null && !currentUser.emailVerified) {
          // 如果未驗證，登出並拋出錯誤
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'email-not-verified',
            message: '請先驗證您的Email才能登入',
          );
        }
        
        // 如果已驗證，更新Firestore狀態（以防資料不同步）
        if (currentUser != null && currentUser.emailVerified) {
          await _firestore.collection('users').doc(currentUser.uid).update({
            'emailVerified': true,
            'emailVerifiedAt': FieldValue.serverTimestamp(),
            'lastActive': FieldValue.serverTimestamp(),
          });
        }
        
        // 更新最後活動時間
        await _updateLastActive(result.user!.uid);
      }
      
      return result;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      // 將email相關錯誤轉換為username相關錯誤
      if (e.code == 'user-not-found') {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: '找不到該用戶名',
        );
      } else if (e.code == 'wrong-password') {
        throw FirebaseAuthException(
          code: 'wrong-password',
          message: '密碼錯誤',
        );
      } else if (e.code == 'email-not-verified') {
        // 保持原始錯誤訊息
        rethrow;
      }
      rethrow;
    } catch (e) {
      print('Unexpected sign in error: $e');
      rethrow;
    }
  }

  // 保留原有的email登入方法（供內部使用）
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      // 更新最後活動時間
      if (result.user != null) {
        await _updateLastActive(result.user!.uid);
      }
      
      return result;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Unexpected sign in error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> createUserWithEmailAndPassword(
      String email, String password, String username) async {
    UserCredential? result;
    User? user;  // 加入這行定義user變數
  
    try {
      // 檢查密碼強度
      String? passwordError = validatePassword(password);
      if (passwordError != null) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: passwordError,
        );
      }
  
      // 檢查用戶名是否已存在
      bool usernameExists = await _checkUsernameExists(username);
      if (usernameExists) {
        throw FirebaseAuthException(
          code: 'username-already-exists',
          message: '用戶名已存在',
        );
      }
  
      // 步驟1：創建Firebase Auth用戶
      print('步驟1：創建Firebase Auth用戶');
      result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      user = result.user;
      print('Firebase Auth創建成功: ${user!.uid}');
    } catch (e) {
      print('Firebase Auth創建過程發生錯誤: $e');
  
      // 檢查是否是PigeonUserDetails錯誤且用戶實際已創建
      if (e.toString().contains('PigeonUserDetails') && _auth.currentUser != null) {
        print('檢測到PigeonUserDetails錯誤，但用戶已創建');
        user = _auth.currentUser;
        print('使用當前用戶繼續: ${user!.uid}');
      } else {
        print('真正的創建失敗，拋出錯誤');
        rethrow;
      }
    }
  
    // 確保有用戶才繼續
    if (user == null) {
      throw Exception('用戶創建失敗');
    }
  
    // 步驟2：立即發送驗證郵件（最重要）
    try {
      print('步驟2：發送驗證郵件');
      await user.sendEmailVerification();
      print('✅ 驗證郵件發送成功');
    } catch (e) {
      print('❌ 驗證郵件發送失敗: $e');
    }
  
    // 步驟3：創建Firestore文檔（可以稍後補救）
    try {
      print('步驟3：創建Firestore文檔');
      UserModel newUser = UserModel(
        uid: user.uid,  // 使用user而不是result.user
        email: email.trim(),
        username: username.trim(),
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        rating: RatingData(),
        transactionStats: TransactionStats(joinDate: DateTime.now()),
        preferences: UserPreferences(),
        isAdmin: false,
        isBanned: false,
        emailVerified: false,
      );
  
      await _firestore.collection('users').doc(user.uid).set(newUser.toFirestore());
      print('✅ Firestore文檔創建成功');
    } catch (e) {
      print('❌ Firestore文檔創建失敗: $e');
      // 不拋出錯誤，因為最重要的Auth和Email已經完成
    }
  
    return result;
  }

  Future<bool> _checkUsernameExists(String username) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.trim())
          .limit(1)
          .get();
      
      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking username: $e');
      return false; // 如果檢查失敗，允許繼續註冊
    }
  }

  Future<void> _updateLastActive(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last active: $e');
      // 不拋出錯誤，因為這不是關鍵操作
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      if (e.toString().contains('PigeonUserDetails')) {
        print('忽略登出時的 PigeonUserDetails 錯誤');
        return;
      }

      rethrow;
    }
  }

  Future<UserModel?> getUserById(String uid) async {
    try {
      print('AuthService: 獲取用戶資料 uid=$uid');
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      print('AuthService: 文檔存在=${doc.exists}');
      
      if (doc.exists && doc.data() != null) {
        UserModel user = UserModel.fromFirestore(doc);
        print('AuthService: 找到用戶=${user.username}');
        return user;
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  // 新增：密碼強度驗證
  String? validatePassword(String password) {
    if (password.length < 8) {
      return '密碼至少需要8個字符';
    }
    if (password.length > 50) {
      return '密碼不能超過50個字符';
    }
    
    // 檢查是否包含數字
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return '密碼必須包含至少一個數字';
    }
    
    // 檢查是否包含字母
    if (!RegExp(r'[a-zA-Z]').hasMatch(password)) {
      return '密碼必須包含至少一個字母';
    }
    
    // 檢查是否包含特殊字符（可選，較嚴格）
    // if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
    //   return '密碼必須包含至少一個特殊字符';
    // }
    
    return null; // 密碼符合要求
  }

  // 修改：重設密碼功能，支援username或email
  Future<void> resetPassword(String usernameOrEmail) async {
    try {
      String email;
      
      // 判斷輸入的是email還是username
      if (usernameOrEmail.contains('@')) {
        // 包含@符號，認為是email
        email = usernameOrEmail.trim();
      } else {
        // 不包含@符號，認為是username，需要查找對應的email
        String? foundEmail = await getEmailByUsername(usernameOrEmail);
        if (foundEmail == null) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: '找不到該用戶名對應的帳戶',
          );
        }
        email = foundEmail;
      }

      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print('Password reset error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Unexpected password reset error: $e');
      rethrow;
    }
  }

  // 新增：更新用戶資料
  Future<void> updateUserProfile({
    String? username,
    String? avatarUrl,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) throw Exception('用戶未登入');

      Map<String, dynamic> updates = {};
      
      if (username != null) {
        // 檢查新用戶名是否已存在
        bool usernameExists = await _checkUsernameExists(username);
        if (usernameExists) {
          throw Exception('用戶名已存在');
        }
        updates['username'] = username.trim();
      }
      
      if (avatarUrl != null) {
        updates['avatarUrl'] = avatarUrl;
      }

      if (updates.isNotEmpty) {
        updates['lastActive'] = FieldValue.serverTimestamp();
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update(updates);
      }
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  //變更密碼
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) throw Exception('用戶未登入');

      // 檢查新密碼強度
      String? passwordError = validatePassword(newPassword);
      if (passwordError != null) {
        throw Exception(passwordError);
      }
  
      // 重新認證用戶
      String email = user.email!;
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
  
      await user.reauthenticateWithCredential(credential);
  
      // 更新密碼
      await user.updatePassword(newPassword);

    } catch (e) {
      print('Change password error: $e');
      if (e.toString().contains('PigeonUserDetails')) {
        print('忽略密碼變更時的 PigeonUserDetails 錯誤');
        return;
      }
      // 處理常見的認證錯誤
      if (e.toString().contains('wrong-password')) {
        throw Exception('目前密碼不正確');
      } else if (e.toString().contains('weak-password')) {
        throw Exception('新密碼強度不足');
      } else if (e.toString().contains('requires-recent-login')) {
        throw Exception('需要重新登入才能變更密碼');
      }

      rethrow;

    }
  }

  // 新增：檢查用戶是否被封鎖
  Future<bool> isUserBanned(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['isBanned'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking ban status: $e');
      return false;
    }
  }
}
