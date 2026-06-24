import '../../domain/entities/invite_entity.dart';
import '../../domain/entities/project_entity.dart';
import '../../domain/repositories/project_repository.dart';
import '../datasources/project_remote_data_source.dart';
import '../models/project_model.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  final ProjectRemoteDataSource remoteDataSource;

  ProjectRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<ProjectEntity>> getProjectsByUser(String userId) {
    return remoteDataSource.getProjectsByUser(userId);
  }

  @override
  Future<void> createProject(ProjectEntity project) async {
    final projectModel = ProjectModel(
      projectId: project.projectId,
      name: project.name,
      description: project.description,
      ownerId: project.ownerId,
      memberIds: project.memberIds,
      roles: project.roles,
      status: project.status,
      createdAt: project.createdAt,
    );
    await remoteDataSource.createProject(projectModel);
  }

  @override
  Future<void> updateProject(ProjectEntity project) async {
    final projectModel = ProjectModel(
      projectId: project.projectId,
      name: project.name,
      description: project.description,
      ownerId: project.ownerId,
      memberIds: project.memberIds,
      roles: project.roles,
      status: project.status,
      createdAt: project.createdAt,
    );
    await remoteDataSource.updateProject(projectModel);
  }

  @override
  Future<void> deleteProject(String projectId) async {
    await remoteDataSource.deleteProject(projectId);
  }

  @override
  Future<void> addMemberByEmail(String projectId, String email) async {
    await remoteDataSource.addMemberByEmail(projectId, email);
  }

  @override
  Future<void> updateMemberRole(
    String projectId,
    String userId,
    String newRole,
  ) async {
    await remoteDataSource.updateMemberRole(projectId, userId, newRole);
  }

  @override
  Future<void> removeMember(String projectId, String userId) async {
    await remoteDataSource.removeMember(projectId, userId);
  }

  @override
  Stream<List<InviteEntity>> getPendingInvites(String userId) {
    return remoteDataSource.getPendingInvites(userId);
  }

  @override
  Future<void> respondToInvite(
    String inviteId,
    String projectId,
    String userId,
    bool isAccept,
  ) async {
    await remoteDataSource.respondToInvite(
      inviteId,
      projectId,
      userId,
      isAccept,
    );
  }
}
