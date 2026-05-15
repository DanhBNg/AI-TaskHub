import 'package:equatable/equatable.dart';

class InviteEntity extends Equatable {
  final String inviteId;
  final String projectId;
  final String projectName;
  final String senderName;
  final String receiverId;
  final DateTime createdAt;

  const InviteEntity({
    required this.inviteId,
    required this.projectId,
    required this.projectName,
    required this.senderName,
    required this.receiverId,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [inviteId, projectId, projectName, senderName, receiverId, createdAt];
}