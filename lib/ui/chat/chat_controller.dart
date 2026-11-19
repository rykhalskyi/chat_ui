import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/context_budget.dart';
import '../../core/exceptions.dart';
import '../../data/llm_client_factory.dart';
import '../../domain/entities/chat_role.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/model_info.dart';
import '../../domain/llm/chat_stream_event.dart';
import '../../domain/llm/llm_client.dart';
import '../../domain/repositories/chat_repository.dart';
import '../settings/settings_controller.dart';
import 'conversations_controller.dart';

enum ChatRunPhase {
  idle,
  connecting,
  waitingForModel,
  thinking,
  streaming,
  failed,
  cancelled,
}

class ChatController extends ChangeNotifier {
  ChatController({
    required this.repository,
    required this.settings,
    required this.clientFactory,
    required this.conversations,
  }) {
    _selectedModel = settings.settings.defaultModel;
  }

  final ChatRepository repository;
  final SettingsController settings;
  final LlmClientFactory clientFactory;
  final ConversationsController conversations;

  Conversation? _active;
  List<Message> _messages = [];
  String _selectedModel = '';
  List<ModelInfo> _models = [];
  bool _modelsLoading = false;
  String? _modelsError;
  bool _isLoading = true;
  String? _errorMessage;
  ChatRunPhase _phase = ChatRunPhase.idle;
  DateTime? _runStartedAt;
  String? _runError;
  bool _contextTrimmed = false;
  int _droppedMessages = 0;
  final Map<String, String> _drafts = {};
  static const _newChatDraftKey = '__new__';

  LlmClient? _client;
  LlmStreamHandle? _handle;
  StreamSubscription<ChatStreamEvent>? _subscription;
  Timer? _persistTimer;
  Message? _assistant;
  StringBuffer _content = StringBuffer();
  StringBuffer _reasoning = StringBuffer();
  TokenUsage? _usage;
  bool _finalized = false;
  bool _persisting = false;
  bool _persistPending = false;
  bool _disposed = false;

  Conversation? get active => _active;
  List<Message> get messages => List.unmodifiable(_messages);
  String get selectedModel => _selectedModel;
  List<ModelInfo> get models => List.unmodifiable(_models);
  bool get modelsLoading => _modelsLoading;
  String? get modelsError => _modelsError;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ChatRunPhase get phase => _phase;
  DateTime? get runStartedAt => _runStartedAt;
  String? get runError => _runError;
  bool get contextTrimmed => _contextTrimmed;
  int get droppedMessages => _droppedMessages;
  String? get assistantId => _assistant?.id;
  String get draftKey => _active?.id ?? _newChatDraftKey;
  String get draft => _drafts[draftKey] ?? '';

  bool get isRunning =>
      _phase == ChatRunPhase.connecting ||
      _phase == ChatRunPhase.waitingForModel ||
      _phase == ChatRunPhase.thinking ||
      _phase == ChatRunPhase.streaming;

  bool get canRetry {
    if (isRunning || _messages.isEmpty) {
      return false;
    }
    final last = _messages.last;
    return last.role == ChatRole.assistant &&
        (last.status == MessageStatus.error ||
            last.status == MessageStatus.stopped);
  }

  bool get canRegenerate {
    if (isRunning || _messages.isEmpty) {
      return false;
    }
    final last = _messages.last;
    return last.role == ChatRole.assistant &&
        last.status == MessageStatus.complete &&
        last.content.isNotEmpty;
  }

  Future<void> initialize() async {
    await conversations.load();
    final recent = conversations.mostRecent;
    if (recent != null) {
      await open(recent);
    } else {
      _selectedModel = settings.settings.defaultModel;
      _isLoading = false;
      _notify();
    }
  }

