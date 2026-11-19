import '../entities/conversation.dart';
import '../entities/message.dart';

class Exchange {
  const Exchange({required this.userMessage, required this.assistantMessage});

  final Message userMessage;
  final Message assistantMessage;
}

abstract interface class ChatRepository {
  Future<List<Conversation>> listConversations();

  Future<Conversation?> getConversation(String id);

  Future<Conversation> createConversation({
    required String title,
    required String modelId,
    String? systemPrompt,
    String? id,
    DateTime? now,
  });

  Future<void> renameConversation(String id, String title, {DateTime? now});

  Future<void> deleteConversation(String id);

  Future<void> updateConversationModel(
    String id,
    String modelId, {
    DateTime? now,
  });

  Future<List<Message>> listMessages(String conversationId);

  Future<Exchange> beginExchange({
    required String conversationId,
    required String userContent,
    required String modelId,
    String? userMessageId,
    String? assistantMessageId,
    DateTime? now,
  });

  Future<void> updateAssistantMessage({
    required String messageId,
    required String conversationId,
    required String content,
    required MessageStatus status,
    String? reasoning,
    String? error,
    String? modelId,
    int? promptTokens,
    int? completionTokens,
    double? cost,
    DateTime? now,
  });

  Future<int> markInterruptedRunsStopped({DateTime? now});
}
