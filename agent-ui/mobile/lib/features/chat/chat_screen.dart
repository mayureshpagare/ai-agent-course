import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/theme/tokens.dart';
import '../../domain/agents_controller.dart';
import '../../domain/chat_controller.dart';
import '../../domain/conversations_controller.dart';
import '../conversations/conversations_drawer.dart';
import '../shared/agent_avatar.dart';
import 'widgets/agent_picker.dart';
import 'widgets/chat_view.dart';
import 'widgets/composer.dart';

/// The main screen: top bar, chat history drawer and the open chat.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // A turn whose connection drops in the background is ended by the server;
    // the controller reloads the chat when the app comes back.
    _lifecycle = AppLifecycleListener(onStateChange: (state) {
      final controller = ref.read(chatControllerProvider.notifier);
      switch (state) {
        case AppLifecycleState.resumed:
          controller.setForeground(true);
        case AppLifecycleState.paused || AppLifecycleState.hidden || AppLifecycleState.detached:
          controller.setForeground(false);
        case AppLifecycleState.inactive:
          break; // brief interruptions such as the notification shade
      }
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final agent = ref.watch(currentAgentProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    // Load the chat list now, not when the drawer first opens, so it is ready
    // and a connection problem shows up straight away.
    ref.listen(conversationsProvider, (_, _) {});

    final composer = Composer(
      key: ValueKey(chat.isNewChat ? 'composer-new' : 'composer-chat'),
      agentName: agent?.name ?? 'agent',
      enabled: agent != null || chat.conversationId != null,
      busy: chat.busy,
      large: chat.isNewChat,
      onSend: controller.send,
      onStop: controller.stop,
    );

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
            onPressed: chat.busy ? null : controller.newChat,
          ),
        ],
      ),
      drawer: const ConversationsDrawer(),
      body: Column(
        children: [
          const _ConnectionBanner(),
          if (chat.notice case final String notice)
            _Banner(
              key: const Key('notice-banner'),
              icon: Icons.info_outline_rounded,
              text: notice,
              color: context.palette.warning,
              background: context.palette.warningBackground,
              action: TextButton(onPressed: controller.dismissNotice, child: const Text('Dismiss')),
            ),
          Expanded(
            child: switch (chat) {
              ChatState(loading: true) =>
                const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading chat')),
              ChatState(isNewChat: true) => const _NewChatGreeting(),
              _ => const ChatView(),
            },
          ),
          composer,
        ],
      ),
    );
  }
}

/// New chat: the agent's logo, name and description, centered.
class _NewChatGreeting extends ConsumerWidget {
  const _NewChatGreeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = ref.watch(currentAgentProvider);
    final palette = context.palette;
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AgentAvatar(agent: agent, size: 64),
              const SizedBox(height: 20),
              Text(
                agent?.name ?? 'Pick an agent',
                key: const Key('greeting-name'),
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall,
              ),
              if (agent != null && agent.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  agent.description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: palette.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the server can't be reached, with Retry.
class _ConnectionBanner extends ConsumerWidget {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsError = ref.watch(agentsProvider).error;
    final listError = ref.watch(conversationsProvider).error;
    final loadError = ref.watch(chatControllerProvider.select((chat) => chat.loadError));
    final error = agentsError ?? listError;
    final message = loadError ??
        switch (error) {
          null => null,
          BackendException(:final message) => message,
          _ => 'Could not reach the computer.',
        };
    if (message == null) return const SizedBox.shrink();

    return _Banner(
      key: const Key('connection-banner'),
      icon: Icons.wifi_off_rounded,
      text: message,
      color: context.palette.error,
      background: context.palette.error.withValues(alpha: 0.08),
      action: TextButton(
        onPressed: () {
          if (agentsError != null) ref.invalidate(agentsProvider);
          if (listError != null) ref.read(conversationsProvider.notifier).refresh();
          ref.read(chatControllerProvider.notifier).retryLoad();
        },
        child: const Text('Retry'),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
    required this.action,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color background;
  final Widget action;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: TextStyle(color: color))),
              action,
            ],
          ),
        ),
      );
}
