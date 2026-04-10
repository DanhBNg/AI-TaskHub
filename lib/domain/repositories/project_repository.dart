import '../entities/project_entity.dart';

abstract class ProjectRepository {

  Stream<List<ProjectEntity>> getProjectsByUser(String userId);

  Future<void> createProject(ProjectEntity project);

  Future<void> updateProject(ProjectEntity project);
  
  Future<void> deleteProject(String projectId);
}