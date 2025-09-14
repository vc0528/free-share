import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final List<String> participants;
  final String itemId;
  final LastMessage? lastMessage;
  final DateTime createdAt;

  ChatRoomModel({
    required this.id,
    required this.participants,
    required this.itemId,
    this.lastMessage,
    required this.createdAt,
  });

  factory ChatRoomModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return ChatRoomModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      itemId: data['itemId'] ?? '',
      lastMessage: data['lastMessage'] != null
          ? LastMessage.fromMap(data['lastMessage'])
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'itemId': itemId,
      'lastMessage': lastMessage?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class LastMessage {
  final String text;
  final String senderId;
  final DateTime timestamp;

  LastMessage({
    required this.text,
    required this.senderId,
    required this.timestamp,
  });

  factory LastMessage.fromMap(Map<String, dynamic> map) {
    return LastMessage(
      text: map['text'] ?? '',
      senderId: map['senderId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class MessageModel {
  final String id;
  final String text;
  final String senderId;
  final DateTime timestamp;
  final String type;

  MessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    required this.timestamp,
    this.type = 'text',
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return MessageModel(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: data['type'] ?? 'text',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'senderId': senderId,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
    };
  }
}
