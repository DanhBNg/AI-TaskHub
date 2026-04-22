import 'package:equatable/equatable.dart';

class TaskEntity extends Equatable {
  final String taskId;
  final String projectId;
  final String title;
  final String description;
  final String status;
  final String priority;
  final List<String> assigneeIds;
  final List<String> assigneeNames;
  final List<String> assigneeAvatarUrls;
  final DateTime? dueDate;
  final DateTime createdAt;

  const TaskEntity({
    required this.taskId,
    required this.projectId,
    required this.title,
    this.description = '',
    this.status = 'todo',
    this.priority = 'medium',
    required this.createdAt, this.dueDate, required this.assigneeIds, required this.assigneeNames, required this.assigneeAvatarUrls,
  });

  @override
  List<Object?> get props => [taskId, projectId, title, description, status, priority, assigneeIds, assigneeNames, assigneeAvatarUrls, dueDate, createdAt];
}