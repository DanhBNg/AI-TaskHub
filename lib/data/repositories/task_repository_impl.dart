import 'dart:typed_data';

import '../../domain/entities/task_entity.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/task_remote_data_source.dart';
import '../models/task_model.dart';

class TaskRepositoryImpl implements TaskRepository {
  final TaskRemoteDataSource remoteDataSource;

  TaskRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<TaskEntity>> getTasksByProject(String projectId) {
    return remoteDataSource.getTasksByProject(projectId);
  }

  @override
  Future<void> createTask(TaskEntity task) async {
    final taskModel = TaskModel(
      taskId: task.taskId,
      projectId: task.projectId,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      dueDate: task.dueDate,
      assigneeIds: task.assigneeIds,
      assigneeNames: task.assigneeNames,
      assigneeAvatarUrls: task.assigneeAvatarUrls,
      createdAt: task.createdAt,
    );
    await remoteDataSource.createTask(taskModel);
  }

  @override
  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    await remoteDataSource.updateTaskStatus(taskId, newStatus);
  }

  @override
  Future<void> updateTask(TaskEntity task) async {
    final taskModel = TaskModel(
      taskId: task.taskId,
      projectId: task.projectId,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      dueDate: task.dueDate,
      assigneeIds: task.assigneeIds,
      assigneeNames: task.assigneeNames,
      assigneeAvatarUrls: task.assigneeAvatarUrls,
      createdAt: task.createdAt,
    );

    await remoteDataSource.updateTask(taskModel);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await remoteDataSource.deleteTask(taskId);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchAttachments(String taskId) {
    return remoteDataSource.watchAttachments(taskId);
  }

  @override
  Future<void> uploadAttachment(
    String taskId,
    String fileName,
    Uint8List fileBytes,
  ) async {
    await remoteDataSource.uploadAttachment(taskId, fileName, fileBytes);
  }

  @override
  Future<void> deleteAttachment(
    String taskId,
    Map<String, dynamic> fileData,
  ) async {
    await remoteDataSource.deleteAttachment(taskId, fileData);
  }
}
