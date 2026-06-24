import '../../domain/entities/ai_chat_message_entity.dart';
import '../../domain/repositories/ai_assistant_repository.dart';
import '../datasources/ai_assistant_remote_data_source.dart';

class AiAssistantRepositoryImpl implements AiAssistantRepository {
  final AiAssistantRemoteDataSource remoteDataSource;

  AiAssistantRepositoryImpl({required this.remoteDataSource});

  @override
  Future<AiChatMessageEntity> sendMessage(
    String message,
    String projectId,
    Map<String, dynamic> context,
    List<AiChatMessageEntity> conversationHistory,
  ) {
    return remoteDataSource.sendMessage(
      message,
      projectId,
      context,
      conversationHistory,
    );
  }

  @override
  Future<Map<String, dynamic>> runAction(
    String action,
    String projectId,
    Map<String, dynamic> context,
    List<AiChatMessageEntity> conversationHistory,
  ) {
    return remoteDataSource.runAction(
      action,
      projectId,
      context,
      conversationHistory,
    );
  }

  @override
  Future<String> summarizeChat(List<Map<String, String>> messages) {
    return remoteDataSource.summarizeChat(messages);
  }

  @override
  Future<List<Map<String, dynamic>>> generateTasks(String prompt) {
    return remoteDataSource.generateTasks(prompt);
  }
}
