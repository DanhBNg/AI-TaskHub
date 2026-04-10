import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project_model.dart';

abstract class ProjectRemoteDataSource {
  Stream<List<ProjectModel>> getProjectsByUser(String userId);
  Future<void> createProject(ProjectModel project);
}

class ProjectRemoteDataSourceImpl implements ProjectRemoteDataSource {
  final FirebaseFirestore firestore;

  ProjectRemoteDataSourceImpl({required this.firestore});

  @override
  Stream<List<ProjectModel>> getProjectsByUser(String userId) {
    // Lấy các dự án mà userId này nằm trong danh sách memberIds
    return firestore
        .collection('PROJECTS')
        .where('memberIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ProjectModel.fromFirestore(doc))
        .toList());
  }

  @override
  Future<void> createProject(ProjectModel project) async {
    final docRef = firestore.collection('PROJECTS').doc(); // Tự động tạo ID
    final newProject = ProjectModel(
      projectId: docRef.id,
      name: project.name,
      description: project.description,
      ownerId: project.ownerId,
      memberIds: project.memberIds,
      roles: project.roles,
      status: project.status,
      createdAt: project.createdAt,
    );
    await docRef.set(newProject.toJson());
  }
}