import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'chat_controller.dart';
import 'widgets/composer.dart';
import 'widgets/conversation_panel.dart';
import 'widgets/empty_state.dart';
import 'widgets/message_bubble.dart';
import 'widgets/model_selector.dart';
import '../settings/settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  ChatController? _chat;
  bool _pinned = true;
  bool _showJump = false;
  String? _activeId;

  @override
  void initState() {
    super.initState();
    _chat = context.read<ChatController>();
    _chat!.addListener(_onChatChanged);
    _scrollController.addListener(_onScroll);
    _activeId = _chat!.active?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _chat?.removeListener(_onChatChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onChatChanged() {
    if (!mounted) {
      return;
    }
    final chat = _chat!;
    final id = chat.active?.id;
    if (id != _activeId) {
      _activeId = id;
      _pinned = true;
      if (_showJump) {
        setState(() => _showJump = false);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      return;
    }
    if (_pinned) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else if (!_showJump && chat.messages.isNotEmpty) {
      setState(() => _showJump = true);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final pinned = position.pixels >= position.maxScrollExtent - 48;
    if (pinned != _pinned) {
      setState(() {
        _pinned = pinned;
        _showJump = !pinned && (_chat?.messages.isNotEmpty ?? false);
      });
    }
  }

  void _scrollToBottom({bool animate = false}) {
    if (!_scrollController.hasClients) {
      return;
    }
    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } else if ((target - _scrollController.position.pixels).abs() > 4) {
      _scrollController.jumpTo(target);
    }
  }

  void _jumpToLatest() {
    _pinned = true;
    setState(() => _showJump = false);
    _scrollToBottom(animate: true);
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final active = chat.active;
    final body = Column(
      children: [
        if (chat.errorMessage != null)
          _ErrorBanner(message: chat.errorMessage!, onDismiss: chat.clearError),
        Expanded(
          child: chat.isLoading
              ? const Center(child: CircularProgressIndicator())
              : chat.messages.isEmpty
              ? EmptyState(onPrompt: (prompt) => unawaited(chat.send(prompt)))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: chat.messages.length,
                  itemBuilder: (context, index) {
                    final message = chat.messages[index];
                    final isLast = index == chat.messages.length - 1;
                    return MessageBubble(
                      message: message,
                      isActive: chat.assistantId == message.id,
                      phase: chat.phase,
                      startedAt: chat.runStartedAt,
                      contextTrimmed: chat.contextTrimmed,
                      canRetry: isLast && chat.canRetry,
                      onRetry: () => unawaited(chat.retryLast()),
                    );
                  },
                ),
        ),
        if (_showJump)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextButton.icon(
              key: const Key('jumpToLatestButton'),
              onPressed: _jumpToLatest,
              icon: const Icon(Icons.keyboard_arrow_down),
              label: const Text('Jump to latest'),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: Row(children: const [ModelSelector()]),
        ),
        Composer(
          isRunning: chat.isRunning,
          onSend: (text) => unawaited(chat.send(text)),
          onStop: () => unawaited(chat.cancel()),
          draftKey: chat.draftKey,
          draft: chat.draft,
          onDraftChanged: chat.setDraft,
          hintText: active == null
              ? 'Start a new chat…'
              : 'Message ${chat.selectedModel}…',
        ),
      ],
    );

    return Scaffold(
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: ConversationPanel(
                  onNavigate: () => Navigator.of(context).pop(),
                ),
              ),
            ),
      appBar: AppBar(
        leading: wide
            ? null
            : Builder(
                builder: (appBarContext) => IconButton(
                  key: const Key('openDrawerButton'),
                  tooltip: 'Chats',
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(appBarContext).openDrawer(),
                ),
              ),
        title: Text(
          active?.title ?? 'Chat UI',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (chat.canRegenerate)
            IconButton(
              key: const Key('regenerateButton'),
              tooltip: 'Regenerate',
              onPressed: () => unawaited(chat.regenerateLast()),
              icon: const Icon(Icons.refresh),
            ),
          if (chat.canRetry)
            IconButton(
              key: const Key('retryButton'),
              tooltip: 'Retry',
              onPressed: () => unawaited(chat.retryLast()),
              icon: const Icon(Icons.replay),
            ),
          IconButton(
            key: const Key('openSettingsButton'),
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                const SizedBox(
                  width: 300,
                  child: SafeArea(child: ConversationPanel()),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
