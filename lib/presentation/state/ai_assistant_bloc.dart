import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/ai_chat_message_entity.dart';
import '../../domain/repositories/ai_assistant_repository.dart';

abstract class AiAssistantEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SendMessageEvent extends AiAssistantEvent {
  final String message;
  final String projectId;
  final Map<String, dynamic> context;

  SendMessageEvent({
    required this.message,
    required this.projectId,
    required this.context,
  });

  @override
  List<Object?> get props => [message, projectId, context];
}

abstract class AiAssistantState extends Equatable {
  final List<AiChatMessageEntity> messages;

  const AiAssistantState({this.messages = const []});

  @override
  List<Object?> get props => [messages];
}

class AiAssistantInitial extends AiAssistantState {
  const AiAssistantInitial() : super(messages: const []);
}

class AiAssistantLoading extends AiAssistantState {
  const AiAssistantLoading({required super.messages});
}

class AiAssistantLoaded extends AiAssistantState {
  const AiAssistantLoaded({required super.messages});
}

class AiAssistantError extends AiAssistantState {
  final String error;

  const AiAssistantError({
    required this.error,
    required super.messages,
  });

  @override
  List<Object?> get props => [error, messages];
}

class AiAssistantBloc extends Bloc<AiAssistantEvent, AiAssistantState> {
  final AiAssistantRepository aiAssistantRepository;

  AiAssistantBloc({required this.aiAssistantRepository})
      : super(const AiAssistantInitial()) {
    on<SendMessageEvent>((event, emit) async {
      final userMessage = AiChatMessageEntity(
        messageId: DateTime.now().microsecondsSinceEpoch.toString(),
        role: 'user',
        content: event.message,
        timestamp: DateTime.now(),
      );

      final updatedMessages = [...state.messages, userMessage];
      emit(AiAssistantLoading(messages: updatedMessages));

      try {
        final aiReply = await aiAssistantRepository.sendMessage(
          event.message,
          event.projectId,
          event.context,
        );
        emit(AiAssistantLoaded(messages: [...updatedMessages, aiReply]));
      } catch (e) {
        emit(AiAssistantError(
          error: e.toString().replaceAll('Exception: ', ''),
          messages: updatedMessages,
        ));
      }
    });
  }
}
