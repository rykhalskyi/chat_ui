import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'data/llm_client_factory.dart';
import 'data/model_catalog_client.dart';
import 'data/prefs_settings_repository.dart';
import 'data/sqflite_chat_repository.dart';
import 'domain/repositories/chat_repository.dart';
import 'domain/repositories/settings_repository.dart';
import 'ui/chat/chat_controller.dart';
import 'ui/chat/conversations_controller.dart';
import 'ui/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final repository = PrefsSettingsRepository(
    prefs: prefs,
    secureStorage: const FlutterSecureStorage(),
  );
  final settingsController = SettingsController(
    repository: repository,
    modelCatalog: ModelCatalogClient(),
  );
  await settingsController.load();

  final database = await AppDatabase.open();
  final chatRepository = SqfliteChatRepository(database: database);
  await chatRepository.markInterruptedRunsStopped();

  final conversationsController = ConversationsController(
    repository: chatRepository,
  );
  final chatController = ChatController(
    repository: chatRepository,
    settings: settingsController,
    clientFactory: const LlmClientFactory(),
    conversations: conversationsController,
  );
  await chatController.initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider<SettingsRepository>.value(value: repository),
        Provider<AppDatabase>.value(value: database),
        Provider<ChatRepository>.value(value: chatRepository),
        ChangeNotifierProvider<SettingsController>.value(
          value: settingsController,
        ),
        ChangeNotifierProvider<ConversationsController>.value(
          value: conversationsController,
        ),
        ChangeNotifierProvider<ChatController>.value(value: chatController),
      ],
      child: const ChatUiApp(),
    ),
  );
}
