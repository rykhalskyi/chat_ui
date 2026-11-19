import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/app_settings.dart';
import '../domain/repositories/settings_repository.dart';

class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository({required this.prefs, required this.secureStorage});

  static const _baseUrlKey = 'settings.baseUrl';
  static const _defaultModelKey = 'settings.defaultModel';
  static const _systemPromptKey = 'settings.systemPrompt';
  static const _temperatureKey = 'settings.temperature';
  static const _maxTokensKey = 'settings.maxTokens';
  static const _themeModeKey = 'settings.themeMode';
  static const _apiKeyKey = 'litellm.apiKey';

  final SharedPreferences prefs;
  final FlutterSecureStorage secureStorage;

  @override
  Future<AppSettings> loadSettings() async {
    const defaults = AppSettings.defaults;
    final themeName = prefs.getString(_themeModeKey);
    return AppSettings(
      baseUrl: prefs.getString(_baseUrlKey) ?? defaults.baseUrl,
      defaultModel: prefs.getString(_defaultModelKey) ?? defaults.defaultModel,
      systemPrompt: prefs.getString(_systemPromptKey) ?? defaults.systemPrompt,
      temperature: prefs.getDouble(_temperatureKey) ?? defaults.temperature,
      maxTokens: prefs.getInt(_maxTokensKey) ?? defaults.maxTokens,
      themeMode: AppThemeMode.values.firstWhere(
        (mode) => mode.name == themeName,
        orElse: () => AppThemeMode.system,
      ),
    );
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await Future.wait([
      prefs.setString(_baseUrlKey, settings.baseUrl),
      prefs.setString(_defaultModelKey, settings.defaultModel),
      prefs.setString(_systemPromptKey, settings.systemPrompt),
      prefs.setDouble(_temperatureKey, settings.temperature),
      prefs.setInt(_maxTokensKey, settings.maxTokens),
      prefs.setString(_themeModeKey, settings.themeMode.name),
    ]);
  }

  @override
  Future<String> loadApiKey() async {
    return await secureStorage.read(key: _apiKeyKey) ?? '';
  }

  @override
  Future<void> saveApiKey(String apiKey) async {
    if (apiKey.isEmpty) {
      await secureStorage.delete(key: _apiKeyKey);
      return;
    }
    await secureStorage.write(key: _apiKeyKey, value: apiKey);
  }
}
