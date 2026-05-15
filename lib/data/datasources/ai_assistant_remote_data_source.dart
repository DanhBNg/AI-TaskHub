import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_chat_message_model.dart';

abstract class AiAssistantRemoteDataSource {
  Future<AiChatMessageModel> sendMessage(
    String message,
    String projectId,
    Map<String, dynamic> context,
  );
}

class AiAssistantRemoteDataSourceImpl implements AiAssistantRemoteDataSource {
  static const String _baseUrl = 'https://taskhub-backend-ords.onrender.com';
  final http.Client client;

  AiAssistantRemoteDataSourceImpl({required this.client});

  @override
  Future<AiChatMessageModel> sendMessage(
    String message,
    String projectId,
    Map<String, dynamic> context,
  ) async {
    try {
      final response = await client.post(
        Uri.parse('$_baseUrl/api/assistant/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userMessage': message,
          'projectId': projectId,
          'context': context,
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
}
