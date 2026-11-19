import 'package:flutter/foundation.dart';

import '../../data/api_client_factory.dart';
import '../../data/model_catalog_client.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/model_info.dart';
import '../../domain/repositories/settings_repository.dart';

sealed class ConnectionTestResult {
  const ConnectionTestResult();
}

final class ConnectionTestSuccess extends ConnectionTestResult {
  const ConnectionTestSuccess(this.models);

  final List<ModelInfo> models;
}

final class ConnectionTestFailure extends ConnectionTestResult {
  const ConnectionTestFailure(this.message);

  final String message;
}

class SettingsController extends ChangeNotifier {
  SettingsController({
    required this.repository,
    required this.modelCatalog,
    this.apiClientFactory = const ApiClientFactory(),
  });

  final SettingsRepository repository;
  final ModelCatalogClient modelCatalog;
  final ApiClientFactory apiClientFactory;

  AppSettings _settings = AppSettings.defaults;
  String _apiKey = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _errorMessage;
  ConnectionTestResult? _connectionResult;

  AppSettings get settings => _settings;
  String get apiKey => _apiKey;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isTesting => _isTesting;
  String? get errorMessage => _errorMessage;
  ConnectionTestResult? get connectionResult => _connectionResult;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _settings = await repository.loadSettings();
    } catch (error) {
      _errorMessage = 'Could not load settings: $error';
    }
    try {
      _apiKey = await repository.loadApiKey();
    } catch (error) {
      _errorMessage ??= 'Could not read the stored API key: $error';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> save({
    required AppSettings settings,
    required String apiKey,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await repository.saveSettings(settings);
      await repository.saveApiKey(apiKey);
      _settings = settings;
      _apiKey = apiKey;
      return true;
    } catch (error) {
      _errorMessage = 'Could not save settings: $error';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_settings.themeMode == mode) {
      return;
    }
    final updated = _settings.copyWith(themeMode: mode);
    _settings = updated;
    notifyListeners();
    try {
      await repository.saveSettings(updated);
    } catch (error) {
      _errorMessage = 'Could not save the theme: $error';
      notifyListeners();
    }
  }

  Future<void> testConnection({
    required String baseUrl,
    required String apiKey,
    String? connectAddress,
  }) async {
    _isTesting = true;
    _connectionResult = null;
    notifyListeners();
    try {
      final address = connectAddress?.trim() ?? '';
      final catalog = address.isEmpty
          ? modelCatalog
          : ModelCatalogClient(
              clientFactory: () =>
                  apiClientFactory.create(connectAddress: address),
            );
      final models = await catalog.fetchModels(
        baseUrl: baseUrl,
        apiKey: apiKey,
      );
      _connectionResult = ConnectionTestSuccess(models);
    } on ModelCatalogException catch (error) {
      _connectionResult = ConnectionTestFailure(error.message);
    } catch (error) {
      _connectionResult = ConnectionTestFailure('Connection failed: $error');
    } finally {
      _isTesting = false;
      notifyListeners();
    }
  }

  void clearConnectionResult() {
    if (_connectionResult == null) {
      return;
    }
    _connectionResult = null;
    notifyListeners();
  }
}
