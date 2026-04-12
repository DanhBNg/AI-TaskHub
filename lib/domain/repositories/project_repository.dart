import '../entities/project_entity.dart';
import '../entities/invite_entity.dart';

abstract class ProjectRepository {

  Stream<List<ProjectEntity>> getProjectsByUser(String userId);

  Future<void> createProject(ProjectEntity project);

  Future<void> updateProject(ProjectEntity project);
  
  Future<void> deleteProject(String projectId);

  Future<void> addMemberByEmail(String projectId, String email);

  Stream<List<InviteEntity>> getPendingInvites(String userId);
  Future<void> respondToInvite(String inviteId, String projectId, String userId, bool isAccept);
}