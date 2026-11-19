import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_uris.dart';
import '../core/exceptions.dart';
import '../core/sse_parser.dart';
import '../domain/entities/model_info.dart';
import '../domain/llm/chat_stream_event.dart';
import '../domain/llm/llm_client.dart';
import 'model_catalog_client.dart';

class LiteLlmClient implements LlmClient {
  factory LiteLlmClient({
    required String baseUrl,
    required String apiKey,
    http.Client Function()? clientFactory,
    ModelCatalogClient? modelCatalog,
  }) {
    final factory = clientFactory ?? http.Client.new;
    return LiteLlmClient._(
      ApiUris.normalizeBase(baseUrl),
      apiKey,
      factory,
      modelCatalog ?? ModelCatalogClient(clientFactory: factory),
    );
  }

  LiteLlmClient._(
    this._baseUrl,
    this._apiKey,
    this._clientFactory,
    this._modelCatalog,
  );

  final String _baseUrl;
  final String _apiKey;
  final http.Client Function() _clientFactory;
  final ModelCatalogClient _modelCatalog;

  @override
  Future<List<ModelInfo>> listModels() {
    return _modelCatalog.fetchModels(baseUrl: _baseUrl, apiKey: _apiKey);
  }

  @override
  LlmStreamHandle streamChat(ChatRequest request) {
    final handle = _LiteLlmStreamHandle(
      baseUrl: _baseUrl,
      apiKey: _apiKey,
      clientFactory: _clientFactory,
      request: request,
    );
    handle.start();
    return handle;
  }

  @override
  Future<void> dispose() async {}
}

class _LiteLlmStreamHandle implements LlmStreamHandle {
  _LiteLlmStreamHandle({
    required this.baseUrl,
    required this.apiKey,
    required this.clientFactory,
    required this.request,
  });

  static const _connectTimeout = Duration(seconds: 15);

  final String baseUrl;
  final String apiKey;
  final http.Client Function() clientFactory;
  final ChatRequest request;

  final _controller = StreamController<ChatStreamEvent>();
  http.Client? _client;
  bool _started = false;
  bool _cancelled = false;
  bool _finished = false;

