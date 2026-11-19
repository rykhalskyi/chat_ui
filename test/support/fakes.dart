import 'package:chat_ui_3/data/llm_client_factory.dart';
import 'package:chat_ui_3/data/model_catalog_client.dart';
import 'package:chat_ui_3/domain/entities/app_settings.dart';
import 'package:chat_ui_3/domain/entities/chat_role.dart';
import 'package:chat_ui_3/domain/entities/conversation.dart';
import 'package:chat_ui_3/domain/entities/message.dart';
import 'package:chat_ui_3/domain/entities/model_info.dart';
import 'package:chat_ui_3/domain/llm/llm_client.dart';
import 'package:chat_ui_3/domain/repositories/chat_repository.dart';
import 'package:chat_ui_3/domain/repositories/settings_repository.dart';
import 'package:chat_ui_3/ui/settings/settings_controller.dart';

class FakeSettingsRepository implements SettingsRepository {
  AppSettings settings = AppSettings.defaults;
  String apiKey = '';
  int saveSettingsCalls = 0;
  int saveApiKeyCalls = 0;

  @override
  Future<AppSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    this.settings = settings;
    saveSettingsCalls++;
  }

  @override
  Future<String> loadApiKey() async => apiKey;

  @override
  Future<void> saveApiKey(String apiKey) async {
    this.apiKey = apiKey;
    saveApiKeyCalls++;
  }
}

class FakeModelCatalog extends ModelCatalogClient {
  FakeModelCatalog({this.models = const [], this.errorMessage});

  final List<ModelInfo> models;
  final String? errorMessage;
  String? lastBaseUrl;
  String? lastApiKey;

  @override
  Future<List<ModelInfo>> fetchModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    lastBaseUrl = baseUrl;
    lastApiKey = apiKey;
    if (errorMessage != null) {
      throw ModelCatalogException(errorMessage!);
    }
    return models;
  }
}

class FakeChatRepository implements ChatRepository {
  final List<Conversation> _conversations = [];
  final List<Message> _messages = [];
  int _id = 0;

  String _nextId(String prefix) => '$prefix${_id++}';

  @override
  Future<List<Conversation>> listConversations() async {
    final result = [..._conversations]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  @override
  Future<Conversation?> getConversation(String id) async {
    for (final conversation in _conversations) {
      if (conversation.id == id) {
        return conversation;
      }
    }
    return null;
  }

  @override
  Future<Conversation> createConversation({
    required String title,
    required String modelId,
    String? systemPrompt,
    String? id,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final conversation = Conversation(
      id: id ?? _nextId('c'),
      title: title.trim().isEmpty ? 'New chat' : title.trim(),
      modelId: modelId,
      systemPrompt: systemPrompt,
      createdAt: at,
      updatedAt: at,
    );
    _conversations.add(conversation);
    return conversation;
  }

  @override
  Future<void> renameConversation(
    String id,
    String title, {
    DateTime? now,
  }) async {
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index < 0) {
      return;
    }
    _conversations[index] = _conversations[index].copyWith(
      title: title.trim().isEmpty ? 'New chat' : title.trim(),
      updatedAt: now ?? DateTime.now(),
    );
  }

  @override
  Future<void> deleteConversation(String id) async {
    _conversations.removeWhere((c) => c.id == id);
    _messages.removeWhere((m) => m.conversationId == id);
  }

  @override
  Future<void> updateConversationModel(
    String id,
    String modelId, {
    DateTime? now,
  }) async {
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index < 0) {
      return;
    }
    _conversations[index] = _conversations[index].copyWith(
      modelId: modelId,
      updatedAt: now ?? DateTime.now(),
    );
  }

  @override
  Future<List<Message>> listMessages(String conversationId) async {
    final result =
        _messages.where((m) => m.conversationId == conversationId).toList()
          ..sort((a, b) => a.seq.compareTo(b.seq));
    return result;
  }

  @override
  Future<Exchange> beginExchange({
    required String conversationId,
    required String userContent,
    required String modelId,
    String? userMessageId,
    String? assistantMessageId,
    DateTime? now,
  }) async {
    final conversation = await getConversation(conversationId);
    if (conversation == null) {
      throw StateError('Conversation $conversationId does not exist.');
    }
    final at = now ?? DateTime.now();
    final seq =
        _messages.where((m) => m.conversationId == conversationId).length + 1;
    final userMessage = Message(
      id: userMessageId ?? _nextId('u'),
      conversationId: conversationId,
      seq: seq,
      role: ChatRole.user,
      content: userContent,
      status: MessageStatus.complete,
      createdAt: at,
    );
    final assistantMessage = Message(
      id: assistantMessageId ?? _nextId('a'),
      conversationId: conversationId,
      seq: seq + 1,
      role: ChatRole.assistant,
      content: '',
      status: MessageStatus.streaming,
      modelId: modelId,
      createdAt: at,
    );
    _messages.addAll([userMessage, assistantMessage]);
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    _conversations[index] = conversation.copyWith(
      title: conversation.title == 'New chat'
          ? _deriveTitle(userContent)
          : conversation.title,
      updatedAt: at,
    );
    return Exchange(
      userMessage: userMessage,
      assistantMessage: assistantMessage,
    );
  }

  @override
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
  }) async {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      final current = _messages[index];
      _messages[index] = Message(
        id: current.id,
        conversationId: current.conversationId,
        seq: current.seq,
        role: current.role,
        content: content,
        reasoning: reasoning,
        status: status,
        error: error,
        modelId: modelId ?? current.modelId,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        cost: cost,
        createdAt: current.createdAt,
      );
    }
    final conversationIndex = _conversations.indexWhere(
      (c) => c.id == conversationId,
    );
    if (conversationIndex >= 0) {
      _conversations[conversationIndex] = _conversations[conversationIndex]
          .copyWith(updatedAt: now ?? DateTime.now());
    }
  }

  @override
  Future<int> markInterruptedRunsStopped({DateTime? now}) async {
    var count = 0;
    for (var index = 0; index < _messages.length; index++) {
      final message = _messages[index];
      if (message.status != MessageStatus.streaming) {
        continue;
      }
      _messages[index] = message.copyWith(
        status: MessageStatus.stopped,
        error: 'Interrupted before the app closed.',
      );
      count++;
    }
    return count;
  }

  static String _deriveTitle(String content) {
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return 'New chat';
    }
    if (normalized.length <= 48) {
      return normalized;
    }
    return '${normalized.substring(0, 48).trimRight()}…';
  }
}

class TestLlmFactory extends LlmClientFactory {
  TestLlmFactory(this.clients) : super();

  final List<LlmClient> clients;
  int calls = 0;
  String? lastConnectAddress;

  @override
  LlmClient create({
    required String baseUrl,
    required String apiKey,
    String? connectAddress,
  }) {
    lastConnectAddress = connectAddress;
    final index = calls < clients.length ? calls : clients.length - 1;
    calls++;
    return clients[index];
  }
}

Future<SettingsController> createSettingsController({
  AppSettings? settings,
  String apiKey = 'sk-test',
  FakeModelCatalog? modelCatalog,
}) async {
  final repository = FakeSettingsRepository()
    ..settings = settings ?? AppSettings.defaults
    ..apiKey = apiKey;
  final controller = SettingsController(
    repository: repository,
    modelCatalog: modelCatalog ?? FakeModelCatalog(),
  );
  await controller.load();
  return controller;
}
