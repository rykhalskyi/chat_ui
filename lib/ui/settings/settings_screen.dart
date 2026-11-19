import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/app_info.dart';
import '../../domain/entities/app_settings.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.versionFuture});

  final Future<AppVersion>? versionFuture;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _defaultModel;
  late final TextEditingController _systemPrompt;
  late final TextEditingController _temperature;
  late final TextEditingController _maxTokens;
  late final TextEditingController _connectAddress;
  bool _obscureApiKey = true;
  bool _useConnectAddress = false;
  late final Future<AppVersion> _versionFuture;

  @override
  void initState() {
    super.initState();
    _versionFuture = widget.versionFuture ?? AppInfo.current();
    final controller = context.read<SettingsController>();
    _baseUrl = TextEditingController(text: controller.settings.baseUrl);
    _apiKey = TextEditingController(text: controller.apiKey);
    _defaultModel = TextEditingController(
      text: controller.settings.defaultModel,
    );
    _systemPrompt = TextEditingController(
      text: controller.settings.systemPrompt,
    );
    _temperature = TextEditingController(
      text: controller.settings.temperature.toString(),
    );
    _maxTokens = TextEditingController(
      text: controller.settings.maxTokens.toString(),
    );
    _connectAddress = TextEditingController(
      text: controller.settings.connectAddress,
    );
    _useConnectAddress = controller.settings.useConnectAddress;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _defaultModel.dispose();
    _systemPrompt.dispose();
    _temperature.dispose();
    _maxTokens.dispose();
    _connectAddress.dispose();
    super.dispose();
  }

  String? _validateBaseUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Enter the API base URL.';
    }
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Use an http(s) URL, e.g. https://llm.lan.otakeessen.com/v1';
    }
    return null;
  }

  String? _validateModel(String? value) {
    if ((value?.trim() ?? '').isEmpty) {
      return 'Enter a default model id.';
    }
    return null;
  }

  String? _validateTemperature(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0 || parsed > 2) {
      return '0 – 2';
    }
    return null;
  }

  String? _validateMaxTokens(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 16 || parsed > 32768) {
      return '16 – 32768';
    }
    return null;
  }

  String? _validateConnectAddress(String? value) {
    if (!_useConnectAddress) {
      return null;
    }
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Enter the LAN host or IP.';
    }
    if (text.contains('://') || text.contains('/') || text.contains(' ')) {
      return 'Use a host or IP only.';
    }
    return null;
  }

  Future<void> _testConnection() async {
    FocusScope.of(context).unfocus();
    final controller = context.read<SettingsController>();
    final baseUrl = _baseUrl.text.trim();
    if (_validateBaseUrl(baseUrl) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid base URL first.')),
      );
      return;
    }
    if (_validateConnectAddress(_connectAddress.text) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid connect address first.')),
      );
      return;
    }
    await controller.testConnection(
      baseUrl: baseUrl,
      apiKey: _apiKey.text.trim(),
      connectAddress: _useConnectAddress ? _connectAddress.text.trim() : null,
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final controller = context.read<SettingsController>();
    final settings = AppSettings(
      baseUrl: _baseUrl.text.trim(),
      defaultModel: _defaultModel.text.trim(),
      systemPrompt: _systemPrompt.text.trim(),
      temperature: double.parse(_temperature.text.trim()),
      maxTokens: int.parse(_maxTokens.text.trim()),
      themeMode: controller.settings.themeMode,
      useConnectAddress: _useConnectAddress,
      connectAddress: _connectAddress.text.trim(),
    );
    final saved = await controller.save(
      settings: settings,
      apiKey: _apiKey.text.trim(),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? 'Settings saved.' : controller.errorMessage ?? 'Save failed.',
        ),
      ),
    );
  }

  void _resetDefaults() {
    setState(() {
      const defaults = AppSettings.defaults;
      _baseUrl.text = defaults.baseUrl;
      _defaultModel.text = defaults.defaultModel;
      _systemPrompt.text = defaults.systemPrompt;
      _temperature.text = defaults.temperature.toString();
      _maxTokens.text = defaults.maxTokens.toString();
      _connectAddress.text = defaults.connectAddress;
      _useConnectAddress = defaults.useConnectAddress;
    });
    context.read<SettingsController>().clearConnectionResult();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (controller.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              controller.errorMessage!,
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'LiteLLM connection',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('baseUrlField'),
                    controller: _baseUrl,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://llm.lan.otakeessen.com/v1',
                      helperText:
                          'OpenAI-compatible base URL. /v1/models is appended.',
                    ),
                    validator: _validateBaseUrl,
                    onChanged: (_) => controller.clearConnectionResult(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('apiKeyField'),
                    controller: _apiKey,
                    obscureText: _obscureApiKey,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'API key',
                      helperText: 'Stored in secure storage on this device.',
                      suffixIcon: IconButton(
                        key: const Key('apiKeyVisibilityButton'),
                        tooltip: _obscureApiKey ? 'Show key' : 'Hide key',
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureApiKey = !_obscureApiKey),
                      ),
                    ),
                    onChanged: (_) => controller.clearConnectionResult(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        key: const Key('testConnectionButton'),
                        onPressed: controller.isTesting
                            ? null
                            : _testConnection,
                        icon: const Icon(Icons.wifi_tethering),
                        label: const Text('Test connection'),
                      ),
                      const SizedBox(width: 12),
                      if (controller.isTesting)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ConnectionStatus(result: controller.connectionResult),
                  const SizedBox(height: 24),
                  Text('LAN access', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    key: const Key('useConnectAddressSwitch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use LAN IP override'),
                    subtitle: const Text(
                      'Bypass DNS for this endpoint; TLS still validates the hostname.',
                    ),
                    value: _useConnectAddress,
                    onChanged: (value) {
                      setState(() => _useConnectAddress = value);
                      controller.clearConnectionResult();
                    },
                  ),
                  if (_useConnectAddress) ...[
                    const SizedBox(height: 4),
                    TextFormField(
                      key: const Key('connectAddressField'),
                      controller: _connectAddress,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Connect address',
                        hintText: '192.168.2.240',
                        helperText: 'Host or IP only. The base URL host is kept for TLS.',
                      ),
                      validator: _validateConnectAddress,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('Defaults', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('defaultModelField'),
                    controller: _defaultModel,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Default model',
                      hintText: 'llama3.2-3b-cpp',
                      helperText: 'Fetched model ids come from /v1/models.',
                    ),
                    validator: _validateModel,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('systemPromptField'),
                    controller: _systemPrompt,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'System prompt (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Generation', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('temperatureField'),
                          controller: _temperature,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Temperature',
                          ),
                          validator: _validateTemperature,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: const Key('maxTokensField'),
                          controller: _maxTokens,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max tokens',
                          ),
                          validator: _validateMaxTokens,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Appearance', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SegmentedButton<AppThemeMode>(
                    key: const Key('themeModeControl'),
                    segments: const [
                      ButtonSegment(
                        value: AppThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {controller.settings.themeMode},
                    onSelectionChanged: (selection) {
                      controller.setThemeMode(selection.first);
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      TextButton(
                        key: const Key('resetDefaultsButton'),
                        onPressed: _resetDefaults,
                        child: const Text('Reset to defaults'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        key: const Key('saveSettingsButton'),
                        onPressed: controller.isSaving ? null : _save,
                        icon: controller.isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('About', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FutureBuilder<AppVersion>(
                    future: _versionFuture,
                    builder: (context, snapshot) {
                      final version = snapshot.data;
                      return ListTile(
                        key: const Key('appVersionTile'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.info_outline),
                        title: const Text('Chat UI'),
                        subtitle: Text(
                          version != null
                              ? 'Version ${version.display}'
                              : snapshot.hasError
                              ? 'Version unavailable'
                              : 'Version …',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.result});

  final ConnectionTestResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = this.result;
    if (result == null) {
      return const SizedBox.shrink();
    }
    if (result is ConnectionTestFailure) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.message,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      );
    }
    final success = result as ConnectionTestSuccess;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Connected — ${success.models.length} models',
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          if (success.models.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final model in success.models) Chip(label: Text(model.id)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
