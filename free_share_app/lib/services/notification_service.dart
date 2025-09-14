import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // 初始化通知服務
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Android 設定
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS 設定
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      // 初始化插件
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );

      // 請求權限
      await _requestPermissions();

      _initialized = true;
      print('NotificationService: 初始化完成');
    } catch (e) {
      print('NotificationService: 初始化失敗: $e');
    }
  }

  // 請求通知權限
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ 需要通知權限
      final status = await Permission.notification.request();
      return status == PermissionStatus.granted;
    } else if (Platform.isIOS) {
      // iOS 權限
      final bool? result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }
    return true;
  }

  // 檢查通知權限
  Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      return await Permission.notification.isGranted;
    } else if (Platform.isIOS) {
      // iOS 檢查
      // 這裡可以添加 iOS 權限檢查邏輯
      return true; // 簡化處理
    }
    return true;
  }

  // 發送新物品匹配通知
  Future<void> sendNewItemNotification({
    required String itemId,
    required String itemTitle,
    required String itemDescription,
    required List<String> matchedKeywords,
    required double distance,
    String? imageUrl,
  }) async {
    if (!_initialized) await initialize();

    try {
      const int notificationId = 1001; // 新物品通知ID範圍：1001-1999
      
      String title = '發現符合條件的物品！';
      String body = '$itemTitle - 距離您 ${distance.toStringAsFixed(1)}km\n符合關鍵字: ${matchedKeywords.join(', ')}';

      await _showNotification(
        id: notificationId + itemId.hashCode % 999, // 確保唯一ID
        title: title,
        body: body,
        payload: 'newItem:$itemId',
        channelId: 'new_items',
        channelName: '新物品通知',
        channelDescription: '當有符合您關鍵字的物品上架時通知',
        importance: Importance.high,
        priority: Priority.high,
      );

      print('NotificationService: 新物品通知已發送 - $itemTitle');
    } catch (e) {
      print('NotificationService: 發送新物品通知失敗: $e');
    }
  }

  // 發送位置更新通知
  Future<void> sendLocationUpdateNotification({
    required String itemId,
    required String itemTitle,
    required List<String> matchedKeywords,
    required double distance,
    String? imageUrl,
  }) async {
    if (!_initialized) await initialize();

    try {
      const int notificationId = 2001; // 位置更新通知ID範圍：2001-2999
      
      String title = '在新位置發現符合條件的物品！';
      String body = '$itemTitle - 距離您 ${distance.toStringAsFixed(1)}km\n符合關鍵字: ${matchedKeywords.join(', ')}';

      await _showNotification(
        id: notificationId + itemId.hashCode % 999,
        title: title,
        body: body,
        payload: 'locationUpdate:$itemId',
        channelId: 'location_updates',
        channelName: '位置更新通知',
        channelDescription: '當您移動到新位置發現符合條件的物品時通知',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      print('NotificationService: 位置更新通知已發送 - $itemTitle');
    } catch (e) {
      print('NotificationService: 發送位置更新通知失敗: $e');
    }
  }

  // 通用通知發送方法
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    required String channelId,
    required String channelName,
    required String channelDescription,
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
    String? largeIcon,
  }) async {
    try {
      // Android 通知詳細設定
      AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: importance,
        priority: priority,
        showWhen: true,
        autoCancel: true,
        enableVibration: true,
        enableLights: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: largeIcon != null 
            ? FilePathAndroidBitmap(largeIcon)
            : const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: '物品分享',
        ),
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'view_action',
            '查看物品',
            showsUserInterface: true,
          ),
          const AndroidNotificationAction(
            'dismiss_action',
            '忽略',
            showsUserInterface: false,
          ),
        ],
      );

      // iOS 通知詳細設定
      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1,
      );

      NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // 發送通知
      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      print('NotificationService: 顯示通知失敗: $e');
      rethrow;
    }
  }

  // 處理通知點擊
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload != null) {
      _handleNotificationTap(payload, response.actionId);
    }
  }

  // 處理通知點擊事件
  void _handleNotificationTap(String payload, String? actionId) {
    try {
      print('NotificationService: 通知被點擊 - payload: $payload, action: $actionId');

      // 解析 payload
      List<String> parts = payload.split(':');
      if (parts.length < 2) return;

      String type = parts[0];
      String itemId = parts[1];

      // 根據動作類型處理
      if (actionId == 'dismiss_action') {
        print('NotificationService: 用戶選擇忽略通知');
        return;
      }

      // 這裡可以添加導航邏輯
      // 例如：使用全局導航或事件總線來處理跳轉
      _notifyAppOfTap(type, itemId);

    } catch (e) {
      print('NotificationService: 處理通知點擊失敗: $e');
    }
  }

  // 通知應用程式通知被點擊
  void _notifyAppOfTap(String type, String itemId) {
    // 這裡可以使用事件總線或全局狀態管理來通知應用
    // 例如：EventBus.fire(NotificationTappedEvent(type, itemId));
    print('NotificationService: 需要跳轉到物品 $itemId，類型: $type');
  }

  // 取消特定通知
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  // 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  // 獲取待處理的通知
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  // 測試通知功能
  Future<void> sendTestNotification() async {
    if (!_initialized) await initialize();

    await _showNotification(
      id: 9999,
      title: '測試通知',
      body: '這是一個測試通知，用於確認通知功能正常工作',
      payload: 'test:notification',
      channelId: 'test',
      channelName: '測試通知',
      channelDescription: '用於測試通知功能',
    );
  }

  // 檢查通知設定
  Future<Map<String, dynamic>> getNotificationStatus() async {
    try {
      bool hasPermission = await this.hasPermission();
      List<PendingNotificationRequest> pending = await getPendingNotifications();
      
      return {
        'initialized': _initialized,
        'hasPermission': hasPermission,
        'pendingCount': pending.length,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      };
    } catch (e) {
      return {
        'initialized': false,
        'hasPermission': false,
        'pendingCount': 0,
        'error': e.toString(),
      };
    }
  }
}
