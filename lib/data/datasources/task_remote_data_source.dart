import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/task_model.dart';

abstract class TaskRemoteDataSource {
  Stream<List<TaskModel>> getTasksByProject(String projectId);
  Future<void> createTask(TaskModel task);
  Future<void> updateTaskStatus(String taskId, String newStatus);
  Future<void> updateTask(TaskModel task);
  Future<void> deleteTask(String taskId);

  Stream<List<Map<String, dynamic>>> watchAttachments(String taskId);
  Future<void> uploadAttachment(
    String taskId,
    String fileName,
    Uint8List fileBytes,
  );
  Future<void> deleteAttachment(String taskId, Map<String, dynamic> fileData);
}

bool shouldIgnoreMissingStorageObject(Object error) {
  return error is FirebaseException &&
      error.plugin == 'firebase_storage' &&
      error.code == 'object-not-found';
}

class TaskRemoteDataSourceImpl implements TaskRemoteDataSource {
  final FirebaseFirestore firestore;

  TaskRemoteDataSourceImpl({required this.firestore});

  @override
  Stream<List<TaskModel>> getTasksByProject(String projectId) {
    return firestore
        .collection('TASKS')
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList(),
        );
  }

  @override
  Future<void> createTask(TaskModel task) async {
    await firestore.collection('TASKS').doc(task.taskId).set(task.toJson());
  }

  @override
  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    await firestore.collection('TASKS').doc(taskId).update({
      'status': newStatus,
    });
  }

  @override
  Future<void> updateTask(TaskModel task) async {
    await firestore.collection('TASKS').doc(task.taskId).update(task.toJson());
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await firestore.collection('TASKS').doc(taskId).delete();
  }

  @override
  Stream<List<Map<String, dynamic>>> watchAttachments(String taskId) {
    return firestore.collection('TASKS').doc(taskId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data() ?? <String, dynamic>{};
      final attachments = data['attachments'];
      if (attachments is! List) return <Map<String, dynamic>>[];
      return attachments
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    });
  }

  @override
  Future<void> uploadAttachment(
    String taskId,
    String fileName,
    Uint8List fileBytes,
  ) async {
    final storageRef = FirebaseStorage.instance.ref().child(
      'task_attachments/$taskId/$fileName',
    );

    await storageRef.putData(
      fileBytes,
      SettableMetadata(contentType: 'application/octet-stream'),
    );
    final downloadUrl = await storageRef.getDownloadURL();

    await firestore.collection('TASKS').doc(taskId).update({
      'attachments': FieldValue.arrayUnion([
        {'name': fileName, 'url': downloadUrl},
      ]),
    });
  }

  @override
  Future<void> deleteAttachment(
    String taskId,
    Map<String, dynamic> fileData,
  ) async {
    final fileUrl = (fileData['url'] ?? '').toString();

    if (fileUrl.isNotEmpty) {
      final storageRef = FirebaseStorage.instance.refFromURL(fileUrl);
      try {
        await storageRef.delete();
      } catch (error) {
        if (!shouldIgnoreMissingStorageObject(error)) {
          rethrow;
        }
      }
    }

    await firestore.collection('TASKS').doc(taskId).update({
      'attachments': FieldValue.arrayRemove([fileData]),
    });
  }
}
