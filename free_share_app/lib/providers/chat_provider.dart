import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  
  List<ChatRoomModel> _chatRooms = [];
  List<MessageModel> _messages = [];
  bool _isLoading = false;
  String? _error;

  List<ChatRoomModel> get chatRooms => _chatRooms;
  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUserChatRooms(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _chatRooms = await _chatService.getUserChatRooms(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createOrGetChatRoom(
      String currentUserId, String otherUserId, String itemId) async {
    try {
      return await _chatService.createOrGetChatRoom(
          currentUserId, otherUserId, itemId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> sendMessage(String chatRoomId, String senderId, String text) async {
    try {
      await _chatService.sendMessage(chatRoomId, senderId, text);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Stream<List<MessageModel>> getMessagesStream(String chatRoomId) {
    return _chatService.getMessagesStream(chatRoomId);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
