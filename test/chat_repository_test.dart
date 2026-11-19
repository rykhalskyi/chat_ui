import 'dart:io';

import 'package:chat_ui_3/data/db/app_database.dart';
import 'package:chat_ui_3/data/sqflite_chat_repository.dart';
import 'package:chat_ui_3/domain/entities/chat_role.dart';
import 'package:chat_ui_3/domain/entities/message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DateTime at(int milliseconds) =>
    DateTime.fromMillisecondsSinceEpoch(milliseconds);

void main() {
  late AppDatabase database;
  late SqfliteChatRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = SqfliteChatRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('creates conversations and lists them by updated time', () async {
    await repository.createConversation(
      id: 'c1',
      title: 'First',
      modelId: 'llama3.2-3b-cpp',
      now: at(1000),
    );
    await repository.createConversation(
      id: 'c2',
      title: 'Second',
      modelId: 'gemma3-1b-cpp',
      now: at(2000),
    );

    var conversations = await repository.listConversations();
    expect(conversations.map((c) => c.id), ['c2', 'c1']);

    await repository.renameConversation('c1', 'Renamed', now: at(3000));
    conversations = await repository.listConversations();
    expect(conversations.map((c) => c.id), ['c1', 'c2']);
    expect(conversations.first.title, 'Renamed');
  });

  test(
    'begins an exchange and derives the title from the first message',
    () async {
      await repository.createConversation(
        id: 'c1',
        title: SqfliteChatRepository.defaultConversationTitle,
        modelId: 'llama3.2-3b-cpp',
        now: at(1000),
      );

      final exchange = await repository.beginExchange(
        conversationId: 'c1',
        userContent: '  How   do I use LiteLLM?  ',
        modelId: 'llama3.2-3b-cpp',
        userMessageId: 'u1',
        assistantMessageId: 'a1',
        now: at(2000),
      );

      expect(exchange.userMessage.seq, 1);
      expect(exchange.userMessage.role, ChatRole.user);
      expect(exchange.userMessage.content, '  How   do I use LiteLLM?  ');
      expect(exchange.assistantMessage.seq, 2);
      expect(exchange.assistantMessage.role, ChatRole.assistant);
      expect(exchange.assistantMessage.status, MessageStatus.streaming);
      expect(exchange.assistantMessage.modelId, 'llama3.2-3b-cpp');

      final conversation = await repository.getConversation('c1');
      expect(conversation!.title, 'How do I use LiteLLM?');
      expect(conversation.updatedAt, at(2000));

      final messages = await repository.listMessages('c1');
      expect(messages.map((m) => m.id), ['u1', 'a1']);
    },
  );

  test('updates the assistant message and metadata', () async {
    await repository.createConversation(
      id: 'c1',
      title: 'Chat',
      modelId: 'llama3.2-3b-cpp',
      now: at(1000),
    );
    final exchange = await repository.beginExchange(
      conversationId: 'c1',
      userContent: 'hi',
      modelId: 'llama3.2-3b-cpp',
      userMessageId: 'u1',
      assistantMessageId: 'a1',
      now: at(2000),
    );

    await repository.updateAssistantMessage(
      messageId: exchange.assistantMessage.id,
      conversationId: 'c1',
      content: 'Hello there',
      reasoning: 'Think first',
      status: MessageStatus.complete,
      modelId: 'llama3.2-3b-cpp',
      promptTokens: 5,
      completionTokens: 2,
      cost: 0.001,
      now: at(3000),
    );

    final messages = await repository.listMessages('c1');
    final assistant = messages.last;
    expect(assistant.content, 'Hello there');
    expect(assistant.reasoning, 'Think first');
    expect(assistant.status, MessageStatus.complete);
    expect(assistant.promptTokens, 5);
    expect(assistant.completionTokens, 2);
    expect(assistant.cost, 0.001);

    final conversation = await repository.getConversation('c1');
    expect(conversation!.updatedAt, at(3000));
  });

  test('deleting a conversation cascades to messages', () async {
    await repository.createConversation(
      id: 'c1',
      title: 'Chat',
      modelId: 'm',
      now: at(1000),
    );
    await repository.beginExchange(
      conversationId: 'c1',
      userContent: 'hi',
      modelId: 'm',
      now: at(2000),
    );
    expect(await repository.listMessages('c1'), hasLength(2));

    await repository.deleteConversation('c1');

    expect(await repository.getConversation('c1'), isNull);
    expect(await database.database.query('messages'), isEmpty);
  });

  test('marks interrupted streaming runs as stopped', () async {
    await repository.createConversation(
      id: 'c1',
      title: 'Chat one',
      modelId: 'm',
      now: at(1000),
    );
    await repository.createConversation(
      id: 'c2',
      title: 'Chat two',
      modelId: 'm',
      now: at(1000),
    );
    await repository.beginExchange(
      conversationId: 'c1',
      userContent: 'a',
      modelId: 'm',
      now: at(2000),
    );
    await repository.beginExchange(
      conversationId: 'c2',
      userContent: 'b',
      modelId: 'm',
      now: at(2000),
    );

    final count = await repository.markInterruptedRunsStopped(now: at(4000));

    expect(count, 2);
    for (final conversationId in ['c1', 'c2']) {
      final messages = await repository.listMessages(conversationId);
      final assistant = messages.last;
      expect(assistant.status, MessageStatus.stopped);
      expect(assistant.error, isNotNull);
    }
  });

  test('round-trips long message content', () async {
    await repository.createConversation(
      id: 'c1',
      title: 'Long',
      modelId: 'm',
      now: at(1000),
    );
    final exchange = await repository.beginExchange(
      conversationId: 'c1',
      userContent: 'hi',
      modelId: 'm',
      now: at(2000),
    );
    final longText = 'x' * 10000;

    await repository.updateAssistantMessage(
      messageId: exchange.assistantMessage.id,
      conversationId: 'c1',
      content: longText,
      status: MessageStatus.complete,
      now: at(3000),
    );

    final messages = await repository.listMessages('c1');
    expect(messages.last.content.length, 10000);
  });

  test('persists across database reopen', () async {
    final directory = await Directory.systemTemp.createTemp('chat_ui_repo_');
    final path = p.join(directory.path, 'chat.db');
    try {
      final first = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      final firstRepository = SqfliteChatRepository(database: first);
      await firstRepository.createConversation(
        id: 'c1',
        title: 'Persisted',
        modelId: 'm',
        now: at(1000),
      );
      await firstRepository.beginExchange(
        conversationId: 'c1',
        userContent: 'Remember me',
        modelId: 'm',
        userMessageId: 'u1',
        assistantMessageId: 'a1',
        now: at(2000),
      );
      await first.close();

      final second = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      final secondRepository = SqfliteChatRepository(database: second);
      final conversations = await secondRepository.listConversations();
      expect(conversations.single.id, 'c1');
      final messages = await secondRepository.listMessages('c1');
      expect(messages.map((message) => message.id), ['u1', 'a1']);
      await second.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('deriveTitle normalizes whitespace and truncates', () {
    expect(SqfliteChatRepository.deriveTitle('  a   b  '), 'a b');
    expect(
      SqfliteChatRepository.deriveTitle('   '),
      SqfliteChatRepository.defaultConversationTitle,
    );
    final long = 'word ' * 20;
    final title = SqfliteChatRepository.deriveTitle(long);
    expect(title.endsWith('…'), isTrue);
    expect(title.length, lessThanOrEqualTo(49));
  });
}
