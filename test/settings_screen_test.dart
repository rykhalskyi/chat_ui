import 'package:chat_ui_3/core/app_theme.dart';
import 'package:chat_ui_3/domain/entities/model_info.dart';
import 'package:chat_ui_3/ui/settings/settings_controller.dart';
import 'package:chat_ui_3/ui/settings/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('settings screen tests the connection and saves', (tester) async {
    final repository = FakeSettingsRepository();
    final catalog = FakeModelCatalog(
      models: const [
        ModelInfo(id: 'gemma3-1b-cpp'),
        ModelInfo(id: 'llama3.2-3b-cpp'),
      ],
    );
    final controller = SettingsController(
      repository: repository,
      modelCatalog: catalog,
    );
    await controller.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsController>.value(
        value: controller,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('baseUrlField')),
      'https://example.test/v1',
    );
    await tester.enterText(find.byKey(const Key('apiKeyField')), 'sk-test');

    await tester.ensureVisible(find.byKey(const Key('testConnectionButton')));
    await tester.tap(find.byKey(const Key('testConnectionButton')));
    await tester.pumpAndSettle();

    expect(find.text('Connected — 2 models'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('saveSettingsButton')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('saveSettingsButton')));
    await tester.pumpAndSettle();

    expect(repository.settings.baseUrl, 'https://example.test/v1');
    expect(repository.apiKey, 'sk-test');
    expect(find.text('Settings saved.'), findsOneWidget);
  });
}
