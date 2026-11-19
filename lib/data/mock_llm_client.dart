import 'dart:async';

import '../core/exceptions.dart';
import '../domain/entities/model_info.dart';
import '../domain/llm/chat_stream_event.dart';
import '../domain/llm/llm_client.dart';

class MockLlmClient implements LlmClient {
  MockLlmClient({
    this.models = const [
      ModelInfo(id: 'llama3.2-3b-cpp'),
      ModelInfo(id: 'gemma3-1b-cpp'),
    ],
    this.reply =
        'Hello! This is the mock client. Streaming is ready for the chat UI.',
    this.reasoning,
    this.chunkDelay = const Duration(milliseconds: 20),
    this.failAfterContentChunks,
    this.error,
  });

  final List<ModelInfo> models;
  final String reply;
  final String? reasoning;
  final Duration chunkDelay;
  final int? failAfterContentChunks;
  final LlmException? error;

  @override
  Future<List<ModelInfo>> listModels() async => models;

  @override
  LlmStreamHandle streamChat(ChatRequest request) {
    final handle = _MockStreamHandle(
      reply: reply,
      reasoning: reasoning,
      chunkDelay: chunkDelay,
      failAfterContentChunks: failAfterContentChunks,
      error: error,
    );
    handle.start();
    return handle;
  }

  @override
  Future<void> dispose() async {}
}

class _MockStreamHandle implements LlmStreamHandle {
  _MockStreamHandle({
    required this.reply,
    required this.reasoning,
    required this.chunkDelay,
    required this.failAfterContentChunks,
    required this.error,
  });

  final String reply;
  final String? reasoning;
  final Duration chunkDelay;
  final int? failAfterContentChunks;
  final LlmException? error;

  final _controller = StreamController<ChatStreamEvent>();
  bool _cancelled = false;
  bool _finished = false;

  @override
  Stream<ChatStreamEvent> get events => _controller.stream;

  void start() {
    unawaited(_run());
  }

  @override
  Future<void> cancel() async {
    if (_cancelled || _finished) {
      return;
    }
    _cancelled = true;
    if (!_controller.isClosed) {
      _controller.add(const StreamFinished(FinishReason.cancelled));
      await _controller.close();
    }
  }

  Future<void> _run() async {
    try {
      _emit(const StreamOpened());
      await _wait();
      final reasoningText = reasoning;
      if (reasoningText != null) {
        for (final chunk in _chunks(reasoningText)) {
          if (_cancelled) {
            return;
          }
          _emit(ReasoningDelta(chunk));
          await _wait();
        }
      }
      var sent = 0;
      for (final chunk in _chunks(reply)) {
        if (_cancelled) {
          return;
        }
        if (failAfterContentChunks != null && sent >= failAfterContentChunks!) {
          _emit(
            StreamFailed(
              error ??
                  const LlmException(
                    LlmErrorKind.server,
                    'Mock stream failed.',
                  ),
            ),
          );
          return;
        }
        _emit(ContentDelta(chunk));
        sent++;
        await _wait();
      }
      final completionTokens = reply.split(RegExp(r'\s+')).length;
      _emit(
        UsageReported(
          TokenUsage(
            promptTokens: 10,
            completionTokens: completionTokens,
            totalTokens: 10 + completionTokens,
          ),
        ),
      );
      _emit(const StreamFinished(FinishReason.stop));
    } finally {
      _finished = true;
      if (!_controller.isClosed) {
        await _controller.close();
      }
    }
  }

  void _emit(ChatStreamEvent event) {
    if (_cancelled || _finished || _controller.isClosed) {
      return;
    }
    _controller.add(event);
  }

  Future<void> _wait() {
    if (chunkDelay == Duration.zero) {
      return Future<void>.value();
    }
    return Future<void>.delayed(chunkDelay);
  }

  static Iterable<String> _chunks(String text) {
    final words = text.split(' ');
    return [
      for (var i = 0; i < words.length; i++) i == 0 ? words[i] : ' ${words[i]}',
    ];
  }
}
