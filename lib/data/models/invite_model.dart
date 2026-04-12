import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/invite_entity.dart';

class InviteModel extends InviteEntity {
  const InviteModel({
    required super.inviteId,
    required super.projectId,
    required super.projectName,
    required super.senderName,
    required super.receiverId,
    required super.createdAt,
  });

  factory InviteModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return InviteModel(
      inviteId: doc.id,
      projectId: data['projectId'] ?? '',
      projectName: data['projectName'] ?? '',
      senderName: data['senderName'] ?? '',
      receiverId: data['receiverId'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}