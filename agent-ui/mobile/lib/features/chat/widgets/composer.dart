import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/theme/tokens.dart';

/// The message box: a pill that grows to about six lines, with a round send
/// button that becomes a square stop button while a reply streams in. Enter
/// adds a new line; only the button sends.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.agentName,
    required this.enabled,
    required this.busy,
    required this.onSend,
    required this.onStop,
    this.large = false,
  });

  final String agentName;

  /// False when there is no agent to talk to.
  final bool enabled;
  final bool busy;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;

  /// New chat: a taller box.
  final bool large;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend => widget.enabled && !widget.busy && _controller.text.trim().isNotEmpty;

  void _send() {
    if (!_canSend) return;
    widget.onSend(_controller.text.trim());
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              decoration: BoxDecoration(
                color: palette.inputFill,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('composer-field'),
                      controller: _controller,
                      enabled: widget.enabled,
                      minLines: widget.large ? 3 : 1,
                      maxLines: 6,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: palette.text),
                      decoration: InputDecoration(
                        hintText:
                            widget.large ? 'Ask ${widget.agentName} anything...' : 'Message ${widget.agentName}',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  widget.busy
                      ? _RoundButton(
                          key: const Key('composer-stop'),
                          tooltip: 'Stop',
                          icon: Icons.stop_rounded,
                          square: true,
                          onPressed: widget.onStop,
                        )
                      : _RoundButton(
                          key: const Key('composer-send'),
                          tooltip: 'Send message',
                          icon: Icons.arrow_upward_rounded,
                          onPressed: _canSend ? _send : null,
                        ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              composerHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.square = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      style: IconButton.styleFrom(
        backgroundColor: enabled ? palette.primary : palette.border,
        foregroundColor: enabled ? palette.onPrimary : palette.muted,
        disabledBackgroundColor: palette.border,
        disabledForegroundColor: palette.muted,
        shape: square
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            : const CircleBorder(),
      ),
      icon: Icon(icon),
    );
  }
}
