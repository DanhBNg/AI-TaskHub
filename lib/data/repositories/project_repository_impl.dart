import '../../domain/entities/project_entity.dart';
import '../../domain/repositories/project_repository.dart';
import '../datasources/project_remote_data_source.dart';
import '../models/project_model.dart';
import '../../domain/entities/invite_entity.dart';


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
      createdAt: project.createdAt,
    );
    await remoteDataSource.createProject(projectModel);
  }

  @override
  Future<void> updateProject(ProjectEntity project) async {
    // Implement later cho chức năng sửa
  }

  @override
  Future<void> deleteProject(String projectId) async {
    // Implement later cho chức năng xóa
  }

  @override
  Future<void> addMemberByEmail(String projectId, String email) async{
    await remoteDataSource.addMemberByEmail(projectId, email);
  }

  @override
  Stream<List<InviteEntity>> getPendingInvites(String userId) {
    // Gọi Data Source (nó trả về Model, nhưng vì Model kế thừa Entity nên hợp lệ)
    return remoteDataSource.getPendingInvites(userId);
  }

  @override
  Future<void> respondToInvite(String inviteId, String projectId, String userId, bool isAccept) async {
    await remoteDataSource.respondToInvite(inviteId, projectId, userId, isAccept);
  }
}