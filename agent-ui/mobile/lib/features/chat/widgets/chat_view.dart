import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../data/models/chat_item.dart';
import '../../../domain/chat_blocks.dart';
import '../../../domain/chat_controller.dart';
import 'activity_group.dart';
import 'message_widgets.dart';

/// The open chat's messages. Follows new content to the bottom unless the
/// user has scrolled up, in which case a "Jump to latest" button appears.
class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key});

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _scroll = ScrollController();
  bool _following = true;

  /// Distance from the end that still counts as "at the bottom".
  static const _slack = 64.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom(animate: false));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _atBottom =>
      !_scroll.hasClients || _scroll.position.pixels >= _scroll.position.maxScrollExtent - _slack;

  void _toBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(end, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _scroll.jumpTo(end);
      }
    });
  }

  void _jumpToLatest() {
    setState(() => _following = true);
    _toBottom();
  }

  /// Only the user's own scrolling changes whether we follow the bottom, so
  /// content growing under us never switches it off.
  bool _onScroll(ScrollNotification notification) {
    final userScrolled = (notification is ScrollUpdateNotification && notification.dragDetails != null) ||
        (notification is UserScrollNotification && notification.direction != ScrollDirection.idle);
    if (userScrolled || (notification is ScrollEndNotification && !_following)) {
      final following = _atBottom;
      if (following != _following) setState(() => _following = following);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatControllerProvider, (previous, next) {
      if (previous?.conversationId != next.conversationId) {
        setState(() => _following = true);
        _toBottom(animate: false);
      } else if (_following &&
          (!identical(previous?.items, next.items) || previous?.status != next.status || previous?.busy != next.busy)) {
        _toBottom();
      }
    });

    final chat = ref.watch(chatControllerProvider);
    final agent = ref.watch(currentAgentProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final blocks = toBlocks(chat.items);
    final lastIsActivity = blocks.isNotEmpty && blocks.last is ActivityBlock;
    final showStatusLine = chat.busy && !lastIsActivity;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: ListView.builder(
            key: const Key('chat-list'),
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: blocks.length + (showStatusLine ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == blocks.length) return _StatusLine(status: chat.status);
              final block = blocks[index];
              final isLast = index == blocks.length - 1;
              return Padding(
                key: ValueKey(block.key),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _FadeIn(
                  child: switch (block) {
                    ActivityBlock(:final steps) => ActivityGroup(
                        steps: steps,
                        liveStatus: chat.busy && isLast ? chat.status : null,
                        onDecide: controller.decide,
                      ),
                    MessageBlock(:final item) => switch (item) {
                        UserItem(:final content) => UserBubble(content),
                        AssistantItem(:final content) => AssistantMessage(content, agent: agent),
                        ErrorItem(:final content) => ErrorMessage(content),
                      },
                  },
                ),
              );
            },
          ),
        ),
        if (!_following)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: ActionChip(
                key: const Key('jump-to-latest'),
                avatar: const Icon(Icons.arrow_downward_rounded, size: 18),
                label: const Text('Jump to latest'),
                onPressed: _jumpToLatest,
              ),
            ),
          ),
      ],
    );
  }
}

/// "Thinking..." under the last message while waiting for the first event.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Semantics(
        liveRegion: true,
        child: Row(
          children: [
            SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: palette.primary)),
            const SizedBox(width: 10),
            Expanded(child: Text(status, style: TextStyle(color: palette.muted))),
          ],
        ),
      ),
    );
  }
}

/// Fades a block in when it first appears.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
        child: child,
      );
}
