import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/project_entity.dart';

class ProjectModel extends ProjectEntity {
  const ProjectModel({
    required super.projectId,
    required super.name,
    super.description,
    required super.ownerId,
    required super.memberIds,
    required super.roles,
    super.status,
    required super.createdAt,
  });

  factory ProjectModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProjectModel(
      projectId: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      ownerId: data['ownerId'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      roles: Map<String, dynamic>.from(data['roles'] ?? {}),
      status: data['status'] ?? 'active',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'roles': roles,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}