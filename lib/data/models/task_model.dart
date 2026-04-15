import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/task_entity.dart';

class TaskModel extends TaskEntity {
  const TaskModel({
    required super.taskId,
    required super.projectId,
    required super.title,
    super.description,
    super.status,
    super.priority,
    super.dueDate,
    required super.createdAt, required super.assigneeIds, required super.assigneeNames, required super.assigneeAvatarUrls,
  });

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TaskModel(
      taskId: doc.id,
      projectId: data['projectId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: data['status'] ?? 'todo',
      priority: data['priority'] ?? 'medium',
      assigneeIds: List<String>.from(data['assigneeIds'] ?? []),
      assigneeNames: List<String>.from(data['assigneeNames'] ?? []),
      assigneeAvatarUrls: List<String>.from(data['assigneeAvatarUrls'] ?? []),
      dueDate: data['dueDate'] != null ? (data['dueDate'] as Timestamp).toDate() : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'projectId': projectId,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'assigneeIds': assigneeIds,
      'assigneeNames': assigneeNames,
      'assigneeAvatarUrls': assigneeAvatarUrls,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}