  Future<bool> open(Conversation conversation) async {
    if (isRunning) {
      _errorMessage = 'Stop the current response before switching chats.';
      _notify();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      final messages = await repository.listMessages(conversation.id);
      _active = conversation;
      _messages = messages;
      _selectedModel = conversation.modelId;
      _phase = ChatRunPhase.idle;
      _runError = null;
      _contextTrimmed = false;
      _droppedMessages = 0;
      _isLoading = false;
      _notify();
      return true;
    } catch (error) {
      _errorMessage = 'Could not load the conversation: $error';
      _isLoading = false;
      _notify();
      return false;
    }
  }

  Future<void> newChat() async {
    if (isRunning) {
      _errorMessage = 'Stop the current response before starting a new chat.';
      _notify();
      return;
    }
    final model = _selectedModel.isEmpty
        ? settings.settings.defaultModel
        : _selectedModel;
    final conversation = await conversations.create(
      modelId: model,
      systemPrompt: settings.settings.systemPrompt,
    );
    _drafts.remove(_newChatDraftKey);
    await open(conversation);
  }

  Future<void> setModel(String modelId) async {
    if (modelId == _selectedModel) {
      return;
    }
    _selectedModel = modelId;
    final active = _active;
    if (active != null) {
      try {
        await repository.updateConversationModel(active.id, modelId);
        _active = active.copyWith(modelId: modelId);
        await conversations.refresh();
      } catch (error) {
        _errorMessage = 'Could not save the model: $error';
      }
    }
    _notify();
  }

