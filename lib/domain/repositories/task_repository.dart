import '../entities/task_entity.dart';

abstract class TaskRepository {
  Stream<List<TaskEntity>> getTasksByProject(String projectId);
  Future<void> createTask(TaskEntity task);
  Future<void> updateTaskStatus(String taskId, String newStatus);
}