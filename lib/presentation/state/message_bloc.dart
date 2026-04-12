import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/message_repository.dart';
import 'dart:typed_data';

// --- EVENTS ---
abstract class MessageEvent extends Equatable { @override List<Object> get props => []; }

class LoadMessages extends MessageEvent {
  final String taskId;
  LoadMessages(this.taskId);
}

class SendMessage extends MessageEvent {
  final MessageEntity message;
  final Uint8List? imageBytes;
  SendMessage(this.message, {this.imageBytes});
}

// --- STATES ---
abstract class MessageState extends Equatable { @override List<Object> get props => []; }
class MessageLoading extends MessageState {}
class MessageLoaded extends MessageState {
  final List<MessageEntity> messages;
  MessageLoaded(this.messages);
  @override List<Object> get props => [messages];
}
class MessageError extends MessageState {
  final String error;
  MessageError(this.error);
  @override List<Object> get props => [error];
}

// --- BLOC ---
class MessageBloc extends Bloc<MessageEvent, MessageState> {
  final MessageRepository messageRepository;

  MessageBloc({required this.messageRepository}) : super(MessageLoading()) {
    on<LoadMessages>((event, emit) async {
      emit(MessageLoading());
      await emit.forEach<List<MessageEntity>>(
        messageRepository.getMessagesByTask(event.taskId),
        onData: (messages) => MessageLoaded(messages),
        onError: (error, stackTrace) => MessageError(error.toString()),
      );
    });

    on<SendMessage>((event, emit) async {
      final currentState = state;

      try {
        await messageRepository.sendMessage(event.message, imageBytes: event.imageBytes);
      } catch (e) {
        emit(MessageError(e.toString()));

        if (currentState is MessageLoaded) {
          emit(currentState);
        }
      }
    });
  }
}