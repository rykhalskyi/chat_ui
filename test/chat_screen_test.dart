import 'package:chat_ui_3/app.dart';
import 'package:chat_ui_3/domain/entities/app_settings.dart';
import 'package:chat_ui_3/domain/entities/message.dart';
import 'package:chat_ui_3/data/mock_llm_client.dart';
import 'package:chat_ui_3/ui/chat/chat_controller.dart';
import 'package:chat_ui_3/ui/chat/conversations_controller.dart';
import 'package:chat_ui_3/ui/settings/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('sends a message and renders the streamed reply', (tester) async {
    final repository = FakeChatRepository();
    final conversations = ConversationsController(repository: repository);
    final settings = await createSettingsController();
    final chat = ChatController(
      repository: repository,
      settings: settings,
      clientFactory: TestLlmFactory([
        MockLlmClient(reply: 'Hi there', chunkDelay: Duration.zero),
      ]),
      conversations: conversations,
    );
    await chat.initialize();
    addTearDown(chat.dispose);
    addTearDown(conversations.dispose);
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<ConversationsController>.value(
            value: conversations,
          ),
          ChangeNotifierProvider<ChatController>.value(value: chat),
        ],
        child: const ChatUiApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('composerField')), 'Hello');
    await tester.pump();
    await tester.tap(find.byKey(const Key('sendButton')));

    for (var index = 0; index < 100 && chat.isRunning; index++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(chat.messages, hasLength(2));
    expect(chat.messages.first.content, 'Hello');
    expect(chat.messages.last.content, 'Hi there');
    expect(chat.messages.last.promptTokens, 10);
    expect(chat.isRunning, isFalse);
    expect(find.byType(GptMarkdown), findsOneWidget);
    expect(find.text('Hello'), findsWidgets);
    expect(find.byKey(const Key('stopButton')), findsNothing);
    expect(chat.messages.last.status, MessageStatus.complete);
    expect(chat.canRegenerate, isTrue);
    expect(find.textContaining('in ·'), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
    expect(find.byKey(const Key('regenerateButton')), findsOneWidget);
  });

  testWidgets('renders long markdown at large text scale in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final repository = FakeChatRepository();
    final conversation = await repository.createConversation(
      title: 'Markdown',
      modelId: 'm',
      now: DateTime(2026, 1, 1),
    );
    await repository.beginExchange(
      conversationId: conversation.id,
      userContent: 'show code',
      modelId: 'm',
      userMessageId: 'u1',
      assistantMessageId: 'a1',
      now: DateTime(2026, 1, 2),
    );
    await repository.updateAssistantMessage(
      messageId: 'a1',
      conversationId: conversation.id,
      content:
          '# Heading\n\n'
          '```dart\nvoid main() { print("hello"); }\n```\n\n'
          '${'long line ' * 120}',
      status: MessageStatus.complete,
      modelId: 'm',
      now: DateTime(2026, 1, 3),
    );

    final conversations = ConversationsController(repository: repository);
    final settings = await createSettingsController(
      settings: AppSettings.defaults.copyWith(themeMode: AppThemeMode.dark),
    );
    final chat = ChatController(
      repository: repository,
      settings: settings,
      clientFactory: TestLlmFactory([MockLlmClient()]),
      conversations: conversations,
    );
    await chat.initialize();
    addTearDown(chat.dispose);
    addTearDown(conversations.dispose);
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<ConversationsController>.value(
            value: conversations,
          ),
          ChangeNotifierProvider<ChatController>.value(value: chat),
        ],
        child: const ChatUiApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(GptMarkdown), findsOneWidget);
    final scaffoldContext = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(scaffoldContext).brightness, Brightness.dark);
  });
}
