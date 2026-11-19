enum AppThemeMode { system, light, dark }

class AppSettings {
  const AppSettings({
    required this.baseUrl,
    required this.defaultModel,
    required this.systemPrompt,
    required this.temperature,
    required this.maxTokens,
    required this.themeMode,
    required this.useConnectAddress,
    required this.connectAddress,
  });

  static const AppSettings defaults = AppSettings(
    baseUrl: 'https://llm.lan.otakeessen.com/v1',
    defaultModel: 'llama3.2-3b-cpp',
    systemPrompt: '',
    temperature: 0.7,
    maxTokens: 1024,
    themeMode: AppThemeMode.system,
    useConnectAddress: false,
    connectAddress: '',
  );

  final String baseUrl;
  final String defaultModel;
  final String systemPrompt;
  final double temperature;
  final int maxTokens;
  final AppThemeMode themeMode;
  final bool useConnectAddress;
  final String connectAddress;

  AppSettings copyWith({
    String? baseUrl,
    String? defaultModel,
    String? systemPrompt,
    double? temperature,
    int? maxTokens,
    AppThemeMode? themeMode,
    bool? useConnectAddress,
    String? connectAddress,
  }) {
    return AppSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModel: defaultModel ?? this.defaultModel,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      themeMode: themeMode ?? this.themeMode,
      useConnectAddress: useConnectAddress ?? this.useConnectAddress,
      connectAddress: connectAddress ?? this.connectAddress,
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
        other.themeMode == themeMode &&
        other.useConnectAddress == useConnectAddress &&
        other.connectAddress == connectAddress;
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
