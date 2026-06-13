import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../domain/entities/ai_chat_message_entity.dart';
import '../models/ai_chat_message_model.dart';

abstract class AiAssistantRemoteDataSource {
  Future<AiChatMessageModel> sendMessage(
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
}

class AiAssistantRemoteDataSourceImpl implements AiAssistantRemoteDataSource {
  final http.Client client;

  AiAssistantRemoteDataSourceImpl({required this.client});

  @override
  Future<AiChatMessageModel> sendMessage(
    String message,
    String projectId,
    Map<String, dynamic> context,
    List<AiChatMessageEntity> conversationHistory,
  ) async {
    try {
      final response = await client.post(
        AppConfig.apiUri('/api/assistant/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userMessage': message,
          'projectId': projectId,
          'context': context,
          'conversationHistory': conversationHistory
              .map(
                (message) => {
                  'role': message.role,
                  'content': message.content,
                  'timestamp': message.timestamp.toIso8601String(),
                },
              )
              .toList(),
        }),
      );

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(decoded['error'] ?? 'Server AI tra ve loi');
      }

      return AiChatMessageModel.fromJson({
        'role': 'model',
        'content': decoded['reply'],
        'suggestedActions': decoded['suggestedActions'] ?? [],
      });
    } catch (e) {
      throw Exception('Khong the goi tro ly AI: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> runAction(
    String action,
    String projectId,
    Map<String, dynamic> context,
    List<AiChatMessageEntity> conversationHistory,
  ) async {
    try {
      final response = await client.post(
        AppConfig.apiUri('/api/assistant/action'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': action,
          'projectId': projectId,
          'context': context,
          'conversationHistory': conversationHistory
              .map(
                (message) => {
                  'role': message.role,
                  'content': message.content,
                  'timestamp': message.timestamp.toIso8601String(),
                },
              )
              .toList(),
        }),
      );

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(decoded['error'] ?? 'Server AI tra ve loi');
      }

      return decoded;
    } catch (e) {
      throw Exception('Khong the chay hanh dong AI: $e');
    }
  }
}
