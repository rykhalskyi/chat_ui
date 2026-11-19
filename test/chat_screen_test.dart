import 'package:chat_ui_3/app.dart';
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
    await tester.pump(const Duration(milliseconds: 100));

    expect(chat.messages, hasLength(2));
    expect(chat.messages.first.content, 'Hello');
    expect(chat.messages.last.content, 'Hi there');
    expect(chat.messages.last.promptTokens, 10);
    expect(chat.isRunning, isFalse);
    expect(find.byType(GptMarkdown), findsOneWidget);
    expect(find.text('Hello'), findsWidgets);
    expect(find.byKey(const Key('stopButton')), findsNothing);
  });
}
