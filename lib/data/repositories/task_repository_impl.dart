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

  @override
  Future<void> updateTask(TaskEntity task) async {
    // Chuyển đổi từ Entity (Logic) sang Model (Data) trước khi gửi đi
    final taskModel = TaskModel(
      taskId: task.taskId,
      projectId: task.projectId,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      dueDate: task.dueDate,
      assigneeId: task.assigneeId,
      assigneeName: task.assigneeName,
      assigneeAvatarUrl: task.assigneeAvatarUrl,
      createdAt: task.createdAt,
    );

    // Đẩy Model xuống Remote Data Source để cập nhật lên Firestore
    await remoteDataSource.updateTask(taskModel);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await remoteDataSource.deleteTask(taskId);
  }
}