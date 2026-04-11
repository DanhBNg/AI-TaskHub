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
    // Tạo ID duy nhất dựa trên thời gian thực
    final newTaskId = DateTime.now().millisecondsSinceEpoch.toString();

    final taskModel = TaskModel(
      taskId: newTaskId,
      projectId: task.projectId,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      createdAt: task.createdAt,
    );

    // Data Source gọi Firebase
    await remoteDataSource.createTask(taskModel);
  }

  @override
  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    await remoteDataSource.updateTaskStatus(taskId, newStatus);
  }

  String firestoreId() => DateTime.now().millisecondsSinceEpoch.toString();
}