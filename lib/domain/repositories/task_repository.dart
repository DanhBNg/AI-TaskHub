import 'dart:typed_data';

import '../entities/task_entity.dart';

abstract class TaskRepository {
  Stream<List<TaskEntity>> getTasksByProject(String projectId);
  Future<void> createTask(TaskEntity task);
  Future<void> updateTaskStatus(String taskId, String newStatus);
  Future<void> updateTask(TaskEntity task);
  Future<void> deleteTask(String taskId);

  Stream<List<Map<String, dynamic>>> watchAttachments(String taskId);
  Future<void> uploadAttachment(
    String taskId,
    String fileName,
    Uint8List fileBytes,
  );
  Future<void> deleteAttachment(String taskId, Map<String, dynamic> fileData);
}
