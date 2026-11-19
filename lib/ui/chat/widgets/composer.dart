import 'package:material_ui/material_ui.dart';

class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.isRunning,
    required this.onSend,
    required this.onStop,
    this.hintText = 'Message…',
  });

  final bool isRunning;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final String hintText;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isRunning) {
      return;
    }
    _controller.clear();
    setState(() => _hasText = false);
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('composerField'),
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onChanged: (value) {
                    final hasText = value.trim().isNotEmpty;
                    if (hasText != _hasText) {
                      setState(() => _hasText = hasText);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.isRunning)
                IconButton.filled(
                  key: const Key('stopButton'),
                  tooltip: 'Stop',
                  onPressed: widget.onStop,
                  icon: const Icon(Icons.stop),
                )
              else
                IconButton.filled(
                  key: const Key('sendButton'),
                  tooltip: 'Send',
                  onPressed: _hasText ? _send : null,
                  icon: const Icon(Icons.arrow_upward),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
