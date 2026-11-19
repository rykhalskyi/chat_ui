import 'package:chat_ui_3/core/exceptions.dart';
import 'package:chat_ui_3/data/db/app_database.dart';
import 'package:chat_ui_3/data/mock_llm_client.dart';
import 'package:chat_ui_3/data/sqflite_chat_repository.dart';
import 'package:chat_ui_3/domain/entities/message.dart';
import 'package:chat_ui_3/ui/chat/chat_controller.dart';
import 'package:chat_ui_3/ui/chat/conversations_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fakes.dart';

Future<void> settle(ChatController chat) async {
  for (var index = 0; index < 200 && chat.isRunning; index++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  await Future<void>.delayed(const Duration(milliseconds: 10));
}

void main() {
  late AppDatabase database;
  late SqfliteChatRepository repository;
  late ConversationsController conversations;
  late ChatController chat;
  late TestLlmFactory factory;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = SqfliteChatRepository(database: database);
    conversations = ConversationsController(repository: repository);
    factory = TestLlmFactory([
      MockLlmClient(reply: 'Hi there', chunkDelay: Duration.zero),
    ]);
    final settings = await createSettingsController();
    chat = ChatController(
      repository: repository,
      settings: settings,
      clientFactory: factory,
      conversations: conversations,
    );
  });

  tearDown(() async {
    chat.dispose();
    conversations.dispose();
    await database.close();
  });

  test('send creates a chat, streams a reply, and persists it', () async {
    await chat.initialize();
    expect(chat.active, isNull);

    await chat.send('Hello');
    await settle(chat);

    expect(chat.active, isNotNull);
    expect(chat.active!.title, 'Hello');
    expect(chat.messages, hasLength(2));
    expect(chat.messages.first.content, 'Hello');
    final assistant = chat.messages.last;
    expect(assistant.status, MessageStatus.complete);
    expect(assistant.content, 'Hi there');
    expect(assistant.promptTokens, 10);
    expect(chat.phase, ChatRunPhase.idle);
    expect(chat.contextTrimmed, isFalse);
    expect(conversations.conversations.single.title, 'Hello');

    final persisted = await repository.listMessages(chat.active!.id);
    expect(persisted, hasLength(2));
    expect(persisted.last.content, 'Hi there');
    expect(persisted.last.status, MessageStatus.complete);
  });

  test('cancel keeps the partial reply as stopped', () async {
    chat.dispose();
    factory = TestLlmFactory([
      MockLlmClient(
        reply: 'one two three four five six',
        chunkDelay: const Duration(milliseconds: 40),
      ),
    ]);
    final settings = await createSettingsController();
    chat = ChatController(
      repository: repository,
      settings: settings,
      clientFactory: factory,
      conversations: conversations,
    );
    await chat.initialize();

    await chat.send('hi');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await chat.cancel();
    await settle(chat);

    final assistant = chat.messages.last;
    expect(assistant.status, MessageStatus.stopped);
    expect(chat.phase, ChatRunPhase.cancelled);
    expect(assistant.content.isNotEmpty, isTrue);
    expect(assistant.content, isNot('one two three four five six'));

    final persisted = await repository.listMessages(chat.active!.id);
    expect(persisted.last.status, MessageStatus.stopped);
  });

  test(
    'stream failure marks the reply as an error and retry succeeds',
    () async {
      chat.dispose();
      final failing = MockLlmClient(
        reply: 'one two three',
        chunkDelay: Duration.zero,
        failAfterContentChunks: 1,
        error: const LlmException(LlmErrorKind.server, 'boom'),
      );
      final succeeding = MockLlmClient(
        reply: 'recovered',
        chunkDelay: Duration.zero,
      );
      factory = TestLlmFactory([failing, succeeding]);
      final settings = await createSettingsController();
      chat = ChatController(
        repository: repository,
        settings: settings,
        clientFactory: factory,
        conversations: conversations,
      );
      await chat.initialize();

      await chat.send('hi');
      await settle(chat);

      expect(chat.phase, ChatRunPhase.failed);
      expect(chat.messages.last.status, MessageStatus.error);
      expect(chat.messages.last.error, 'Server error: boom');
      expect(chat.canRetry, isTrue);

      await chat.retryLast();
      await settle(chat);

      expect(chat.phase, ChatRunPhase.idle);
      expect(chat.messages, hasLength(2));
      expect(chat.messages.last.status, MessageStatus.complete);
      expect(chat.messages.last.content, 'recovered');
      expect(factory.calls, 2);
    },
  );

  test('stores reasoning content from the stream', () async {
    chat.dispose();
    factory = TestLlmFactory([
      MockLlmClient(
        reply: 'answer',
        reasoning: 'thinking deeply',
        chunkDelay: Duration.zero,
      ),
    ]);
    final settings = await createSettingsController();
    chat = ChatController(
      repository: repository,
      settings: settings,
      clientFactory: factory,
      conversations: conversations,
    );
    await chat.initialize();

    await chat.send('hi');
    await settle(chat);

    expect(chat.phase, ChatRunPhase.idle);
    expect(chat.messages.last.reasoning, 'thinking deeply');
    expect(chat.messages.last.content, 'answer');
    final persisted = await repository.listMessages(chat.active!.id);
    expect(persisted.last.reasoning, 'thinking deeply');
  });

  test('changing the model updates the conversation', () async {
    await chat.initialize();
    await chat.send('hi');
    await settle(chat);

    await chat.setModel('gemma3-1b-cpp');

    expect(chat.selectedModel, 'gemma3-1b-cpp');
    final conversation = await repository.getConversation(chat.active!.id);
    expect(conversation!.modelId, 'gemma3-1b-cpp');
    expect(conversations.conversations.single.modelId, 'gemma3-1b-cpp');
  });

  test('opening a conversation loads its history', () async {
    final conversation = await conversations.create(modelId: 'llama3.2-3b-cpp');
    await repository.beginExchange(
      conversationId: conversation.id,
      userContent: 'stored question',
      modelId: 'llama3.2-3b-cpp',
    );
    await chat.initialize();
    if (chat.active?.id != conversation.id) {
      await chat.open(conversation);
    }

    expect(chat.messages, hasLength(2));
    expect(chat.messages.first.content, 'stored question');
    expect(chat.selectedModel, 'llama3.2-3b-cpp');
  });
}
