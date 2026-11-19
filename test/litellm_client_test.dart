import 'dart:async';
import 'dart:convert';

import 'package:chat_ui_3/core/exceptions.dart';
import 'package:chat_ui_3/data/litellm_client.dart';
import 'package:chat_ui_3/data/model_catalog_client.dart';
import 'package:chat_ui_3/domain/llm/chat_message.dart';
import 'package:chat_ui_3/domain/llm/chat_stream_event.dart';
import 'package:chat_ui_3/domain/llm/llm_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class FakeClient extends http.BaseClient {
  FakeClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;
  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    lastRequest = request;
    return handler(request);
  }
}

http.StreamedResponse sseResponse(List<String> events) {
  return http.StreamedResponse(
    Stream.fromIterable(events.map(utf8.encode)),
    200,
    headers: {'content-type': 'text/event-stream'},
  );
}

LiteLlmClient clientWith(FakeClient fake) {
  return LiteLlmClient(
    baseUrl: 'https://example.test/v1',
    apiKey: 'sk-test',
    clientFactory: () => fake,
  );
}

ChatRequest request({
  String model = 'llama3.2-3b-cpp',
  String prompt = 'hi',
  String? systemPrompt,
}) {
  return ChatRequest(
    model: model,
    messages: [ChatMessage.user(prompt)],
    systemPrompt: systemPrompt,
    temperature: 0.2,
    maxTokens: 64,
  );
}

void main() {
  test('streams content, reasoning, usage and finish', () async {
    final fake = FakeClient(
      (_) async => sseResponse([
        'data: {"choices":[{"delta":{"reasoning_content":"Think"}}]}\n\n',
        'data: {"choices":[{"delta":{"content":"Hel"}}]}\n\n',
        'data: {"choices":[{"delta":{"content":"lo"}}]}\n\n',
        'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\n',
        'data: {"choices":[{"delta":{}}],"usage":{"prompt_tokens":5,"completion_tokens":2,"total_tokens":7,"completion_tokens_details":{"reasoning_tokens":1},"cost":0.25}}\n\n',
        'data: [DONE]\n\n',
      ]),
    );

    final handle = clientWith(fake)
        .streamChat(request(systemPrompt: 'Be brief'));
    final events = await handle.events.toList();

    expect(events.first, isA<StreamOpened>());
    expect(
      events.whereType<ContentDelta>().map((event) => event.text).join(),
      'Hello',
    );
    expect(
      events.whereType<ReasoningDelta>().map((event) => event.text).join(),
      'Think',
    );
    final usage = events.whereType<UsageReported>().single.usage;
    expect(usage.promptTokens, 5);
    expect(usage.completionTokens, 2);
    expect(usage.totalTokens, 7);
    expect(usage.reasoningTokens, 1);
    expect(usage.cost, 0.25);
    expect(events.whereType<StreamFinished>().single.reason, FinishReason.stop);

    final httpRequest = fake.lastRequest as http.Request;
    expect(
      httpRequest.url.toString(),
      'https://example.test/v1/chat/completions',
    );
    expect(httpRequest.headers['Authorization'], 'Bearer sk-test');
    final body = jsonDecode(httpRequest.body) as Map<String, dynamic>;
    expect(body['model'], 'llama3.2-3b-cpp');
    expect(body['stream'], isTrue);
    expect((body['stream_options'] as Map)['include_usage'], isTrue);
    expect(body['temperature'], 0.2);
    expect(body['max_tokens'], 64);
    expect((body['messages'] as List).first, {
      'role': 'system',
      'content': 'Be brief',
    });
    expect((body['messages'] as List)[1], {'role': 'user', 'content': 'hi'});
  });

  test('maps a bad key 400 to unauthorized', () async {
    final fake = FakeClient(
      (_) async => http.StreamedResponse(
        Stream.value(
          utf8.encode(
            '{"error":{"message":"No connected db.","type":"no_db_connection"}}',
          ),
        ),
        400,
      ),
    );

    final events = await clientWith(fake).streamChat(request()).events.toList();

    expect(events.single, isA<StreamFailed>());
    final error = (events.single as StreamFailed).error;
    expect(error.kind, LlmErrorKind.unauthorized);
    expect(error.statusCode, 400);
    expect(error.errorType, 'no_db_connection');
  });

  test('maps an unknown model 400 to modelNotFound', () async {
    final fake = FakeClient(
      (_) async => http.StreamedResponse(
        Stream.value(
          utf8.encode(
            '{"error":{"message":"Invalid model name passed in model=nope","type":"invalid_request_error"}}',
          ),
        ),
        400,
      ),
    );

    final events = await clientWith(fake).streamChat(request()).events.toList();

    final error = (events.single as StreamFailed).error;
    expect(error.kind, LlmErrorKind.modelNotFound);
  });

  test('treats an SSE error payload as a failure', () async {
    final fake = FakeClient(
      (_) async => sseResponse([
        'data: {"error":{"message":"No connected db.","type":"no_db_connection"}}\n\n',
      ]),
    );

    final events = await clientWith(fake).streamChat(request()).events.toList();

    expect(events.first, isA<StreamOpened>());
    final error = (events.last as StreamFailed).error;
    expect(error.kind, LlmErrorKind.unauthorized);
  });

  test('fails when the stream has no content or finish reason', () async {
    final fake = FakeClient(
      (_) async => sseResponse(['data: not-json\n\n', 'data: [DONE]\n\n']),
    );

    final events = await clientWith(fake).streamChat(request()).events.toList();

    final error = (events.last as StreamFailed).error;
    expect(error.kind, LlmErrorKind.protocol);
  });

  test('cancel emits a cancelled terminal event', () async {
    final source = StreamController<List<int>>();
    final fake = FakeClient(
      (_) async => http.StreamedResponse(source.stream, 200),
    );
    final handle = clientWith(fake).streamChat(request());
    final events = <ChatStreamEvent>[];
    final done = Completer<void>();
    handle.events.listen(events.add, onDone: done.complete);

    source.add(
      utf8.encode('data: {"choices":[{"delta":{"content":"Hi"}}]}\n\n'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await handle.cancel();
    await source.close();
    await done.future;

    expect(
      events.whereType<ContentDelta>().map((event) => event.text).join(),
      'Hi',
    );
    expect(
      events.whereType<StreamFinished>().single.reason,
      FinishReason.cancelled,
    );
    expect(events.whereType<StreamFailed>(), isEmpty);
  });

  test('listModels delegates to the model catalog', () async {
    final catalogClient = FakeClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/v1/models');
      expect(request.headers['Authorization'], 'Bearer sk-test');
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            '{"data":[{"id":"gemma3-1b-cpp"},{"id":"llama3.2-3b-cpp"}]}',
          ),
        ),
        200,
      );
    });
    final client = LiteLlmClient(
      baseUrl: 'https://example.test/v1',
      apiKey: 'sk-test',
      clientFactory: () => catalogClient,
      modelCatalog: ModelCatalogClient(clientFactory: () => catalogClient),
    );

    final models = await client.listModels();

    expect(models.map((model) => model.id), [
      'gemma3-1b-cpp',
      'llama3.2-3b-cpp',
    ]);
  });
}
