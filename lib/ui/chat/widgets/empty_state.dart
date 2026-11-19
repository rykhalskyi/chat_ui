import 'package:material_ui/material_ui.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.onPrompt});

  final ValueChanged<String> onPrompt;

  static const prompts = [
    'What does LiteLLM do?',
    'Build a Flutter chat bubble',
    'SQLite vs. a server database',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text('How can I help?', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Pick a model and send a message. History stays on this device.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final prompt in prompts)
                    ActionChip(
                      label: Text(
                        prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => onPrompt(prompt),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
