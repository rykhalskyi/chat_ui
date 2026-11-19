import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'domain/entities/app_settings.dart';
import 'ui/chat/chat_screen.dart';
import 'ui/settings/settings_controller.dart';

class ChatUiApp extends StatelessWidget {
  const ChatUiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<SettingsController, AppThemeMode>(
      (controller) => controller.settings.themeMode,
    );
    return MaterialApp(
      title: 'Chat UI',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (mode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      home: const ChatScreen(),
    );
  }
}
