import 'package:chat_ui_3/app.dart';
import 'package:chat_ui_3/data/mock_llm_client.dart';
import 'package:chat_ui_3/ui/chat/chat_controller.dart';
import 'package:chat_ui_3/ui/chat/conversations_controller.dart';
import 'package:chat_ui_3/ui/settings/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('empty chat opens settings', (tester) async {
    final repository = FakeChatRepository();
    final conversations = ConversationsController(repository: repository);
    final settings = await createSettingsController();
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

    expect(find.text('Chat UI'), findsWidgets);
    expect(find.text('How can I help?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('openSettingsButton')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('LiteLLM connection'), findsOneWidget);
    expect(find.byKey(const Key('baseUrlField')), findsOneWidget);
  });
}
