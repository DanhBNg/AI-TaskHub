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

  Future<String> summarizeChat(List<Map<String, String>> messages);

  Future<List<Map<String, dynamic>>> generateTasks(String prompt);
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
        throw Exception(decoded['error'] ?? 'Server AI trả về lỗi');
      }

      return AiChatMessageModel.fromJson({
        'role': 'model',
        'content': decoded['reply'],
        'suggestedActions': decoded['suggestedActions'] ?? [],
      });
    } catch (e) {
      throw Exception('Không thể gọi trợ lý AI: $e');
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
        throw Exception(decoded['error'] ?? 'Server AI trả về lỗi');
      }

      return decoded;
    } catch (e) {
      throw Exception('Không thể chạy hành động AI: $e');
    }
  }

  @override
  Future<String> summarizeChat(List<Map<String, String>> messages) async {
    try {
      final response = await client.post(
        AppConfig.apiUri('/api/summarize-chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'messages': messages}),
      );

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(decoded['error'] ?? 'Server AI trả về lỗi');
      }

      return (decoded['summary'] ?? '').toString();
    } catch (e) {
      throw Exception('Không thể tóm tắt hội thoại: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> generateTasks(String prompt) async {
    try {
      final response = await client.post(
        AppConfig.apiUri('/api/generate-tasks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      );

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(decoded['error'] ?? 'Server AI trả về lỗi');
      }

      final rawTasks = decoded['tasks'];
      if (rawTasks is! List) return <Map<String, dynamic>>[];

      return rawTasks
          .whereType<Map>()
          .map((task) => Map<String, dynamic>.from(task))
          .toList();
    } catch (e) {
      throw Exception('Không thể sinh task từ AI: $e');
    }
  }
}
