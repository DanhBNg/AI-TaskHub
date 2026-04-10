import 'package:equatable/equatable.dart';

class ProjectEntity extends Equatable {
  final String projectId;
  final String name;
  final String description;
  final String ownerId;
  final List<String> memberIds;
  final Map<String, dynamic> roles;
  final String status; 
  final DateTime createdAt;

  const ProjectEntity({
    required this.projectId,
    required this.name,
    this.description = '',
    required this.ownerId,
    required this.memberIds,
    required this.roles,
    this.status = 'active',
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    projectId,
    name,
    description,
    ownerId,
    memberIds,
    roles,
    status,
    createdAt,
  ];
}