import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/invite_entity.dart';
import '../../domain/repositories/project_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- EVENTS ---
abstract class InviteEvent extends Equatable { @override List<Object> get props => []; }
class LoadInvites extends InviteEvent {}
class RespondToInvite extends InviteEvent {
  final String inviteId;
  final String projectId;
  final bool isAccept;
  RespondToInvite(this.inviteId, this.projectId, this.isAccept);
}

// --- STATES ---
abstract class InviteState extends Equatable { @override List<Object> get props => []; }
class InviteLoading extends InviteState {}
class InviteLoaded extends InviteState {
  final List<InviteEntity> invites;
  InviteLoaded(this.invites);
  @override List<Object> get props => [invites];
}

// --- BLOC ---
class InviteBloc extends Bloc<InviteEvent, InviteState> {
  final ProjectRepository projectRepository;

  InviteBloc({required this.projectRepository}) : super(InviteLoading()) {
    on<LoadInvites>((event, emit) async {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (userId.isEmpty) return;

      await emit.forEach<List<InviteEntity>>(
        projectRepository.getPendingInvites(userId),
        onData: (invites) => InviteLoaded(invites),
        onError: (error, stackTrace) => InviteLoaded(const []),
      );
    });

    on<RespondToInvite>((event, emit) async {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      await projectRepository.respondToInvite(event.inviteId, event.projectId, userId, event.isAccept);
    });
  }
}