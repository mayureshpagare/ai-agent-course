import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/chat_item.dart';
import '../../domain/chat_controller.dart';
import '../../domain/conversations_controller.dart';
import '../conversations/conversations_drawer.dart';
import '../shared/agent_avatar.dart';
import 'widgets/agent_picker.dart';

/// The main screen: top bar, chat history drawer and the open chat.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(chatControllerProvider.select((chat) => chat.busy));
    // Load the chat list now, not when the drawer first opens, so it is ready
    // and a connection problem shows up straight away.
    ref.listen(conversationsProvider, (_, _) {});
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Open chats',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const AgentTitleButton(),
        actions: [
          IconButton(
            key: const Key('top-new-chat'),
            tooltip: 'New chat',
            icon: const Icon(Icons.edit_square),
            onPressed: busy ? null : () => ref.read(chatControllerProvider.notifier).newChat(),
          ),
        ],
      ),
      drawer: const ConversationsDrawer(),
      body: const _ChatBody(),
    );
  }
}

/// Temporary body until the message list and composer land (milestone 4).
class _ChatBody extends ConsumerWidget {
  const _ChatBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatControllerProvider);
    final agent = ref.watch(currentAgentProvider);
    if (chat.loading) return const Center(child: CircularProgressIndicator());
    if (chat.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AgentAvatar(agent: agent, size: 56),
            const SizedBox(height: 16),
            Text(agent?.name ?? 'Pick an agent', style: Theme.of(context).textTheme.displaySmall),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final item in chat.items)
          Text(switch (item) {
            MessageItem(:final kind, :final content) => '$kind: $content',
            ThinkingItem(:final content) => 'thinking: $content',
            ToolItem(:final name) => 'tool: $name',
          }, style: TextStyle(color: context.palette.text)),
      ],
    );
  }
}
