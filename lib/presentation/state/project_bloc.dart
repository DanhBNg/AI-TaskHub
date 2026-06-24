import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/project_entity.dart';
import '../../domain/repositories/project_repository.dart';

abstract class ProjectEvent extends Equatable {
  const ProjectEvent();

  @override
  List<Object?> get props => [];
}

class LoadProjects extends ProjectEvent {
  final String userId;

  const LoadProjects(this.userId);

  @override
  List<Object?> get props => [userId];
}

class CreateProject extends ProjectEvent {
  final ProjectEntity project;

  const CreateProject(this.project);

  @override
  List<Object?> get props => [project];
}

class AddMember extends ProjectEvent {
  final String projectId;
  final String email;

  const AddMember(this.projectId, this.email);

  @override
  List<Object?> get props => [projectId, email];
}

class UpdateProjectRequested extends ProjectEvent {
  final ProjectEntity project;

  const UpdateProjectRequested(this.project);

  @override
  List<Object?> get props => [project];
}

class DeleteProjectRequested extends ProjectEvent {
  final String projectId;

  const DeleteProjectRequested(this.projectId);

  @override
  List<Object?> get props => [projectId];
}

class UpdateMemberRoleRequested extends ProjectEvent {
  final String projectId;
  final String userId;
  final String newRole;

  const UpdateMemberRoleRequested(this.projectId, this.userId, this.newRole);

  @override
  List<Object?> get props => [projectId, userId, newRole];
}

class RemoveMemberRequested extends ProjectEvent {
  final String projectId;
  final String userId;

  const RemoveMemberRequested(this.projectId, this.userId);

  @override
  List<Object?> get props => [projectId, userId];
}

abstract class ProjectState extends Equatable {
  const ProjectState();

  @override
  List<Object?> get props => [];
}

class ProjectLoading extends ProjectState {}

class ProjectLoaded extends ProjectState {
  final List<ProjectEntity> projects;

  const ProjectLoaded(this.projects);

  @override
  List<Object?> get props => [projects];
}

class ProjectError extends ProjectState {
  final String message;

  const ProjectError(this.message);

  @override
  List<Object?> get props => [message];
}

class ProjectActionSuccess extends ProjectState {
  final String message;

  const ProjectActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final ProjectRepository projectRepository;

  ProjectBloc({required this.projectRepository}) : super(ProjectLoading()) {
    on<LoadProjects>((event, emit) async {
      emit(ProjectLoading());
      await emit.forEach<List<ProjectEntity>>(
        projectRepository.getProjectsByUser(event.userId),
        onData: (projects) => ProjectLoaded(projects),
        onError: (error, _) => ProjectError(error.toString()),
      );
    });

    on<CreateProject>((event, emit) async {
      try {
        await projectRepository.createProject(event.project);
      } catch (e) {
        emit(ProjectError(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<AddMember>((event, emit) async {
      await _handleAction(
        emit,
        () => projectRepository.addMemberByEmail(event.projectId, event.email),
        'Đã gửi lời mời thêm thành viên!',
      );
    });

    on<UpdateProjectRequested>((event, emit) async {
      await _handleAction(
        emit,
        () => projectRepository.updateProject(event.project),
        'Đã cập nhật dự án thành công!',
      );
    });

    on<DeleteProjectRequested>((event, emit) async {
      await _handleAction(
        emit,
        () => projectRepository.deleteProject(event.projectId),
        'Đã xóa dự án thành công!',
      );
    });

    on<UpdateMemberRoleRequested>((event, emit) async {
      await _handleAction(
        emit,
        () => projectRepository.updateMemberRole(
          event.projectId,
          event.userId,
          event.newRole,
        ),
        'Đã cập nhật quyền thành viên!',
      );
    });

    on<RemoveMemberRequested>((event, emit) async {
      await _handleAction(
        emit,
        () => projectRepository.removeMember(event.projectId, event.userId),
        'Đã xóa thành viên khỏi dự án!',
      );
    });
  }

  Future<void> _handleAction(
    Emitter<ProjectState> emit,
    Future<void> Function() action,
    String successMessage,
  ) async {
    final currentState = state;
    try {
      await action();
      emit(ProjectActionSuccess(successMessage));
    } catch (e) {
      emit(ProjectError(e.toString().replaceAll('Exception: ', '')));
    }

    if (currentState is ProjectLoaded) {
      emit(currentState);
    }
  }
}
