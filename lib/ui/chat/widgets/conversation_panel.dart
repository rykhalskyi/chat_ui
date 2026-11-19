import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../core/time_format.dart';
import '../../../domain/entities/conversation.dart';
import '../chat_controller.dart';
import '../conversation_actions.dart';
import '../conversations_controller.dart';
import '../../settings/settings_screen.dart';

enum _ConversationAction { rename, delete }

class ConversationPanel extends StatelessWidget {
  const ConversationPanel({super.key, this.onNavigate});

  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final conversations = context.watch<ConversationsController>();
    final chat = context.watch<ChatController>();
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Text('Chats', style: theme.textTheme.titleLarge),
              const Spacer(),
              IconButton(
                key: const Key('newChatButton'),
                tooltip: 'New chat',
                onPressed: () => _newChat(context),
                icon: const Icon(Icons.add_comment_outlined),
              ),
            ],
          ),
        ),
        if (conversations.isLoading) const LinearProgressIndicator(),
        if (conversations.errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              conversations.errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        Expanded(
          child: conversations.conversations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No chats yet. Start a new one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: conversations.conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations.conversations[index];
                    return _ConversationTile(
                      conversation: conversation,
                      selected: chat.active?.id == conversation.id,
                      onNavigate: onNavigate,
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Settings'),
          onTap: () => _openSettings(context),
        ),
      ],
    );
  }

  Future<void> _newChat(BuildContext context) async {
    final chat = context.read<ChatController>();
    final messenger = ScaffoldMessenger.of(context);
    await chat.newChat();
    if (!context.mounted) {
      return;
    }
    if (chat.errorMessage != null) {
      messenger.showSnackBar(SnackBar(content: Text(chat.errorMessage!)));
      return;
    }
    onNavigate?.call();
  }

  void _openSettings(BuildContext context) {
    final navigator = Navigator.of(context);
    onNavigate?.call();
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onNavigate,
  });

  final Conversation conversation;
  final bool selected;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('conversation-${conversation.id}'),
      selected: selected,
      selectedTileColor: theme.colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: const Icon(Icons.chat_bubble_outline),
      title: Text(
        conversation.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${formatRelativeTime(conversation.updatedAt)} · ${conversation.modelId}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<_ConversationAction>(
        tooltip: 'Chat actions',
        onSelected: (action) async {
          switch (action) {
            case _ConversationAction.rename:
              await renameConversationDialog(context, conversation);
            case _ConversationAction.delete:
              await deleteConversationDialog(context, conversation);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _ConversationAction.rename,
            child: Text('Rename'),
          ),
          PopupMenuItem(
            value: _ConversationAction.delete,
            child: Text('Delete'),
          ),
        ],
      ),
      onTap: () => _open(context),
    );
  }

  Future<void> _open(BuildContext context) async {
    final chat = context.read<ChatController>();
    final messenger = ScaffoldMessenger.of(context);
    final opened = await chat.open(conversation);
    if (!context.mounted) {
      return;
    }
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(chat.errorMessage ?? 'Could not open the chat.'),
        ),
      );
      return;
    }
    onNavigate?.call();
  }
}