  @override
  Stream<ChatStreamEvent> get events => _controller.stream;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
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
    _client?.close();
  }

  Future<void> _run() async {
    final client = clientFactory();
    _client = client;
    try {
      final httpRequest = http.Request('POST', ApiUris.chatCompletions(baseUrl))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        });
      httpRequest.body = jsonEncode(_body());

      final response = await client.send(httpRequest).timeout(_connectTimeout);
      if (_cancelled) {
        return;
      }
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString().timeout(
          const Duration(seconds: 10),
        );
        _emit(StreamFailed(LlmException.fromHttp(response.statusCode, body)));
        return;
      }

      _emit(const StreamOpened());
      var sawContent = false;
      var sawMalformed = false;
      FinishReason? finishReason;

      await for (final payload in SseParser().parse(response.stream)) {
        if (_cancelled) {
          return;
        }
        if (payload == '[DONE]') {
          break;
        }
        final Map<String, dynamic> json;
        try {
          json = jsonDecode(payload) as Map<String, dynamic>;
        } on FormatException {
          sawMalformed = true;
          continue;
        }
        if (json['error'] != null) {
          _emit(StreamFailed(_eventError(json['error'])));
          return;
        }
        final usage = json['usage'];
        if (usage is Map<String, dynamic>) {
          _emit(UsageReported(_tokenUsage(usage)));
        }
        final choices = json['choices'];
        if (choices is! List || choices.isEmpty) {
          continue;
        }
        final choice = choices.first;
        if (choice is! Map<String, dynamic>) {
          continue;
        }
        final delta = choice['delta'];
        if (delta is Map<String, dynamic>) {
          final reasoning =
              delta['reasoning_content'] ??
              delta['reasoning'] ??
              _providerReasoning(delta);
          if (reasoning is String && reasoning.isNotEmpty) {
            _emit(ReasoningDelta(reasoning));
          }
          final content = delta['content'];
          if (content is String && content.isNotEmpty) {
            sawContent = true;
            _emit(ContentDelta(content));
          }
        }
        final finish = choice['finish_reason'];
        if (finish is String) {
          finishReason = _mapFinishReason(finish);
        }
      }

      if (_cancelled) {
        return;
      }
      if (finishReason != null) {
        _emit(StreamFinished(finishReason));
      } else if (sawContent) {
        _emit(const StreamFinished(FinishReason.stop));
      } else {
        _emit(
          StreamFailed(
            LlmException(
              LlmErrorKind.protocol,
              sawMalformed
                  ? 'Malformed stream from the server.'
                  : 'The stream ended without content.',
            ),
          ),
        );
      }
    } on TimeoutException {
      if (!_cancelled) {
        _emit(
          const StreamFailed(
            LlmException(
              LlmErrorKind.timeout,
              'The request timed out before the server responded.',
            ),
          ),
        );
      }
    } on http.ClientException catch (error) {
      if (!_cancelled) {
        _emit(
          StreamFailed(
            LlmException(
              LlmErrorKind.network,
              'Network error: ${error.message}',
            ),
          ),
        );
      }
    } on FormatException catch (error) {
      if (!_cancelled) {
        _emit(
          StreamFailed(
            LlmException(
              LlmErrorKind.protocol,
              'Unexpected server response: ${error.message}',
            ),
          ),
        );
      }
    } catch (error) {
      if (!_cancelled) {
        _emit(
          StreamFailed(
            LlmException(LlmErrorKind.protocol, 'Unexpected error: $error'),
          ),
        );
      }
    } finally {
      _finished = true;
      _client?.close();
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

  Map<String, dynamic> _body() {
    final messages = <Map<String, dynamic>>[];
    final systemPrompt = request.systemPrompt?.trim();
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.addAll(request.messages.map((message) => message.toJson()));
    return {
      'model': request.model,
      'messages': messages,
      'stream': true,
      'stream_options': {'include_usage': true},
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.maxTokens != null) 'max_tokens': request.maxTokens,
    };
  }

  static Object? _providerReasoning(Map<String, dynamic> delta) {
    final providerFields = delta['provider_specific_fields'];
    if (providerFields is Map<String, dynamic>) {
      return providerFields['reasoning_content'];
    }
    return null;
  }

  static TokenUsage _tokenUsage(Map<String, dynamic> usage) {
    final completionDetails = usage['completion_tokens_details'];
    final reasoningTokens = completionDetails is Map<String, dynamic>
        ? (completionDetails['reasoning_tokens'] as num?)?.toInt()
        : null;
    return TokenUsage(
      promptTokens: (usage['prompt_tokens'] as num?)?.toInt(),
      completionTokens: (usage['completion_tokens'] as num?)?.toInt(),
      totalTokens: (usage['total_tokens'] as num?)?.toInt(),
      reasoningTokens: reasoningTokens,
      cost: (usage['cost'] as num?)?.toDouble(),
    );
  }

  static LlmException _eventError(Object? error) {
    if (error is Map<String, dynamic>) {
      final type = error['type']?.toString();
      final message = error['message']?.toString() ?? 'Server error';
      if (type == 'no_db_connection' ||
          message.toLowerCase().contains('api key')) {
        return LlmException(
          LlmErrorKind.unauthorized,
          message,
          errorType: type,
        );
      }
      return LlmException(LlmErrorKind.server, message, errorType: type);
    }
    return LlmException(
      LlmErrorKind.server,
      error?.toString() ?? 'Server error',
    );
  }

  static FinishReason _mapFinishReason(String value) {
    return switch (value) {
      'stop' => FinishReason.stop,
      'length' => FinishReason.length,
      'content_filter' => FinishReason.contentFilter,
      'tool_calls' || 'function_call' => FinishReason.toolCalls,
      _ => FinishReason.other,
    };
  }
}
