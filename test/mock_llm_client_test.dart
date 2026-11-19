import 'dart:async';

import 'package:chat_ui_3/data/mock_llm_client.dart';
import 'package:chat_ui_3/domain/llm/chat_message.dart';
import 'package:chat_ui_3/domain/llm/chat_stream_event.dart';
import 'package:chat_ui_3/domain/llm/llm_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mock streams reasoning and content', () async {
    final client = MockLlmClient(
      reply: 'Hi there',
      reasoning: 'Think',
      chunkDelay: Duration.zero,
    );

    final events = await client
        .streamChat(
          ChatRequest(
            model: 'mock',
            messages: [const ChatMessage.user('hello')],
          ),
        )
        .events
        .toList();

    expect(
      events.whereType<ReasoningDelta>().map((event) => event.text).join(),
      'Think',
    );
    expect(
      events.whereType<ContentDelta>().map((event) => event.text).join(),
      'Hi there',
    );
    expect(events.whereType<UsageReported>(), hasLength(1));
    expect(events.whereType<StreamFinished>().single.reason, FinishReason.stop);
  });

  test('mock cancel emits a cancelled terminal event', () async {
    final client = MockLlmClient(
      reply: 'one two three four five',
      chunkDelay: const Duration(milliseconds: 30),
    );
    final handle = client.streamChat(
      ChatRequest(model: 'mock', messages: [const ChatMessage.user('hello')]),
    );
    final events = <ChatStreamEvent>[];
    final done = Completer<void>();
    handle.events.listen(events.add, onDone: done.complete);

    await Future<void>.delayed(const Duration(milliseconds: 40));
    await handle.cancel();
    await done.future;

    expect(
      events.whereType<StreamFinished>().single.reason,
      FinishReason.cancelled,
    );
  });
}
