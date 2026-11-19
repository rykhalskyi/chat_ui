import 'chat_role.dart';

enum MessageStatus {
  complete,
  streaming,
  stopped,
  error;

  static MessageStatus fromName(String value) {
    return MessageStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => MessageStatus.complete,
    );
  }
}

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.seq,
    required this.role,
    required this.content,
    required this.status,
    required this.createdAt,
    this.reasoning,
    this.error,
    this.modelId,
    this.promptTokens,
    this.completionTokens,
    this.cost,
  });

  final String id;
  final String conversationId;
  final int seq;
  final ChatRole role;
  final String content;
  final String? reasoning;
  final MessageStatus status;
  final String? error;
  final String? modelId;
  final int? promptTokens;
  final int? completionTokens;
  final double? cost;
  final DateTime createdAt;

  bool get isStreaming => status == MessageStatus.streaming;

  Message copyWith({
    String? content,
    String? reasoning,
    MessageStatus? status,
    String? error,
    String? modelId,
    int? promptTokens,
    int? completionTokens,
    double? cost,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      seq: seq,
      role: role,
      content: content ?? this.content,
      reasoning: reasoning ?? this.reasoning,
      status: status ?? this.status,
      error: error ?? this.error,
      modelId: modelId ?? this.modelId,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      cost: cost ?? this.cost,
      createdAt: createdAt,
    );
  }
}
