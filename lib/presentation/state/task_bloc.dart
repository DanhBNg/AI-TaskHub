import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/repositories/task_repository.dart';

// --- EVENTS ---
abstract class TaskEvent extends Equatable { @override List<Object> get props => []; }

class LoadTasks extends TaskEvent {
  final String projectId;
  LoadTasks(this.projectId);
}

class CreateTask extends TaskEvent {
  final TaskEntity task;
  CreateTask(this.task);
}

class UpdateTask extends TaskEvent {
  final TaskEntity task;
  UpdateTask(this.task);
  @override List<Object> get props => [task];
}

class DeleteTask extends TaskEvent {
  final String taskId;
  DeleteTask(this.taskId);
  @override List<Object> get props => [taskId];
}

class UpdateTaskStatus extends TaskEvent {
  final String taskId;
  final String newStatus;
  UpdateTaskStatus(this.taskId, this.newStatus);
}

// --- STATES ---
abstract class TaskState extends Equatable { @override List<Object> get props => []; }
class TaskLoading extends TaskState {}
class TaskLoaded extends TaskState {
  final List<TaskEntity> tasks;
  TaskLoaded(this.tasks);
  @override List<Object> get props => [tasks];
}
class TaskError extends TaskState {
  final String message;
  TaskError(this.message);
  @override List<Object> get props => [message];
}

// --- BLOC ---
class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskRepository taskRepository;

  TaskBloc({required this.taskRepository}) : super(TaskLoading()) {
    on<LoadTasks>((event, emit) async {
      emit(TaskLoading());
      await emit.forEach<List<TaskEntity>>(
        taskRepository.getTasksByProject(event.projectId),
        onData: (tasks) => TaskLoaded(tasks),
        onError: (error, stackTrace) => TaskError(error.toString()),
      );
    });

    on<CreateTask>((event, emit) async {
      try { await taskRepository.createTask(event.task); }
      catch (e) { emit(TaskError(e.toString())); }
    });

    on<UpdateTaskStatus>((event, emit) async {
      try { await taskRepository.updateTaskStatus(event.taskId, event.newStatus); }
      catch (e) { emit(TaskError(e.toString())); }
    });

    on<UpdateTask>((event, emit) async {
      try { await taskRepository.updateTask(event.task); }
      catch (e) { emit(TaskError(e.toString())); }
    });

    on<DeleteTask>((event, emit) async {
      try { await taskRepository.deleteTask(event.taskId); }
      catch (e) { emit(TaskError(e.toString())); }
    });
  }
}