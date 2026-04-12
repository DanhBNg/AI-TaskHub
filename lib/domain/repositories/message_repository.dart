
import 'dart:typed_data';
import '../entities/message_entity.dart';

abstract class MessageRepository {
  Stream<List<MessageEntity>> getMessagesByTask(String taskId);

  Future<void> sendMessage(MessageEntity message, {Uint8List? imageBytes});
}