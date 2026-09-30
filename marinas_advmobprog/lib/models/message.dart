import 'package:cloud_firestore/cloud_firestore.dart';

// Act6 Enhancement 3: where a message is in its lifecycle. "sending" is never
// stored; it is read off the snapshot while the write is still local.
enum MessageStatus { sending, delivered, seen }

class MessageModel {
  final String senderId;
  final String senderEmail;
  final String receiverId;
  final String message;
  final Timestamp timestamp;
  final bool seen;

  MessageModel({
    required this.senderId,
    required this.senderEmail,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.seen = false,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      senderId: map['senderId'] ?? '',
      senderEmail: map['senderEmail'] ?? '',
      receiverId: map['receiverId'] ?? '',
      message: map['message'] ?? '',
      timestamp: map['timestamp'] is Timestamp
          ? map['timestamp']
          : Timestamp.now(),
      seen: map['seen'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderEmail': senderEmail,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'seen': seen,
    };
  }
}
