import 'package:uuid/uuid.dart';

import '../domain/entities/chat_role.dart';
import '../domain/entities/conversation.dart';
import '../domain/entities/message.dart';
import '../domain/repositories/chat_repository.dart';
import 'db/app_database.dart';
import 'db/chat_dao.dart';

class SqfliteChatRepository implements ChatRepository {
  SqfliteChatRepository({
    required AppDatabase database,
    ChatDao? dao,
    Uuid? uuid,
    DateTime Function()? clock,
  }) : _database = database,
       _dao = dao ?? ChatDao(database.database),
       _uuid = uuid ?? const Uuid(),
       _clock = clock ?? DateTime.now;

  static const defaultConversationTitle = 'New chat';

  final AppDatabase _database;
  final ChatDao _dao;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  Future<List<Conversation>> listConversations() {
    return _dao.listConversations();
  }

  @override
  Future<Conversation?> getConversation(String id) {
    return _dao.getConversation(id);
  }

  @override
  Future<Conversation> createConversation({
    required String title,
    required String modelId,
    String? systemPrompt,
    String? id,
    DateTime? now,
  }) async {
    final at = now ?? _clock();
    final normalizedTitle = title.trim();
    final conversation = Conversation(
      id: id ?? _uuid.v4(),
      title: normalizedTitle.isEmpty
          ? defaultConversationTitle
          : normalizedTitle,
      modelId: modelId,
      systemPrompt: systemPrompt,
      createdAt: at,
      updatedAt: at,
    );
    await _dao.insertConversation(conversation);
    return conversation;
  }

  @override
  Future<void> renameConversation(
    String id,
    String title, {
    DateTime? now,
  }) async {
    final normalizedTitle = title.trim();
    await _dao.updateConversationTitle(
      id: id,
      title: normalizedTitle.isEmpty
          ? defaultConversationTitle
          : normalizedTitle,
      updatedAt: (now ?? _clock()).millisecondsSinceEpoch,
    );
  }

  @override
  Future<void> deleteConversation(String id) {
    return _dao.deleteConversation(id);
  }

  @override
  Future<void> updateConversationModel(
    String id,
    String modelId, {
    DateTime? now,
  }) {
    return _dao.updateConversationModel(
      id: id,
      modelId: modelId,
      updatedAt: (now ?? _clock()).millisecondsSinceEpoch,
    );
  }

  @override
  Future<List<Message>> listMessages(String conversationId) {
    return _dao.listMessages(conversationId);
  }

  @override
  Future<Exchange> beginExchange({
    required String conversationId,
    required String userContent,
    required String modelId,
    String? userMessageId,
    String? assistantMessageId,
    DateTime? now,
  }) {
    return _database.database.transaction((transaction) async {
      final conversation = await _dao.getConversation(
        conversationId,
        transaction,
      );
      if (conversation == null) {
        throw StateError('Conversation $conversationId does not exist.');
      }
      final at = now ?? _clock();
      final seq = await _dao.nextSeq(conversationId, transaction);
      final userMessage = Message(
        id: userMessageId ?? _uuid.v4(),
        conversationId: conversationId,
        seq: seq,
        role: ChatRole.user,
        content: userContent,
        status: MessageStatus.complete,
        createdAt: at,
      );
      final assistantMessage = Message(
        id: assistantMessageId ?? _uuid.v4(),
        conversationId: conversationId,
        seq: seq + 1,
        role: ChatRole.assistant,
        content: '',
        status: MessageStatus.streaming,
        modelId: modelId,
        createdAt: at,
      );
      await _dao.insertMessage(userMessage, transaction);
      await _dao.insertMessage(assistantMessage, transaction);
      final updatedAt = at.millisecondsSinceEpoch;
      if (conversation.title == defaultConversationTitle) {
        await _dao.updateConversationTitle(
          id: conversationId,
          title: deriveTitle(userContent),
          updatedAt: updatedAt,
          executor: transaction,
        );
      } else {
        await _dao.touchConversation(
          id: conversationId,
          updatedAt: updatedAt,
          executor: transaction,
        );
      }
      return Exchange(
        userMessage: userMessage,
        assistantMessage: assistantMessage,
      );
    });
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
  }) {
    return _database.database.transaction((transaction) async {
      await _dao.updateAssistantMessage(
        messageId: messageId,
        content: content,
        status: status,
        reasoning: reasoning,
        error: error,
        modelId: modelId,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        cost: cost,
        executor: transaction,
      );
      await _dao.touchConversation(
        id: conversationId,
        updatedAt: (now ?? _clock()).millisecondsSinceEpoch,
        executor: transaction,
      );
    });
  }

  @override
  Future<int> markInterruptedRunsStopped({DateTime? now}) {
    return _database.database.transaction((transaction) {
      return _dao.markStreamingAsStopped(
        updatedAt: (now ?? _clock()).millisecondsSinceEpoch,
        error: 'Interrupted before the app closed.',
        executor: transaction,
      );
    });
  }

  static String deriveTitle(String content) {
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return defaultConversationTitle;
    }
    if (normalized.length <= 48) {
      return normalized;
    }
    return '${normalized.substring(0, 48).trimRight()}…';
  }
}
