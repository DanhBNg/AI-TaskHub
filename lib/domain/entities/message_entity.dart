import 'package:equatable/equatable.dart';

class MessageEntity extends Equatable {
  final String messageId;
  final String taskId;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String content;
  final String? imageUrl;
  final DateTime timestamp;

  const MessageEntity({
    required this.messageId,
    required this.taskId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.content,
    this.imageUrl,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [messageId, taskId, senderId, senderName, senderAvatarUrl, content, imageUrl, timestamp];
}