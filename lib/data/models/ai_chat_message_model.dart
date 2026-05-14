import '../../domain/entities/ai_chat_message_entity.dart';

class AiChatMessageModel extends AiChatMessageEntity {
  const AiChatMessageModel({
    required super.messageId,
    required super.role,
    required super.content,
    required super.timestamp,
    super.suggestedActions,
  });

  factory AiChatMessageModel.fromJson(Map<String, dynamic> json) {
    return AiChatMessageModel(
      messageId: json['messageId']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      role: json['role']?.toString() ?? 'model',
      content: json['content']?.toString() ?? json['reply']?.toString() ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      suggestedActions: List<String>.from(json['suggestedActions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'suggestedActions': suggestedActions,
    };
  }
}
