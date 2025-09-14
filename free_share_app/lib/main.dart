import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
//import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'providers/auth_provider.dart';
import 'providers/map_provider.dart';
import 'providers/item_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/edit_profile_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/items/add_item_screen.dart';
import 'screens/items/my_items_screen.dart';
import 'screens/items/edit_item_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/transaction/transaction_history_screen.dart';
import 'screens/transaction/rating_screen.dart';
// 新增：導入通知服務
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  runApp(MyApp());
}

class FirebaseService {
  static Future<void> initialize() async {
    try {
      // Firebase 初始化
      await Firebase.initializeApp();
/*      
      if (kDebugMode) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
          webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
        );
        
        print('App Check initialized in debug mode');
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttest,
          webProvider: ReCaptchaV3Provider('your-recaptcha-site-key'),
        );
      }
 */
      
      // 新增：初始化通知服務
      await _initializeNotificationService();
      
      print('Firebase 和通知服務初始化完成');
      
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  }

  // 新增：通知服務初始化方法
  static Future<void> _initializeNotificationService() async {
    try {
      print('開始初始化通知服務...');
      
      // 獲取通知服務實例並初始化
      final notificationService = NotificationService();
      await notificationService.initialize();
      
      // 檢查初始化狀態
      final status = await notificationService.getNotificationStatus();
      print('通知服務狀態: $status');
      
      // 如果在調試模式，發送測試通知
      if (kDebugMode) {
        // 延遲3秒後發送測試通知，確保用戶看到應用啟動
        Future.delayed(Duration(seconds: 3), () async {
          try {
            await notificationService.sendTestNotification();
            print('測試通知已發送');
          } catch (e) {
            print('測試通知發送失敗: $e');
          }
        });
      }
      
    } catch (e) {
      print('通知服務初始化失敗: $e');
      // 通知服務初始化失敗不應該阻止應用啟動
    }
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => ItemProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return MaterialApp.router(
            title: '免費物品分享',
            theme: ThemeData(
              primarySwatch: Colors.green,
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            routerConfig: _createRouter(authProvider),
          );
        },
      ),
    );
  }
}

GoRouter _createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: authProvider.isAuthenticated ? '/map' : '/login',
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final currentPath = state.uri.toString();
      final isOnAuthPage = currentPath == '/login' || currentPath == '/register';

//      final isOnAuthPage = state.uri.toString() == '/login' || state.uri.toString() == '/register';
      
      if (isAuthenticated && isOnAuthPage) {
        return '/map';
      }
      
      if (!isAuthenticated && !isOnAuthPage) {
        return '/login';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterScreen(),
      ),
      // 修改：支持通知模式參數
      GoRoute(
        path: '/map',
        builder: (context, state) {
          // 檢查查詢參數
          final queryParams = state.uri.queryParameters;
          return MapScreen(
            notificationMode: queryParams['mode'] == 'notification',
            highlightItemId: queryParams['itemId'],
            notificationType: queryParams['type'],
          );
        },
      ),
      GoRoute(
        path: '/add-item',
        builder: (context, state) => AddItemScreen(),
      ),
      // 新增路由
      GoRoute(
        path: '/my-items',
        builder: (context, state) => MyItemsScreen(),
      ),
      GoRoute(
        path: '/edit-item/:itemId',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          return EditItemScreen(itemId: itemId);
        },
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => EditProfileScreen(),
      ),
      GoRoute(
        path: '/chat-list',
        builder: (context, state) => ChatListScreen(),
      ),
      GoRoute(
        path: '/transaction_history',
        builder: (context, state) => TransactionHistoryScreen(),
      ),
      GoRoute(
        path: '/rating/:itemId',
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return RatingScreen(
            itemId: itemId,
            otherUserId: extra?['otherUserId'] ?? '',
            otherUserName: extra?['otherUserName'] ?? '',
            itemTitle: extra?['itemTitle'] ?? '',
          );
        },
      ),
    ],
    refreshListenable: authProvider,
  );
}
