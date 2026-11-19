import 'package:sqflite/sqflite.dart';

import '../../domain/entities/chat_role.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';

class ChatDao {
  ChatDao(this._db);

  final Database _db;

  Future<List<Conversation>> listConversations([
    DatabaseExecutor? executor,
  ]) async {
    final rows = await _executor(executor)
        .query('conversations', orderBy: 'updated_at DESC');
    return rows.map(_conversationFromRow).toList();
  }

  Future<Conversation?> getConversation(
    String id, [
    DatabaseExecutor? executor,
  ]) async {
    final rows = await _executor(executor)
        .query('conversations', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _conversationFromRow(rows.first);
  }

  Future<void> insertConversation(
    Conversation conversation, [
    DatabaseExecutor? executor,
  ]) async {
    await _executor(executor)
        .insert('conversations', _conversationToRow(conversation));
  }

  Future<void> updateConversationTitle({
    required String id,
    required String title,
    required int updatedAt,
    DatabaseExecutor? executor,
  }) async {
    await _executor(executor).update(
      'conversations',
      {'title': title, 'updated_at': updatedAt},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateConversationModel({
    required String id,
    required String modelId,
    required int updatedAt,
    DatabaseExecutor? executor,
  }) async {
    await _executor(executor).update(
      'conversations',
      {'model_id': modelId, 'updated_at': updatedAt},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> touchConversation({
    required String id,
    required int updatedAt,
    DatabaseExecutor? executor,
  }) async {
    await _executor(executor).update(
      'conversations',
      {'updated_at': updatedAt},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteConversation(
    String id, [
    DatabaseExecutor? executor,
  ]) async {
    await _executor(executor)
        .delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Message>> listMessages(
    String conversationId, [
    DatabaseExecutor? executor,
  ]) async {
    final rows = await _executor(executor).query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'seq ASC',
    );
    return rows.map(_messageFromRow).toList();
  }

  Future<int> nextSeq(
    String conversationId, [
    DatabaseExecutor? executor,
  ]) async {
    final rows = await _executor(executor).rawQuery(
      'SELECT COALESCE(MAX(seq), 0) + 1 AS next_seq '
      'FROM messages WHERE conversation_id = ?',
      [conversationId],
    );
    return (rows.first['next_seq'] as num).toInt();
  }

  Future<void> insertMessage(
    Message message, [
    DatabaseExecutor? executor,
  ]) async {
    await _executor(executor).insert('messages', _messageToRow(message));
  }

  Future<void> updateAssistantMessage({
    required String messageId,
    required String content,
    required MessageStatus status,
    String? reasoning,
    String? error,
    String? modelId,
    int? promptTokens,
    int? completionTokens,
    double? cost,
    DatabaseExecutor? executor,
  }) async {
    await _executor(executor).update(
      'messages',
      {
        'content': content,
        'reasoning': reasoning,
        'status': status.name,
        'error': error,
        'model_id': modelId,
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'cost': cost,
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> markStreamingAsStopped({
    required int updatedAt,
    required String error,
    DatabaseExecutor? executor,
  }) async {
    final db = _executor(executor);
    final rows = await db.rawQuery(
      'SELECT DISTINCT conversation_id FROM messages WHERE status = ?',
      [MessageStatus.streaming.name],
    );
    final updated = await db.update(
      'messages',
      {'status': MessageStatus.stopped.name, 'error': error},
      where: 'status = ?',
      whereArgs: [MessageStatus.streaming.name],
    );
    for (final row in rows) {
      await touchConversation(
        id: row['conversation_id'] as String,
        updatedAt: updatedAt,
        executor: db,
      );
    }
    return updated;
  }

  DatabaseExecutor _executor(DatabaseExecutor? executor) => executor ?? _db;

  static Conversation _conversationFromRow(Map<String, Object?> row) {
    return Conversation(
      id: row['id'] as String,
      title: row['title'] as String,
      modelId: row['model_id'] as String,
      systemPrompt: row['system_prompt'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  static Map<String, Object?> _conversationToRow(Conversation conversation) {
    return {
      'id': conversation.id,
      'title': conversation.title,
      'model_id': conversation.modelId,
      'system_prompt': conversation.systemPrompt,
      'created_at': conversation.createdAt.millisecondsSinceEpoch,
      'updated_at': conversation.updatedAt.millisecondsSinceEpoch,
    };
  }

  static Message _messageFromRow(Map<String, Object?> row) {
    return Message(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      seq: (row['seq'] as num).toInt(),
      role: ChatRole.fromName(row['role'] as String),
      content: row['content'] as String? ?? '',
      reasoning: row['reasoning'] as String?,
      status: MessageStatus.fromName(row['status'] as String),
      error: row['error'] as String?,
      modelId: row['model_id'] as String?,
      promptTokens: (row['prompt_tokens'] as num?)?.toInt(),
      completionTokens: (row['completion_tokens'] as num?)?.toInt(),
      cost: (row['cost'] as num?)?.toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    );
  }

  static Map<String, Object?> _messageToRow(Message message) {
    return {
      'id': message.id,
      'conversation_id': message.conversationId,
      'seq': message.seq,
      'role': message.role.name,
      'content': message.content,
      'reasoning': message.reasoning,
      'status': message.status.name,
      'error': message.error,
      'model_id': message.modelId,
      'prompt_tokens': message.promptTokens,
      'completion_tokens': message.completionTokens,
      'cost': message.cost,
      'created_at': message.createdAt.millisecondsSinceEpoch,
    };
  }
}
