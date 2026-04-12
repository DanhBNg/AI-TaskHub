import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/project_entity.dart';
import '../../domain/repositories/project_repository.dart';

// --- EVENTS ---
abstract class ProjectEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class LoadProjects extends ProjectEvent {
  final String userId;
  LoadProjects(this.userId);
}

class CreateProject extends ProjectEvent {
  final ProjectEntity project;
  CreateProject(this.project);
}

class AddMember extends ProjectEvent {
  final String projectId;
  final String email;
  AddMember(this.projectId, this.email);
}

// --- STATES ---
abstract class ProjectState extends Equatable {
  @override
  List<Object> get props => [];
}

class ProjectLoading extends ProjectState {}

class ProjectLoaded extends ProjectState {
  final List<ProjectEntity> projects;
  ProjectLoaded(this.projects);
  @override
  List<Object> get props => [projects];
}

class ProjectError extends ProjectState {
  final String message;
  ProjectError(this.message);
  @override
  List<Object> get props => [message];
}

class ProjectActionSuccess extends ProjectState {
  final String message;
  ProjectActionSuccess(this.message);
}

// --- BLOC ---
class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final ProjectRepository projectRepository;

  ProjectBloc({required this.projectRepository}) : super(ProjectLoading()) {

    // Lắng nghe Stream danh sách dự án
    on<LoadProjects>((event, emit) async {
      emit(ProjectLoading());
      await emit.forEach<List<ProjectEntity>>(
        projectRepository.getProjectsByUser(event.userId),
        onData: (projects) => ProjectLoaded(projects),
        onError: (error, stackTrace) => ProjectError(error.toString()),
      );
    });

    // Tạo dự án mới
    on<CreateProject>((event, emit) async {
      try {
        await projectRepository.createProject(event.project);
        // Không cần emit trạng thái mới vì hàm LoadProjects đã lắng nghe Stream (tự động cập nhật)
      } catch (e) {
        emit(ProjectError(e.toString()));
      }
    });

    //thêm mem
    on<AddMember>((event, emit) async {
      final currentState = state; // 1. Lưu lại trạng thái danh sách dự án hiện tại
      try {
        await projectRepository.addMemberByEmail(event.projectId, event.email);
        emit(ProjectActionSuccess('Đã gửi lời mời thêm thành viên!'));
      } catch (e) {
        emit(ProjectError(e.toString().replaceAll('Exception: ', '')));
      }
      if (currentState is ProjectLoaded) {
        emit(currentState);
      }
    });
  }
}