  Future<void> refreshModels() async {
    if (_modelsLoading) {
      return;
    }
    _modelsLoading = true;
    _modelsError = null;
    _notify();
    LlmClient? client;
    try {
      final current = settings.settings;
      client = clientFactory.create(
        baseUrl: current.baseUrl,
        apiKey: settings.apiKey,
        connectAddress: current.useConnectAddress
            ? current.connectAddress
            : null,
      );
      _models = await client.listModels();
    } catch (error) {
      _modelsError = error.toString();
    } finally {
      await client?.dispose();
      _modelsLoading = false;
      _notify();
    }
  }

  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty || isRunning) {
      return;
    }
    if (_active == null) {
      await newChat();
      if (_active == null) {
        return;
      }
    }
    _drafts.remove(_newChatDraftKey);
    final active = _active!;
    _drafts.remove(active.id);
    final model = _selectedModel;
    final prior = List<Message>.of(_messages);
    final now = DateTime.now();
    try {
      final exchange = await repository.beginExchange(
        conversationId: active.id,
        userContent: content,
        modelId: model,
        now: now,
      );
      _messages = [
        ..._messages,
        exchange.userMessage,
        exchange.assistantMessage,
      ];
      final refreshed = await repository.getConversation(active.id);
      _active = refreshed ?? active.copyWith(updatedAt: now);
      _errorMessage = null;
      _beginRun(exchange.assistantMessage);
      await conversations.refresh();
      await _startRun(
        prior: prior,
        userInput: content,
        assistant: exchange.assistantMessage,
        model: model,
      );
    } catch (error) {
      _errorMessage = 'Could not start the chat: $error';
      _phase = ChatRunPhase.failed;
      _notify();
    }
  }

  Future<void> retryLast() async {
    if (isRunning || !canRetry) {
      return;
    }
    await _rerunLastAssistant();
  }

  Future<void> regenerateLast() async {
    if (isRunning || !canRegenerate) {
      return;
    }
    await _rerunLastAssistant();
  }

  Future<void> _rerunLastAssistant() async {
    final last = _messages.last;
    final userIndex = _messages.lastIndexWhere((m) => m.role == ChatRole.user);
    if (userIndex < 0) {
      return;
    }
    final userMessage = _messages[userIndex];
    final prior = _messages.sublist(0, userIndex);
    final now = DateTime.now();
    final model = _selectedModel;
    final reset = Message(
      id: last.id,
      conversationId: last.conversationId,
      seq: last.seq,
      role: ChatRole.assistant,
      content: '',
      status: MessageStatus.streaming,
      modelId: model,
      createdAt: now,
    );
    try {
      await repository.updateAssistantMessage(
        messageId: last.id,
        conversationId: last.conversationId,
        content: '',
        status: MessageStatus.streaming,
        modelId: model,
        now: now,
      );
      final index = _messages.indexWhere((m) => m.id == last.id);
      if (index >= 0) {
        _messages[index] = reset;
      }
      _beginRun(reset);
      await conversations.refresh();
      await _startRun(
        prior: prior,
        userInput: userMessage.content,
        assistant: reset,
        model: model,
      );
    } catch (error) {
      _errorMessage = 'Could not retry the request: $error';
      _phase = ChatRunPhase.failed;
      _notify();
    }
  }

  Future<void> cancel() async {
    if (!isRunning) {
      return;
    }
    final handle = _handle;
    if (handle != null) {
      await handle.cancel();
    }
    if (!_finalized) {
      await _finishRun(FinishReason.cancelled);
    }
  }

  Future<void> conversationDeleted(String id) async {
    _drafts.remove(id);
    if (_active?.id != id) {
      return;
    }
    if (isRunning) {
      await cancel();
    }
    _active = null;
    _messages = [];
    _phase = ChatRunPhase.idle;
    _runError = null;
    _contextTrimmed = false;
    _droppedMessages = 0;
    _selectedModel = settings.settings.defaultModel;
    _notify();
  }

  void setDraft(String value) {
    final key = draftKey;
    if (value.isEmpty) {
      _drafts.remove(key);
    } else {
      _drafts[key] = value;
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    _notify();
  }

  void _beginRun(Message assistant) {
    _assistant = assistant;
    _content = StringBuffer();
    _reasoning = StringBuffer();
    _usage = null;
    _finalized = false;
    _persisting = false;
    _persistPending = false;
    _runError = null;
    _contextTrimmed = false;
    _droppedMessages = 0;
    _phase = ChatRunPhase.connecting;
    _runStartedAt = DateTime.now();
    _notify();
  }

  Future<void> _startRun({
    required List<Message> prior,
    required String userInput,
    required Message assistant,
    required String model,
  }) async {
    final current = settings.settings;
    if (current.baseUrl.trim().isEmpty) {
      await _finishRun(
        FinishReason.other,
        error: const LlmException(
          LlmErrorKind.invalidRequest,
          'Set the API base URL in Settings.',
        ),
      );
      return;
    }
    final plan = ContextBudget.plan(
      prior: prior,
      userInput: userInput,
      modelId: model,
      maxTokens: current.maxTokens,
      systemPrompt: current.systemPrompt,
    );
    _contextTrimmed = plan.trimmed;
    _droppedMessages = plan.droppedMessages;

    final client = clientFactory.create(
      baseUrl: current.baseUrl,
      apiKey: settings.apiKey,
      connectAddress: current.useConnectAddress ? current.connectAddress : null,
    );
    _client = client;
    _assistant = assistant;
    try {
      final handle = client.streamChat(
        ChatRequest(
          model: model,
          messages: plan.messages,
          temperature: current.temperature,
          maxTokens: current.maxTokens,
          systemPrompt: current.systemPrompt,
        ),
      );
      _handle = handle;
      _persistTimer = Timer.periodic(
        const Duration(milliseconds: 300),
        (_) => unawaited(_persistStreaming()),
      );
      _subscription = handle.events.listen(
        _onEvent,
        onError: (Object error, StackTrace stackTrace) {
          unawaited(
            _finishRun(
              FinishReason.other,
              error: LlmException(
                LlmErrorKind.protocol,
                'Stream error: $error',
              ),
            ),
          );
        },
      );
      _notify();
    } catch (error) {
      await _finishRun(
        FinishReason.other,
        error: LlmException(
          LlmErrorKind.protocol,
          'Could not start the stream: $error',
        ),
      );
    }
  }

  void _onEvent(ChatStreamEvent event) {
    if (_finalized) {
      return;
    }
    if (event is StreamOpened) {
      _phase = ChatRunPhase.waitingForModel;
      _notify();
    } else if (event is ReasoningDelta) {
      _reasoning.write(event.text);
      _phase = ChatRunPhase.thinking;
      _syncAssistant();
      _notify();
    } else if (event is ContentDelta) {
      _content.write(event.text);
      _phase = ChatRunPhase.streaming;
      _syncAssistant();
      _notify();
    } else if (event is UsageReported) {
      _usage = event.usage;
      _syncAssistant();
      _notify();
    } else if (event is StreamFinished) {
      unawaited(_finishRun(event.reason));
    } else if (event is StreamFailed) {
      unawaited(_finishRun(FinishReason.other, error: event.error));
    }
  }

  void _syncAssistant({
    MessageStatus status = MessageStatus.streaming,
    String? error,
  }) {
    final assistant = _assistant;
    if (assistant == null) {
      return;
    }
    final index = _messages.indexWhere((m) => m.id == assistant.id);
    if (index < 0) {
      return;
    }
    final updated = Message(
      id: assistant.id,
      conversationId: assistant.conversationId,
      seq: assistant.seq,
      role: assistant.role,
      content: _content.toString(),
      reasoning: _reasoning.isEmpty ? null : _reasoning.toString(),
      status: status,
      error: error,
      modelId: assistant.modelId,
      promptTokens: _usage?.promptTokens,
      completionTokens: _usage?.completionTokens,
      cost: _usage?.cost,
      createdAt: assistant.createdAt,
    );
    _messages[index] = updated;
    _assistant = updated;
  }

  Future<void> _persistStreaming() async {
    if (_finalized || !isRunning) {
      return;
    }
    final assistant = _assistant;
    final active = _active;
    if (assistant == null || active == null) {
      return;
    }
    if (_persisting) {
      _persistPending = true;
      return;
    }
    _persisting = true;
    try {
      await repository.updateAssistantMessage(
        messageId: assistant.id,
        conversationId: active.id,
        content: _content.toString(),
        reasoning: _reasoning.isEmpty ? null : _reasoning.toString(),
        status: MessageStatus.streaming,
        modelId: assistant.modelId,
        promptTokens: _usage?.promptTokens,
        completionTokens: _usage?.completionTokens,
        cost: _usage?.cost,
        now: DateTime.now(),
      );
    } catch (_) {
    } finally {
      _persisting = false;
      if (_persistPending && !_finalized) {
        _persistPending = false;
        unawaited(_persistStreaming());
      }
    }
  }

  Future<void> _finishRun(FinishReason reason, {LlmException? error}) async {
    if (_finalized) {
      return;
    }
    _finalized = true;
    _persistTimer?.cancel();
    _persistTimer = null;
    final status = error != null
        ? MessageStatus.error
        : reason == FinishReason.cancelled
        ? MessageStatus.stopped
        : MessageStatus.complete;
    _syncAssistant(status: status, error: error?.userMessage);
    final assistant = _assistant;
    final active = _active;
    if (assistant != null && active != null) {
      try {
        await repository.updateAssistantMessage(
          messageId: assistant.id,
          conversationId: active.id,
          content: _content.toString(),
          reasoning: _reasoning.isEmpty ? null : _reasoning.toString(),
          status: status,
          error: error?.userMessage,
          modelId: assistant.modelId,
          promptTokens: _usage?.promptTokens,
          completionTokens: _usage?.completionTokens,
          cost: _usage?.cost,
          now: DateTime.now(),
        );
      } catch (persistError) {
        _errorMessage = 'Could not save the reply: $persistError';
      }
    }
    _phase = error != null
        ? ChatRunPhase.failed
        : reason == FinishReason.cancelled
        ? ChatRunPhase.cancelled
        : ChatRunPhase.idle;
    _runError = error?.userMessage;
    _runStartedAt = null;
    _handle = null;
    _assistant = null;
    final client = _client;
    _client = null;
    final subscription = _subscription;
    _subscription = null;
    unawaited(subscription?.cancel());
    await client?.dispose();
    if (!_disposed) {
      await conversations.refresh();
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _persistTimer?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_handle?.cancel());
    unawaited(_client?.dispose());
    super.dispose();
  }
}
