import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../chat_controller.dart';

class RunStatus extends StatefulWidget {
  const RunStatus({
    super.key,
    required this.phase,
    this.startedAt,
    this.contextTrimmed = false,
  });

  final ChatRunPhase phase;
  final DateTime? startedAt;
  final bool contextTrimmed;

  @override
  State<RunStatus> createState() => _RunStatusState();
}

class _RunStatusState extends State<RunStatus> {
  Timer? _timer;

  bool get _active =>
      widget.phase == ChatRunPhase.connecting ||
      widget.phase == ChatRunPhase.waitingForModel ||
      widget.phase == ChatRunPhase.thinking ||
      widget.phase == ChatRunPhase.streaming;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant RunStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    if (_active && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    } else if (!_active) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _elapsedSeconds {
    final startedAt = widget.startedAt;
    if (startedAt == null) {
      return 0;
    }
    return DateTime.now().difference(startedAt).inSeconds;
  }

  String get _label => switch (widget.phase) {
    ChatRunPhase.connecting => 'Connecting…',
    ChatRunPhase.waitingForModel => 'Waiting for model…',
    ChatRunPhase.thinking => 'Thinking…',
    ChatRunPhase.streaming => 'Streaming…',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    if (!_active) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final seconds = _elapsedSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.contextTrimmed) ...[
          Row(
            children: [
              Icon(
                Icons.content_cut,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Earlier messages were trimmed to fit this model’s context.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (seconds > 0) ...[
              const SizedBox(width: 6),
              Text(
                '${seconds}s',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        if (widget.phase == ChatRunPhase.waitingForModel && seconds >= 5) ...[
          const SizedBox(height: 4),
          Text(
            'The first request after a model switch can take a while.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
