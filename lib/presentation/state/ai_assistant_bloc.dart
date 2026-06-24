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

class RunAssistantActionEvent extends AiAssistantEvent {
  final String action;
  final String projectId;
  final Map<String, dynamic> context;

  RunAssistantActionEvent({
    required this.action,
    required this.projectId,
    required this.context,
  });

  @override
  List<Object?> get props => [action, projectId, context];
}

class SummarizeChatEvent extends AiAssistantEvent {
  final List<Map<String, String>> messages;

  SummarizeChatEvent({required this.messages});

  @override
  List<Object?> get props => [messages];
}

class GenerateTasksEvent extends AiAssistantEvent {
  final String prompt;

  GenerateTasksEvent({required this.prompt});

  @override
  List<Object?> get props => [prompt];
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

class AiAssistantActionReady extends AiAssistantState {
  final String action;
  final Map<String, dynamic> payload;

  const AiAssistantActionReady({
    required super.messages,
    required this.action,
    required this.payload,
  });

  @override
  List<Object?> get props => [messages, action, payload];
}

class AiAssistantSummaryReady extends AiAssistantState {
  final String summary;

  const AiAssistantSummaryReady({
    required this.summary,
    required super.messages,
  });

  @override
  List<Object?> get props => [messages, summary];
}

class AiAssistantTasksGenerated extends AiAssistantState {
  final List<Map<String, dynamic>> generatedTasks;

  const AiAssistantTasksGenerated({
    required this.generatedTasks,
    required super.messages,
  });

  @override
  List<Object?> get props => [messages, generatedTasks];
}

class AiAssistantError extends AiAssistantState {
  final String error;

  const AiAssistantError({required this.error, required super.messages});

  @override
  List<Object?> get props => [error, messages];
}

class AiAssistantBloc extends Bloc<AiAssistantEvent, AiAssistantState> {
  final AiAssistantRepository aiAssistantRepository;

  AiAssistantBloc({required this.aiAssistantRepository})
    : super(const AiAssistantInitial()) {
    on<SendMessageEvent>((event, emit) async {
      final conversationHistory = state.messages.length <= 8
          ? state.messages
          : state.messages.sublist(state.messages.length - 8);

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
          conversationHistory,
        );
        emit(AiAssistantLoaded(messages: [...updatedMessages, aiReply]));
      } catch (e) {
        emit(
          AiAssistantError(
            error: e.toString().replaceAll('Exception: ', ''),
            messages: updatedMessages,
          ),
        );
      }
    });

    on<RunAssistantActionEvent>((event, emit) async {
      final conversationHistory = state.messages.length <= 8
          ? state.messages
          : state.messages.sublist(state.messages.length - 8);

      emit(AiAssistantLoading(messages: state.messages));

      try {
        final payload = await aiAssistantRepository.runAction(
          event.action,
          event.projectId,
          event.context,
          conversationHistory,
        );

        if (event.action == 'SUMMARIZE' ||
            event.action == 'FIND_TASK' ||
            event.action == 'PRIORITIZE') {
          final content = _formatActionReply(event.action, payload);
          final aiReply = AiChatMessageEntity(
            messageId: DateTime.now().microsecondsSinceEpoch.toString(),
            role: 'model',
            content: content,
            timestamp: DateTime.now(),
          );
          emit(AiAssistantLoaded(messages: [...state.messages, aiReply]));
          return;
        }

        emit(
          AiAssistantActionReady(
            messages: state.messages,
            action: event.action,
            payload: payload,
          ),
        );
      } catch (e) {
        emit(
          AiAssistantError(
            error: e.toString().replaceAll('Exception: ', ''),
            messages: state.messages,
          ),
        );
      }
    });

    on<SummarizeChatEvent>((event, emit) async {
      emit(AiAssistantLoading(messages: state.messages));

      try {
        final summary = await aiAssistantRepository.summarizeChat(
          event.messages,
        );
        emit(
          AiAssistantSummaryReady(summary: summary, messages: state.messages),
        );
      } catch (e) {
        emit(
          AiAssistantError(
            error: e.toString().replaceAll('Exception: ', ''),
            messages: state.messages,
          ),
        );
      }
    });

