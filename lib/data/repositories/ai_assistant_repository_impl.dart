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
  ) {
    return remoteDataSource.sendMessage(message, projectId, context);
  }
}
