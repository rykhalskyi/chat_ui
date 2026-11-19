import '../../core/exceptions.dart';

enum FinishReason { stop, length, contentFilter, toolCalls, cancelled, other }

class TokenUsage {
  const TokenUsage({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.reasoningTokens,
    this.cost,
  });

  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final int? reasoningTokens;
  final double? cost;
}

sealed class ChatStreamEvent {
  const ChatStreamEvent();
}

final class StreamOpened extends ChatStreamEvent {
  const StreamOpened();
}

final class ContentDelta extends ChatStreamEvent {
  const ContentDelta(this.text);

  final String text;
}

final class ReasoningDelta extends ChatStreamEvent {
  const ReasoningDelta(this.text);

  final String text;
}

final class UsageReported extends ChatStreamEvent {
  const UsageReported(this.usage);

  final TokenUsage usage;
}

final class StreamFinished extends ChatStreamEvent {
  const StreamFinished(this.reason);

  final FinishReason reason;
}

final class StreamFailed extends ChatStreamEvent {
  const StreamFailed(this.error);

  final LlmException error;
}
