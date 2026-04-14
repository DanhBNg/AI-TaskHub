import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/message_repository.dart';
import '../datasources/message_remote_data_source.dart';
import '../models/message_model.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class MessageRepositoryImpl implements MessageRepository {
  final MessageRemoteDataSource remoteDataSource;

  MessageRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<MessageEntity>> getMessagesByTask(String taskId) {
    return remoteDataSource.getMessagesByTask(taskId);
  }

  @override
  Future<void> sendMessage(MessageEntity message, {Uint8List? imageBytes}) async {
    String? uploadedImageUrl = message.imageUrl;

    if (imageBytes != null) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('chat_images/${message.taskId}/$fileName');

      // putdataa
      await ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
      uploadedImageUrl = await ref.getDownloadURL();
    }

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final messageModel = MessageModel(
      messageId: messageId, taskId: message.taskId, senderId: message.senderId,
      senderName: message.senderName,
      senderAvatarUrl: message.senderAvatarUrl,
      content: message.content,
      imageUrl: uploadedImageUrl, timestamp: message.timestamp,
    );
    await remoteDataSource.sendMessage(messageModel);
  }
}