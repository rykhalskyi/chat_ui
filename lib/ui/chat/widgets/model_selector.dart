import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/context_budget.dart';
import '../chat_controller.dart';

class ModelSelector extends StatelessWidget {
  const ModelSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final label = controller.selectedModel.isEmpty
        ? 'Model'
        : controller.selectedModel;
    return ActionChip(
      avatar: const Icon(Icons.smart_toy_outlined, size: 18),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      onPressed: () => _openSheet(context),
    );
  }

  void _openSheet(BuildContext context) {
    final controller = context.read<ChatController>();
    if (controller.models.isEmpty && !controller.modelsLoading) {
      unawaited(controller.refreshModels());
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _ModelSheet(),
    );
  }
}

class _ModelSheet extends StatelessWidget {
  const _ModelSheet();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Model', style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  key: const Key('refreshModelsButton'),
                  tooltip: 'Refresh models',
                  onPressed: controller.modelsLoading
                      ? null
                      : controller.refreshModels,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (controller.modelsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            if (controller.modelsError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  controller.modelsError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (!controller.modelsLoading && controller.models.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No models loaded. Refresh to fetch /v1/models.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            if (controller.models.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: controller.models.length,
                  itemBuilder: (context, index) {
                    final model = controller.models[index];
                    final selected = model.id == controller.selectedModel;
                    return ListTile(
                      key: ValueKey('model-${model.id}'),
                      leading: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(model.id),
                      subtitle: Text(
                        '${ContextBudget.windowLabel(model.id)} context',
                      ),
                      onTap: () async {
                        await controller.setModel(model.id);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Local *-cpp models use a 4096-token window; older turns are trimmed.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