    on<GenerateTasksEvent>((event, emit) async {
      emit(AiAssistantLoading(messages: state.messages));

      try {
        final tasks = await aiAssistantRepository.generateTasks(event.prompt);
        emit(
          AiAssistantTasksGenerated(
            generatedTasks: tasks,
            messages: state.messages,
          ),
        );
      } catch (e) {
        emit(
          AiAssistantError(
            error: e.toString().replaceAll('Exception: ', ''),
            messages: state.messages,
          ),
        );
      }
    });
  }

  String _formatActionReply(String action, Map<String, dynamic> payload) {
    if (action == 'SUMMARIZE') {
      final summary = (payload['summary'] ?? '').toString().trim();
      return summary.isEmpty ? 'Chưa đủ dữ liệu để tóm tắt.' : summary;
    }

    if (action == 'FIND_TASK') {
      final reply = (payload['reply'] ?? '').toString().trim();
      final tasks = _readTaskInsightList(payload['tasks']);

      if (tasks.isEmpty) {
        return reply.isEmpty
            ? 'Chưa tìm thấy task phù hợp trong dữ liệu hiện tại.'
            : reply;
      }

      final buffer = StringBuffer(
        reply.isEmpty ? 'Tôi tìm thấy các task phù hợp:' : reply,
      );

      for (final task in tasks) {
        buffer
          ..writeln()
          ..writeln()
          ..write('- ${task['title']}');

        final projectName = (task['projectName'] ?? '').toString().trim();
        final status = (task['status'] ?? '').toString().trim();
        final priority = (task['priority'] ?? '').toString().trim();
        final dueDate = (task['dueDate'] ?? '').toString().trim();
        final reason = (task['reason'] ?? '').toString().trim();
        final meta = [
          if (projectName.isNotEmpty) projectName,
          if (status.isNotEmpty) status,
          if (priority.isNotEmpty) priority,
          if (dueDate.isNotEmpty) dueDate,
        ];

        if (meta.isNotEmpty) buffer.write(' (${meta.join(' | ')})');
        if (reason.isNotEmpty) buffer.write('\n  Lý do: $reason');
      }

      return buffer.toString();
    }

    final reply = (payload['reply'] ?? '').toString().trim();
    final tasks = _readTaskInsightList(payload['prioritizedTasks']);

    if (tasks.isEmpty) {
      return reply.isEmpty ? 'Chưa đủ dữ liệu để sắp xếp ưu tiên task.' : reply;
    }

    final buffer = StringBuffer(
      reply.isEmpty ? 'Thứ tự task nên ưu tiên:' : reply,
    );

    for (var index = 0; index < tasks.length; index++) {
      final task = tasks[index];
      final rank = task['rank'] ?? index + 1;
      final reason = (task['reason'] ?? '').toString().trim();
      final priority = (task['priority'] ?? '').toString().trim();
      final status = (task['status'] ?? '').toString().trim();
      final dueDate = (task['dueDate'] ?? '').toString().trim();
      final meta = [
        if (priority.isNotEmpty) priority,
        if (status.isNotEmpty) status,
        if (dueDate.isNotEmpty) dueDate,
      ];

      buffer
        ..writeln()
        ..writeln()
        ..write('$rank. ${task['title']}');

      if (meta.isNotEmpty) buffer.write(' (${meta.join(' | ')})');
      if (reason.isNotEmpty) buffer.write('\n   Vì: $reason');
    }

    return buffer.toString();
  }

  List<Map<String, dynamic>> _readTaskInsightList(dynamic rawTasks) {
    if (rawTasks is! List) return [];

    return rawTasks
        .whereType<Map>()
        .map((task) => Map<String, dynamic>.from(task))
        .toList();
  }
}
