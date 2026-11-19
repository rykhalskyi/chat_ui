import '../entities/app_settings.dart';

abstract interface class SettingsRepository {
  Future<AppSettings> loadSettings();

  Future<void> saveSettings(AppSettings settings);

  Future<String> loadApiKey();

  Future<void> saveApiKey(String apiKey);
}
