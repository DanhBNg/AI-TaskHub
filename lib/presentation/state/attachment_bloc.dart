import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/task_repository.dart';

abstract class AttachmentEvent extends Equatable {
  const AttachmentEvent();

  @override
  List<Object?> get props => [];
}

class LoadAttachments extends AttachmentEvent {
  final String taskId;

  const LoadAttachments(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class UploadAttachmentRequested extends AttachmentEvent {
  final String taskId;
  final String fileName;
  final Uint8List fileBytes;

  const UploadAttachmentRequested({
    required this.taskId,
    required this.fileName,
    required this.fileBytes,
  });

  @override
  List<Object?> get props => [taskId, fileName, fileBytes];
}

class DeleteAttachmentRequested extends AttachmentEvent {
  final String taskId;
  final Map<String, dynamic> fileData;

  const DeleteAttachmentRequested({
    required this.taskId,
    required this.fileData,
  });

  @override
  List<Object?> get props => [taskId, fileData];
}

class _AttachmentsUpdated extends AttachmentEvent {
  final String taskId;
  final List<Map<String, dynamic>> attachments;

  const _AttachmentsUpdated({required this.taskId, required this.attachments});

  @override
  List<Object?> get props => [taskId, attachments];
}

class _AttachmentsFailed extends AttachmentEvent {
  final String taskId;
  final String message;

  const _AttachmentsFailed({required this.taskId, required this.message});

  @override
  List<Object?> get props => [taskId, message];
}

abstract class AttachmentState extends Equatable {
  final String taskId;

  const AttachmentState({this.taskId = ''});

  @override
  List<Object?> get props => [taskId];
}

class AttachmentLoading extends AttachmentState {
  const AttachmentLoading({required super.taskId});
}

class AttachmentLoaded extends AttachmentState {
  final List<Map<String, dynamic>> attachments;

  const AttachmentLoaded({required super.taskId, required this.attachments});

  @override
  List<Object?> get props => [taskId, attachments];
}

class AttachmentActionSuccess extends AttachmentState {
  final String message;

  const AttachmentActionSuccess({required super.taskId, required this.message});

  @override
  List<Object?> get props => [taskId, message];
}

class AttachmentError extends AttachmentState {
  final String message;

  const AttachmentError({required super.taskId, required this.message});

  @override
  List<Object?> get props => [taskId, message];
}

class AttachmentBloc extends Bloc<AttachmentEvent, AttachmentState> {
  final TaskRepository taskRepository;
  StreamSubscription<List<Map<String, dynamic>>>? _attachmentsSubscription;

  AttachmentBloc({required this.taskRepository})
    : super(const AttachmentLoading(taskId: '')) {
    on<LoadAttachments>(_onLoadAttachments);
    on<UploadAttachmentRequested>(_onUploadAttachmentRequested);
    on<DeleteAttachmentRequested>(_onDeleteAttachmentRequested);
    on<_AttachmentsUpdated>(_onAttachmentsUpdated);
    on<_AttachmentsFailed>(_onAttachmentsFailed);
  }

  Future<void> _onLoadAttachments(
    LoadAttachments event,
    Emitter<AttachmentState> emit,
  ) async {
    await _attachmentsSubscription?.cancel();
    emit(AttachmentLoading(taskId: event.taskId));

    _attachmentsSubscription = taskRepository
        .watchAttachments(event.taskId)
        .listen(
          (attachments) => add(
            _AttachmentsUpdated(taskId: event.taskId, attachments: attachments),
          ),
          onError: (error) => add(
            _AttachmentsFailed(
              taskId: event.taskId,
              message: error.toString().replaceAll('Exception: ', ''),
            ),
          ),
        );
  }

  Future<void> _onUploadAttachmentRequested(
    UploadAttachmentRequested event,
    Emitter<AttachmentState> emit,
  ) async {
    await _handleAction(
      emit: emit,
      taskId: event.taskId,
      action: () => taskRepository.uploadAttachment(
        event.taskId,
        event.fileName,
        event.fileBytes,
      ),
      successMessage: '?? t?i t?p th?nh c?ng!',
    );
  }

  Future<void> _onDeleteAttachmentRequested(
    DeleteAttachmentRequested event,
    Emitter<AttachmentState> emit,
  ) async {
    await _handleAction(
      emit: emit,
      taskId: event.taskId,
      action: () => taskRepository.deleteAttachment(event.taskId, event.fileData),
      successMessage: '?? x?a t?p th?nh c?ng!',
    );
  }

  void _onAttachmentsUpdated(
    _AttachmentsUpdated event,
    Emitter<AttachmentState> emit,
  ) {
    emit(AttachmentLoaded(taskId: event.taskId, attachments: event.attachments));
  }

  void _onAttachmentsFailed(
    _AttachmentsFailed event,
    Emitter<AttachmentState> emit,
  ) {
    emit(AttachmentError(taskId: event.taskId, message: event.message));
  }

  Future<void> _handleAction({
    required Emitter<AttachmentState> emit,
    required String taskId,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    try {
      await action();
      final refreshedAttachments = await taskRepository.watchAttachments(taskId).first;
      emit(AttachmentActionSuccess(taskId: taskId, message: successMessage));
      emit(AttachmentLoaded(taskId: taskId, attachments: refreshedAttachments));
    } catch (e) {
      emit(
        AttachmentError(
          taskId: taskId,
          message: e.toString().replaceAll('Exception: ', ''),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _attachmentsSubscription?.cancel();
    return super.close();
  }
}
