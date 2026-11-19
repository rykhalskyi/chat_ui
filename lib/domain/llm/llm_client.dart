import '../entities/model_info.dart';
import 'chat_message.dart';
import 'chat_stream_event.dart';

abstract interface class LlmClient {
  Future<List<ModelInfo>> listModels();

  LlmStreamHandle streamChat(ChatRequest request);

  Future<void> dispose();
}

abstract interface class LlmStreamHandle {
  Stream<ChatStreamEvent> get events;

  Future<void> cancel();
}

class ChatRequest {
  const ChatRequest({
    required this.model,
    required this.messages,
    this.temperature,
    this.maxTokens,
    this.systemPrompt,
  });

  final String model;
  final List<ChatMessage> messages;
  final double? temperature;
  final int? maxTokens;
  final String? systemPrompt;
}
