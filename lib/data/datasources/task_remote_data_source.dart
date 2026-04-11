import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

abstract class TaskRemoteDataSource {
  Stream<List<TaskModel>> getTasksByProject(String projectId);
  Future<void> createTask(TaskModel task);
  Future<void> updateTaskStatus(String taskId, String newStatus);
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
        .map((snapshot) => snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList());
  }

  @override
  Future<void> createTask(TaskModel task) async {
    await firestore.collection('TASKS').doc(task.taskId).set(task.toJson());
  }

  @override
  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    await firestore.collection('TASKS').doc(taskId).update({'status': newStatus});
  }
}