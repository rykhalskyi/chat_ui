import 'package:chat_ui_3/core/context_budget.dart';
import 'package:chat_ui_3/domain/entities/chat_role.dart';
import 'package:chat_ui_3/domain/entities/message.dart';
import 'package:flutter_test/flutter_test.dart';

Message message(int seq, ChatRole role, String content) {
  return Message(
    id: 'm$seq',
    conversationId: 'c1',
    seq: seq,
    role: role,
    content: content,
    status: MessageStatus.complete,
    createdAt: DateTime.fromMillisecondsSinceEpoch(seq),
  );
}

void main() {
  test('keeps short history and appends the current input', () {
    final plan = ContextBudget.plan(
      prior: [
        message(1, ChatRole.user, 'hello'),
        message(2, ChatRole.assistant, 'hi'),
      ],
      userInput: 'next',
      modelId: 'llama3.2-3b-cpp',
      maxTokens: 1024,
    );

    expect(plan.trimmed, isFalse);
    expect(plan.droppedMessages, 0);
    expect(plan.messages.map((m) => m.content), ['hello', 'hi', 'next']);
    expect(plan.messages.last.role, ChatRole.user);
  });

  test('drops older exchanges when over the local window', () {
    final oldText = 'a' * 12000;
    final recentText = 'b' * 12000;
    final plan = ContextBudget.plan(
      prior: [
        message(1, ChatRole.user, oldText),
        message(2, ChatRole.assistant, oldText),
        message(3, ChatRole.user, recentText),
        message(4, ChatRole.assistant, recentText),
      ],
      userInput: 'new question',
      modelId: 'llama3.2-3b-cpp',
      maxTokens: 1024,
    );

    expect(plan.trimmed, isTrue);
    expect(plan.droppedMessages, greaterThan(0));
    expect(plan.messages.last.content, 'new question');
    expect(plan.messages.any((m) => m.content == oldText), isFalse);
    expect(plan.messages.any((m) => m.content == recentText), isTrue);
  });

  test('uses per-model context windows', () {
    expect(ContextBudget.contextWindowFor('llama3.2-3b-cpp'), 4096);
    expect(ContextBudget.contextWindowFor('gemma3-1b-cpp'), 4096);
    expect(ContextBudget.contextWindowFor('deepseek-chat'), 32768);
    expect(ContextBudget.contextWindowFor('unknown-model'), 8192);
  });

  test('counts the system prompt against the budget', () {
    final prior = [
      for (var index = 0; index < 4; index++)
        message(
          index + 1,
          index.isEven ? ChatRole.user : ChatRole.assistant,
          'x' * 2000,
        ),
    ];

    final withoutPrompt = ContextBudget.plan(
      prior: prior,
      userInput: 'hi',
      modelId: 'llama3.2-3b-cpp',
      maxTokens: 1024,
    );
    final withPrompt = ContextBudget.plan(
      prior: prior,
      userInput: 'hi',
      modelId: 'llama3.2-3b-cpp',
      maxTokens: 1024,
      systemPrompt: 'z' * 8000,
    );

    expect(withoutPrompt.trimmed, isFalse);
    expect(withPrompt.trimmed, isTrue);
    expect(withPrompt.droppedMessages, greaterThan(0));
  });

  test('always keeps the current input even when it is huge', () {
    final plan = ContextBudget.plan(
      prior: const [],
      userInput: 'x' * 50000,
      modelId: 'llama3.2-3b-cpp',
      maxTokens: 1024,
    );

    expect(plan.messages, hasLength(1));
    expect(plan.messages.single.content.length, 50000);
  });
}
