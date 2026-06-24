import '../entities/ai_chat_message_entity.dart';

abstract class AiAssistantRepository {
  Future<AiChatMessageEntity> sendMessage(
    String message,
    String projectId,
    Map<String, dynamic> context,
    List<AiChatMessageEntity> conversationHistory,
  );

  Future<Map<String, dynamic>> runAction(
    String action,
    String projectId,
    Map<String, dynamic> context,
    List<AiChatMessageEntity> conversationHistory,
  );

  Future<String> summarizeChat(List<Map<String, String>> messages);

  Future<List<Map<String, dynamic>>> generateTasks(String prompt);
}
