import 'package:equatable/equatable.dart';

class TaskEntity extends Equatable {
  final String taskId;
  final String projectId;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String? assigneeId;
  final String? assigneeName;
  final String? assigneeAvatarUrl;
  final DateTime? dueDate;
  final DateTime createdAt;

  const TaskEntity({
    required this.taskId,
    required this.projectId,
    required this.title,
    this.description = '',
    this.status = 'todo',
    this.priority = 'medium',
    required this.createdAt, this.assigneeId, this.assigneeName, this.assigneeAvatarUrl, this.dueDate,
  });

  @override
  List<Object?> get props => [taskId, projectId, title, description, status, priority, assigneeId, assigneeName, assigneeAvatarUrl, dueDate, createdAt];
}