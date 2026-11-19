import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/conversation.dart';
import 'chat_controller.dart';
import 'conversations_controller.dart';

Future<void> renameConversationDialog(
  BuildContext context,
  Conversation conversation,
) async {
  final textController = TextEditingController(text: conversation.title);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Rename chat'),
      content: TextField(
        controller: textController,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Title'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(textController.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  textController.dispose();
  if (result == null || result.isEmpty || !context.mounted) {
    return;
  }
  await context.read<ConversationsController>().rename(conversation, result);
}

Future<void> deleteConversationDialog(
  BuildContext context,
  Conversation conversation,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete chat?'),
      content: Text(
        '“${conversation.title}” and its messages will be removed from this device.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  final chat = context.read<ChatController>();
  final conversations = context.read<ConversationsController>();
  await chat.conversationDeleted(conversation.id);
  await conversations.delete(conversation);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat deleted.'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}
