enum AppThemeMode { system, light, dark }

class AppSettings {
  const AppSettings({
    required this.baseUrl,
    required this.defaultModel,
    required this.systemPrompt,
    required this.temperature,
    required this.maxTokens,
    required this.themeMode,
  });

  static const AppSettings defaults = AppSettings(
    baseUrl: 'https://llm.lan.otakeessen.com/v1',
    defaultModel: 'llama3.2-3b-cpp',
    systemPrompt: '',
    temperature: 0.7,
    maxTokens: 1024,
    themeMode: AppThemeMode.system,
  );

  final String baseUrl;
  final String defaultModel;
  final String systemPrompt;
  final double temperature;
  final int maxTokens;
  final AppThemeMode themeMode;

  AppSettings copyWith({
    String? baseUrl,
    String? defaultModel,
    String? systemPrompt,
    double? temperature,
    int? maxTokens,
    AppThemeMode? themeMode,
  }) {
    return AppSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModel: defaultModel ?? this.defaultModel,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.baseUrl == baseUrl &&
        other.defaultModel == defaultModel &&
        other.systemPrompt == systemPrompt &&
        other.temperature == temperature &&
        other.maxTokens == maxTokens &&
        other.themeMode == themeMode;
  }

  @override
  int get hashCode => Object.hash(
    baseUrl,
    defaultModel,
    systemPrompt,
    temperature,
    maxTokens,
    themeMode,
  );
}
