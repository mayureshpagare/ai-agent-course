import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/errors.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/agent.dart';
import '../../data/models/conversation.dart';
import '../../domain/agents_controller.dart';
import '../../domain/chat_controller.dart';
import '../../domain/conversations_controller.dart';
import '../shared/agent_avatar.dart';

/// Chat history: New chat, search, every chat across agents, and Settings.
class ConversationsDrawer extends ConsumerStatefulWidget {
  const ConversationsDrawer({super.key});

  @override
  ConsumerState<ConversationsDrawer> createState() => _ConversationsDrawerState();
}

class _ConversationsDrawerState extends ConsumerState<ConversationsDrawer> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _newChat() {
    ref.read(chatControllerProvider.notifier).newChat();
    _close();
  }

  void _open(Conversation conversation) {
    _close();
    ref.read(chatControllerProvider.notifier).openConversation(conversation.id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final busy = ref.watch(chatControllerProvider.select((chat) => chat.busy));
    final openId = ref.watch(chatControllerProvider.select((chat) => chat.conversationId));
    final conversations = ref.watch(conversationsProvider);
    final agents = ref.watch(agentsProvider).value ?? const <Agent>[];

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: FilledButton.icon(
                key: const Key('drawer-new-chat'),
                onPressed: busy ? null : _newChat,
                icon: const Icon(Icons.edit_square),
                label: const Text('New chat'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                key: const Key('drawer-search'),
                controller: _search,
                onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search chats',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  fillColor: palette.surface,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Semantics(
                header: true,
                child: Text('Chats', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: palette.muted)),
              ),
            ),
            Expanded(
              child: switch (conversations) {
                AsyncData(:final value) => _ChatList(
                    conversations: value.where((c) => c.title.toLowerCase().contains(_query)).toList(),
                    searching: _query.isNotEmpty,
                    agents: agents,
                    openId: openId,
                    busy: busy,
                    onOpen: _open,
                  ),
                AsyncError(:final error) => _ListError(
                    message: error is BackendException ? error.message : 'Could not load your chats.',
                    onRetry: () => ref.read(conversationsProvider.notifier).refresh(),
                  ),
                _ => const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading chats')),
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                _close();
                context.push(Routes.settings);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatList extends ConsumerWidget {
  const _ChatList({
    required this.conversations,
    required this.searching,
    required this.agents,
    required this.openId,
    required this.busy,
    required this.onOpen,
  });

  final List<Conversation> conversations;
  final bool searching;
  final List<Agent> agents;
  final String? openId;
  final bool busy;
  final void Function(Conversation conversation) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    if (conversations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(searching ? 'No chats match your search.' : 'No chats yet.',
            style: TextStyle(color: palette.muted)),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(conversationsProvider.notifier).refresh(),
      child: ListView.builder(
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          final agent = agents.where((a) => a.id == conversation.agentId).firstOrNull;
          final isOpen = conversation.id == openId;
          return Dismissible(
            key: ValueKey('chat-${conversation.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: palette.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Icon(Icons.delete_outline_rounded, color: palette.onError),
            ),
            confirmDismiss: (_) => confirmAndDelete(context, ref, conversation),
            child: Semantics(
              customSemanticsActions: {
                const CustomSemanticsAction(label: 'Rename'): () => renameConversation(context, ref, conversation),
                const CustomSemanticsAction(label: 'Delete'): () => confirmAndDelete(context, ref, conversation),
              },
              child: ListTile(
                key: Key('chat-row-${conversation.id}'),
                leading: AgentAvatar(
                  agent: agent,
                  size: 28,
                  fallback: conversation.agentId.isEmpty ? '?' : conversation.agentId[0].toUpperCase(),
                ),
                title: Text(conversation.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                selected: isOpen,
                selectedTileColor: palette.userBubble,
                selectedColor: palette.text,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                // The open chat can't change while a reply is streaming.
                enabled: !busy || isOpen,
                onTap: () => onOpen(conversation),
                onLongPress: () => _showActions(context, ref, conversation),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref, Conversation conversation) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(conversation.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  renameConversation(context, ref, conversation);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: context.palette.error),
                title: Text('Delete', style: TextStyle(color: context.palette.error)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  confirmAndDelete(context, ref, conversation);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
}

/// Asks for a new title and saves it. Blank titles are ignored.
Future<void> renameConversation(BuildContext context, WidgetRef ref, Conversation conversation) async {
  final title = await showDialog<String>(
    context: context,
    builder: (context) => _RenameDialog(initial: conversation.title),
  );
  if (title == null || title.trim().isEmpty || title.trim() == conversation.title) return;
  try {
    await ref.read(conversationsProvider.notifier).rename(conversation.id, title);
  } on BackendException catch (error) {
    if (context.mounted) _showError(context, error.message);
  }
}

/// Asks before deleting. Returns whether the chat was deleted.
Future<bool> confirmAndDelete(BuildContext context, WidgetRef ref, Conversation conversation) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete chat?'),
      content: Text('"${conversation.title}" will be deleted from the computer. This can\'t be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          key: const Key('confirm-delete'),
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: context.palette.error),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (!(confirmed ?? false)) return false;
  try {
    await ref.read(conversationsProvider.notifier).delete(conversation.id);
    return true;
  } on BackendException catch (error) {
    if (context.mounted) _showError(context, error.message);
    return false;
  }
}

void _showError(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          key: const Key('rename-field'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(key: const Key('rename-save'), onPressed: _save, child: const Text('Save')),
        ],
      );
}

class _ListError extends StatelessWidget {
  const _ListError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: TextStyle(color: context.palette.error)),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ],
        ),
      );
}
