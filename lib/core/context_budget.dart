import 'dart:math' as math;

import '../domain/entities/chat_role.dart';
import '../domain/entities/message.dart';
import '../domain/llm/chat_message.dart';

class ContextPlan {
  const ContextPlan({
    required this.messages,
    required this.trimmed,
    required this.droppedMessages,
    required this.estimatedTokens,
  });

  final List<ChatMessage> messages;
  final bool trimmed;
  final int droppedMessages;
  final int estimatedTokens;
}

class ContextBudget {
  static const _localWindow = 4096;
  static const _defaultWindow = 8192;
  static const _overhead = 100;
  static const _systemReserve = 200;

  static const _windows = <String, int>{
    'llama3.2-3b-cpp': _localWindow,
    'qwen2.5-coder-3b-cpp': _localWindow,
    'gemma3-1b-cpp': _localWindow,
    'gemma3-4b-cpp': _localWindow,
    'qwen3.5-4b-cpp': _localWindow,
    'deepseek-chat': 32768,
  };

  static int contextWindowFor(String modelId) {
    return _windows[modelId] ?? _defaultWindow;
  }

  static String windowLabel(String modelId) {
    final window = contextWindowFor(modelId);
    if (window >= 1024) {
      return '${(window / 1024).round()}k';
    }
    return '$window';
  }

  static int estimateTokens(String text) {
    if (text.isEmpty) {
      return 0;
    }
    return math.max(1, (text.length / 4).ceil());
  }

  static ContextPlan plan({
    required List<Message> prior,
    required String userInput,
    required String modelId,
    required int maxTokens,
    String? systemPrompt,
  }) {
    final window = contextWindowFor(modelId);
    final systemTokens = estimateTokens(systemPrompt ?? '');
    final budget = math.max(
      256,
      window - maxTokens - systemTokens - _overhead - _systemReserve,
    );

    final groups = <List<Message>>[];
    for (final message in prior) {
      if (message.content.trim().isEmpty) {
        continue;
      }
      if (message.status == MessageStatus.streaming) {
        continue;
      }
      if (message.role == ChatRole.user) {
        groups.add([message]);
      } else if (message.role == ChatRole.assistant && groups.isNotEmpty) {
        groups.last.add(message);
      }
    }

    final selected = <List<Message>>[];
    var used = estimateTokens(userInput);
    var dropped = 0;
    var blocked = false;
    for (var index = groups.length - 1; index >= 0; index--) {
      final group = groups[index];
      final tokens = group.fold<int>(
        0,
        (sum, message) => sum + estimateTokens(message.content),
      );
      if (!blocked && used + tokens > budget && selected.isNotEmpty) {
        blocked = true;
      }
      if (blocked) {
        dropped += group.length;
        continue;
      }
      selected.insert(0, group);
      used += tokens;
    }

    final messages = <ChatMessage>[
      for (final group in selected)
        for (final message in group)
          ChatMessage(role: message.role, content: message.content),
      ChatMessage.user(userInput),
    ];

    return ContextPlan(
      messages: messages,
      trimmed: dropped > 0,
      droppedMessages: dropped,
      estimatedTokens: used,
    );
  }
}
