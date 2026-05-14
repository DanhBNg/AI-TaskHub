import 'package:equatable/equatable.dart';

class AiChatMessageEntity extends Equatable {
  final String messageId;
  final String role;
  final String content;
  final DateTime timestamp;
  final List<String> suggestedActions;

  const AiChatMessageEntity({
    required this.messageId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.suggestedActions = const [],
  });

  bool get isUser => role == 'user';

  @override
  List<Object?> get props => [
        messageId,
        role,
        content,
        timestamp,
        suggestedActions,
      ];
}
