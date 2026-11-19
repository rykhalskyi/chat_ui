import 'package:chat_ui_3/data/api_client_factory.dart';
import 'package:chat_ui_3/domain/entities/app_settings.dart';
import 'package:chat_ui_3/domain/entities/model_info.dart';
import 'package:chat_ui_3/ui/settings/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';

class _SpyApiClientFactory extends ApiClientFactory {
  _SpyApiClientFactory(this.client);

  final http.Client client;
  String? capturedConnectAddress;

  @override
  http.Client create({String? connectAddress}) {
    capturedConnectAddress = connectAddress;
    return client;
  }
}

void main() {
  test('loads persisted settings and api key', () async {
    final repository = FakeSettingsRepository()
      ..settings = AppSettings.defaults.copyWith(
        baseUrl: 'https://example.test/v1',
        defaultModel: 'gemma3-1b-cpp',
        themeMode: AppThemeMode.dark,
      )
      ..apiKey = 'sk-stored';
    final controller = SettingsController(
      repository: repository,
      modelCatalog: FakeModelCatalog(),
    );

    await controller.load();

    expect(controller.isLoading, isFalse);
    expect(controller.settings.baseUrl, 'https://example.test/v1');
    expect(controller.settings.defaultModel, 'gemma3-1b-cpp');
    expect(controller.settings.themeMode, AppThemeMode.dark);
    expect(controller.apiKey, 'sk-stored');
    expect(controller.errorMessage, isNull);
  });

  test('save persists settings and api key', () async {
    final repository = FakeSettingsRepository();
    final controller = SettingsController(
      repository: repository,
      modelCatalog: FakeModelCatalog(),
    );
    await controller.load();
    final settings = AppSettings.defaults.copyWith(
      baseUrl: 'https://other.test/v1',
      temperature: 0.2,
      maxTokens: 512,
    );

    final saved = await controller.save(settings: settings, apiKey: 'sk-new');

    expect(saved, isTrue);
    expect(repository.settings, settings);
    expect(repository.apiKey, 'sk-new');
    expect(controller.settings, settings);
    expect(controller.isSaving, isFalse);
  });

  test('setThemeMode persists without changing other settings', () async {
    final repository = FakeSettingsRepository();
    final controller = SettingsController(
      repository: repository,
      modelCatalog: FakeModelCatalog(),
    );
    await controller.load();

    await controller.setThemeMode(AppThemeMode.light);

    expect(controller.settings.themeMode, AppThemeMode.light);
    expect(repository.settings.themeMode, AppThemeMode.light);
    expect(repository.settings.baseUrl, AppSettings.defaults.baseUrl);
  });

  test('testConnection returns models on success', () async {
    final catalog = FakeModelCatalog(
      models: const [
        ModelInfo(id: 'llama3.2-3b-cpp'),
        ModelInfo(id: 'gemma3-1b-cpp'),
      ],
    );
    final controller = SettingsController(
      repository: FakeSettingsRepository(),
      modelCatalog: catalog,
    );
    await controller.load();

    await controller.testConnection(
      baseUrl: 'https://example.test/v1',
      apiKey: 'sk-test',
    );

    final result = controller.connectionResult;
    expect(result, isA<ConnectionTestSuccess>());
    expect((result as ConnectionTestSuccess).models, hasLength(2));
    expect(controller.isTesting, isFalse);
    expect(catalog.lastBaseUrl, 'https://example.test/v1');
    expect(catalog.lastApiKey, 'sk-test');
  });

  test('testConnection exposes the failure message', () async {
    final controller = SettingsController(
      repository: FakeSettingsRepository(),
      modelCatalog: FakeModelCatalog(errorMessage: 'HTTP 400: bad key'),
    );
    await controller.load();

    await controller.testConnection(
      baseUrl: 'https://example.test/v1',
      apiKey: 'wrong',
    );

    final result = controller.connectionResult;
    expect(result, isA<ConnectionTestFailure>());
    expect((result as ConnectionTestFailure).message, 'HTTP 400: bad key');
  });

  test('testConnection uses the LAN connect address', () async {
    final spy = _SpyApiClientFactory(
      MockClient((request) async {
        expect(request.url.host, 'example.test');
        return http.Response('{"data":[{"id":"llama3.2-3b-cpp"}]}', 200);
      }),
    );
    final controller = SettingsController(
      repository: FakeSettingsRepository(),
      modelCatalog: FakeModelCatalog(),
      apiClientFactory: spy,
    );
    await controller.load();

    await controller.testConnection(
      baseUrl: 'https://example.test/v1',
      apiKey: 'sk-test',
      connectAddress: '192.168.2.240',
    );

    expect(spy.capturedConnectAddress, '192.168.2.240');
    final result = controller.connectionResult;
    expect(result, isA<ConnectionTestSuccess>());
    expect(
      (result as ConnectionTestSuccess).models.single.id,
      'llama3.2-3b-cpp',
    );
  });
}
