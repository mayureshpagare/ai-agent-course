import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/tokens.dart';
import '../../../data/models/agent.dart';
import '../../shared/agent_avatar.dart';
import 'markdown_view.dart';

/// The user's message: a rounded bubble on the right.
class UserBubble extends StatelessWidget {
  const UserBubble(this.content, {super.key});

  final String content;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.85,
        alignment: Alignment.centerRight,
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onLongPress: () => showMessageActions(context, content),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: palette.userBubble, borderRadius: BorderRadius.circular(20)),
              child: Text(content, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: palette.text)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The agent's reply: full width, no bubble, a small avatar above it.
class AssistantMessage extends StatelessWidget {
  const AssistantMessage(this.content, {super.key, required this.agent});

  final String content;
  final Agent? agent;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onLongPress: () => showMessageActions(context, content),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AgentAvatar(agent: agent, size: 24, fallback: 'A'),
            const SizedBox(height: 8),
            MarkdownView(content),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Copy reply',
                icon: Icon(Icons.copy_rounded, size: 18, color: context.palette.muted),
                onPressed: () => copyText(context, content),
              ),
            ),
          ],
        ),
      );
}

/// An error from the agent or the connection, shown inline.
class ErrorMessage extends StatelessWidget {
  const ErrorMessage(this.content, {super.key});

  final String content;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: palette.error, size: 20, semanticLabel: 'Error'),
          const SizedBox(width: 8),
          Expanded(child: Text(content, style: TextStyle(color: palette.error))),
        ],
      ),
    );
  }
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 2)));
}

/// Long-press menu for a message: copy it whole, or open it to select part.
Future<void> showMessageActions(BuildContext context, String text) {
  HapticFeedback.selectionClick().ignore();
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text('Copy'),
            onTap: () {
              Navigator.pop(sheetContext);
              copyText(context, text);
            },
          ),
          ListTile(
            leading: const Icon(Icons.text_fields_rounded),
            title: const Text('Select text'),
            onTap: () {
              Navigator.pop(sheetContext);
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _SelectTextPage(text)));
            },
          ),
        ],
      ),
    ),
  );
}

class _SelectTextPage extends StatelessWidget {
  const _SelectTextPage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Select text')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
}
