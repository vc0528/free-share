import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class MapProvider extends ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> getCurrentLocation() async {
    print("🚀 開始獲取位置...");
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 檢查位置服務
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print("📍 位置服務啟用: $serviceEnabled");
      
      if (!serviceEnabled) {
        throw Exception('位置服務未啟用，請在設定中開啟GPS');
      }

      // 檢查和請求權限
      LocationPermission permission = await Geolocator.checkPermission();
      print("🔑 當前權限: $permission");
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print("🔑 請求權限結果: $permission");
      }
      
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        throw Exception('需要位置權限才能使用地圖功能');
      }

      // 獲取當前位置
      print("📡 開始獲取GPS位置...");
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );
      
      print("✅ 位置獲取成功: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}");
      
    } catch (e) {
      print("❌ 位置獲取失敗: $e");
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
