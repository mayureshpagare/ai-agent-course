import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/conversation.dart';
import 'chat_controller.dart';
import 'session_controller.dart';

/// Every saved chat, across all agents, newest first.
final conversationsProvider =
    AsyncNotifierProvider<ConversationsController, List<Conversation>>(ConversationsController.new);

class ConversationsController extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() => ref.watch(backendProvider).conversations();

  /// Reloads the list. Failures are kept in the state for the error banner.
  Future<void> refresh() async {
    final backend = ref.read(backendProvider);
    final result = await AsyncValue.guard(backend.conversations);
    if (ref.mounted) state = result;
  }

  /// Adds a chat that was just created, before the next refresh lists it.
  void insert(Conversation conversation) =>
      _update((list) => [conversation, ...list.where((c) => c.id != conversation.id)]);

  void setTitle(String id, String title) =>
      _update((list) => [for (final c in list) c.id == id ? c.copyWith(title: title) : c]);

  Future<void> rename(String id, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    await ref.read(backendProvider).rename(id, trimmed);
    setTitle(id, trimmed);
  }

  Future<void> delete(String id) async {
    await ref.read(backendProvider).delete(id);
    _update((list) => list.where((c) => c.id != id).toList());
    ref.read(chatControllerProvider.notifier).conversationDeleted(id);
  }

  void _update(List<Conversation> Function(List<Conversation> list) change) {
    final list = state.value;
    if (list != null) state = AsyncData(change(list));
  }
}
