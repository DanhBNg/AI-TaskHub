import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

abstract class MessageRemoteDataSource {
  Stream<List<MessageModel>> getMessagesByTask(String taskId);
  Future<void> sendMessage(MessageModel message);
  Future<void> updateTaskLastMessage({
    required String taskId,
    required String preview,
  });
}

class MessageRemoteDataSourceImpl implements MessageRemoteDataSource {
  final FirebaseFirestore firestore;

  MessageRemoteDataSourceImpl({required this.firestore});

  @override
  Stream<List<MessageModel>> getMessagesByTask(String taskId) {
    return firestore
        .collection('MESSAGES')
        .where('taskId', isEqualTo: taskId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList(),
        );
  }

  @override
  Future<void> sendMessage(MessageModel message) async {
    await firestore
        .collection('MESSAGES')
        .doc(message.messageId)
        .set(message.toJson());
  }

  @override
  Future<void> updateTaskLastMessage({
    required String taskId,
    required String preview,
  }) async {
    await firestore.collection('TASKS').doc(taskId).update({
      'lastMessage': preview,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }
}
