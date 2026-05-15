import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/invite_model.dart';

abstract class ProjectRemoteDataSource {
  Stream<List<ProjectModel>> getProjectsByUser(String userId);
  Future<void> createProject(ProjectModel project);
  Future<void> addMemberByEmail(String projectId, String email);
  Stream<List<InviteModel>> getPendingInvites(String userId);
  Future<void> respondToInvite(String inviteId, String projectId, String userId, bool isAccept);
}

class ProjectRemoteDataSourceImpl implements ProjectRemoteDataSource {
  final FirebaseFirestore firestore;

  ProjectRemoteDataSourceImpl({required this.firestore});

  @override
  Stream<List<ProjectModel>> getProjectsByUser(String userId) {
    return firestore
        .collection('PROJECTS')
        .where('memberIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ProjectModel.fromFirestore(doc)).toList());
  }

  @override
  Future<void> createProject(ProjectModel project) async {
    final docRef = firestore.collection('PROJECTS').doc();
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

  // Gửi lời mời
  @override
  Future<void> addMemberByEmail(String projectId, String email) async {
    // Tìm user theo email
    final userQuery = await firestore.collection('USERS').where('email', isEqualTo: email.trim()).limit(1).get();
    if (userQuery.docs.isEmpty) throw Exception('Không tìm thấy người dùng nào với Email này!');
    final receiverId = userQuery.docs.first.id;

    // Check xem đã ở trong dự án chưa
    final projectDoc = await firestore.collection('PROJECTS').doc(projectId).get();
    List<dynamic> currentMembers = projectDoc.data()?['memberIds'] ?? [];
    if (currentMembers.contains(receiverId)) throw Exception('Người này đã là thành viên của dự án!');

    final currentUser = FirebaseAuth.instance.currentUser!;

    final existingInvite = await firestore.collection('INVITATIONS')
        .where('projectId', isEqualTo: projectId)
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existingInvite.docs.isNotEmpty) {
      throw Exception('Bạn đã gửi lời mời cho người này rồi, vui lòng chờ họ đồng ý!');
    }

    await firestore.collection('INVITATIONS').doc().set({
      'projectId': projectId,
      'projectName': projectDoc.data()?['name'] ?? 'Dự án',
      'senderName': currentUser.displayName ?? currentUser.email?.split('@')[0],
      'receiverId': receiverId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<InviteModel>> getPendingInvites(String userId) {
    return firestore.collection('INVITATIONS')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {

      List<InviteModel> invites = snapshot.docs.map((doc) => InviteModel.fromFirestore(doc)).toList();

      invites.sort((InviteModel a, InviteModel b) => b.createdAt.compareTo(a.createdAt));

      return invites;
    });
  }

  Future<void> respondToInvite(String inviteId, String projectId, String userId, bool isAccept) async {
    if (isAccept) {
      await firestore.collection('PROJECTS').doc(projectId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
        'roles.$userId': 'member',
      });
    }
    final duplicateInvites = await firestore.collection('INVITATIONS')
        .where('projectId', isEqualTo: projectId)
        .where('receiverId', isEqualTo: userId)
        .get();
    final batch = firestore.batch();
    for (var doc in duplicateInvites.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}