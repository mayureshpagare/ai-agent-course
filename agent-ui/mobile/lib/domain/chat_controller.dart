import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/device_services.dart';
import '../core/errors.dart';
import '../data/models/agent.dart';
import '../data/models/chat_item.dart';
import '../data/models/stream_event.dart';
import 'agents_controller.dart';
import 'conversations_controller.dart';
import 'session_controller.dart';

const _keep = Object();

const interruptedNotice = 'The reply was interrupted because the app went to the background. '
    'This chat was reloaded from the computer; send your message again to retry.';

/// The open chat, as `App.tsx` keeps it: its items, whether a turn is
/// running, and the live status line.
class ChatState {
  const ChatState({
    this.conversationId,
    this.items = const [],
    this.busy = false,
    this.status = '',
    this.loading = false,
    this.loadError,
    this.notice,
  });

  /// Null for a new chat that has not been sent yet.
  final String? conversationId;
  final List<ChatItem> items;

  /// A turn is running.
  final bool busy;

  /// Live status, e.g. "Running add...".
  final String status;

  /// Loading a saved chat.
  final bool loading;

  /// Loading a saved chat failed with this message.
  final String? loadError;

  /// An informational banner, e.g. that a turn was interrupted.
  final String? notice;

  /// The agent can only be chosen for a new, idle chat.
  bool get agentLocked => conversationId != null || busy;

  bool get isNewChat => items.isEmpty && !busy && !loading && conversationId == null;

  bool get awaitingApproval => items.any((item) => item is ToolItem && item.status == ToolStatus.approval);

  ChatState copyWith({
    Object? conversationId = _keep,
    List<ChatItem>? items,
    bool? busy,
    String? status,
    bool? loading,
    Object? loadError = _keep,
    Object? notice = _keep,
  }) =>
      ChatState(
        conversationId: identical(conversationId, _keep) ? this.conversationId : conversationId as String?,
        items: items ?? this.items,
        busy: busy ?? this.busy,
        status: status ?? this.status,
        loading: loading ?? this.loading,
        loadError: identical(loadError, _keep) ? this.loadError : loadError as String?,
        notice: identical(notice, _keep) ? this.notice : notice as String?,
      );
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);

/// The agent shown in the top bar and used for the next new chat.
///
/// For an open chat this is the chat's own agent, or null if that agent no
/// longer exists. For a new chat it is the selected agent, falling back to the
/// first one when the saved choice is gone.
final currentAgentProvider = Provider<Agent?>((ref) {
  final agents = ref.watch(agentsProvider).value ?? const <Agent>[];
  final selected = ref.watch(selectedAgentProvider);
  final hasConversation = ref.watch(chatControllerProvider.select((chat) => chat.conversationId != null));
  for (final agent in agents) {
    if (agent.id == selected) return agent;
  }
  return hasConversation || agents.isEmpty ? null : agents.first;
});

/// Runs chat turns: the Flutter version of the state machine in `App.tsx`.
class ChatController extends Notifier<ChatState> {
  StreamSubscription<StreamEvent>? _subscription;
  Completer<void>? _turnDone;
  bool _stopping = false;
  bool _foreground = true;
  bool _backgroundedDuringTurn = false;
  String? _pendingRecovery;

  @override
  ChatState build() {
    ref.watch(backendProvider); // a new sign-in starts from a fresh chat
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
      if (stateOrNull?.busy ?? false) ref.read(deviceServicesProvider).setKeepAwake(false);
    });
    return const ChatState();
  }

  void _set(ChatState Function(ChatState current) change) {
    if (ref.mounted) state = change(state);
  }

  void _append(ChatItem item) => _set((s) => s.copyWith(items: [...s.items, item]));

  void _updateTool(String callId, ToolItem Function(ToolItem tool) change) => _set((s) => s.copyWith(items: [
        for (final item in s.items) item is ToolItem && item.id == callId ? change(item) : item,
      ]));

  /// Starts a new, empty chat with the current agent.
  void newChat() {
    if (state.busy) return;
    _pendingRecovery = null;
    state = const ChatState();
  }

  /// Loads a saved chat and switches to its agent.
  Future<void> openConversation(String id) async {
    if (state.busy) return;
    _pendingRecovery = null;
    final known = ref.read(conversationsProvider).value?.where((c) => c.id == id).firstOrNull;
    if (known != null) ref.read(selectedAgentProvider.notifier).follow(known.agentId);
    state = ChatState(conversationId: id, loading: true);
    try {
      final detail = await ref.read(backendProvider).conversation(id);
      if (!ref.mounted || state.conversationId != id) return;
      ref.read(selectedAgentProvider.notifier).follow(detail.conversation.agentId);
      state = ChatState(conversationId: id, items: detail.items);
    } on BackendException catch (error) {
      if (!ref.mounted || state.conversationId != id) return;
      state = ChatState(conversationId: id, loadError: error.message);
    }
  }

  /// Retries loading the open chat after a failure.
  Future<void> retryLoad() async {
    final id = state.conversationId;
    if (id != null && state.loadError != null) await openConversation(id);
  }

  void dismissNotice() => _set((s) => s.copyWith(notice: null));

  /// A chat was deleted from the drawer: leave it if it is open.
  void conversationDeleted(String id) {
    if (state.conversationId == id) newChat();
  }

  /// Sends [text], creating the conversation first for a new chat, and
  /// applies the streamed events until the turn ends.
  Future<void> send(String text) async {
    final content = text.trim();
    final agent = ref.read(currentAgentProvider);
    if (content.isEmpty || state.busy || agent == null) return;

    final backend = ref.read(backendProvider);
    final devices = ref.read(deviceServicesProvider);
    _stopping = false;
    _backgroundedDuringTurn = !_foreground;
    _pendingRecovery = null;
    state = state.copyWith(busy: true, status: thinkingStatus, notice: null);
    devices.setKeepAwake(true);

    var id = state.conversationId;
    Object? failure;
    try {
      if (id == null) {
        final created = await backend.createConversation(agent.id);
        id = created.id;
        _set((s) => s.copyWith(conversationId: created.id));
        if (ref.mounted) ref.read(conversationsProvider.notifier).insert(created);
      }
      if (_stopping) throw const _Stopped();
      _append(UserItem(content));
      await _consume(backend.sendMessage(id, content));
    } on Object catch (error) {
      failure = error;
    } finally {
      devices.setKeepAwake(false);
      _subscription = null;
      _turnDone = null;
    }
    if (!ref.mounted) return;

    final interrupted = failure is UnreachableException && _backgroundedDuringTurn;
    state = state.copyWith(
      busy: false,
      status: '',
      items: [
        // Any tool still spinning was interrupted.
        for (final item in state.items)
          item is ToolItem && item.status != ToolStatus.done ? item.copyWith(status: ToolStatus.done) : item,
        if (failure != null && !interrupted) ErrorItem(_describe(failure)),
      ],
    );
    unawaited(ref.read(conversationsProvider.notifier).refresh());

    if (interrupted && id != null) {
      // The server ends a turn whose connection drops, so what it saved is
      // the truth: show that instead of a half-finished reply.
      _pendingRecovery = id;
      if (_foreground) await _recover();
    }
  }

  Future<void> _consume(Stream<StreamEvent> events) {
    final done = _turnDone = Completer<void>();
    _subscription = events.listen(
      _handle,
      onError: (Object error, StackTrace stackTrace) {
        if (!done.isCompleted) done.completeError(error, stackTrace);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    return done.future;
  }

  void _handle(StreamEvent event) {
    // After Stop the server sends its own "Stopped." error; one is enough.
    if (_stopping) return;
    switch (event) {
      case StatusEvent(:final message):
        _set((s) => s.copyWith(status: message));
      case TitleEvent(:final title):
        final id = state.conversationId;
        if (id != null) ref.read(conversationsProvider.notifier).setTitle(id, title);
      case ThinkingEvent(:final content):
        _append(ThinkingItem(content));
      case ToolCallEvent(:final callId, :final name, :final args):
        _set((s) => s.copyWith(
              status: 'Running $name...',
              items: [...s.items, ToolItem(id: callId, name: name, args: args)],
            ));
      case ApprovalRequiredEvent(:final callId, :final warning):
        _set((s) => s.copyWith(status: 'Waiting for your approval...'));
        _updateTool(callId, (tool) => tool.copyWith(status: ToolStatus.approval, warning: warning));
        ref.read(deviceServicesProvider).approvalNeeded();
      case ToolResultEvent(:final callId, :final content):
        _set((s) => s.copyWith(status: thinkingStatus));
        _updateTool(callId, (tool) => tool.copyWith(status: ToolStatus.done, result: content));
      case FinalEvent(:final content):
        _append(AssistantItem(content));
      case ErrorEvent(:final message):
        _append(ErrorItem(message));
    }
  }

  /// Stops the running turn: tells the server, then drops the stream.
  Future<void> stop() async {
    if (!state.busy || _stopping) return;
    _stopping = true;
    final id = state.conversationId;
    if (id != null) {
      try {
        await ref.read(backendProvider).stop(id);
      } on BackendException {
        // Dropping the connection below stops the turn anyway.
      }
    }
    await _subscription?.cancel();
    final done = _turnDone;
    if (done != null && !done.isCompleted) done.completeError(const _Stopped());
  }

  /// Approves or denies the tool call [callId].
  Future<void> decide(String callId, {required bool approved}) async {
    final id = state.conversationId;
    if (id == null) return;
    _updateTool(callId, (tool) => tool.copyWith(status: ToolStatus.running));
    _set((s) => s.copyWith(status: approved ? 'Running approved action...' : 'Cancelling...'));
    try {
      await ref.read(backendProvider).approve(id, callId, approved: approved);
    } on BackendException catch (error) {
      _append(ErrorItem(error.message));
    }
  }

  /// Called by the app on lifecycle changes.
  void setForeground(bool foreground) {
    _foreground = foreground;
    if (!foreground && state.busy) _backgroundedDuringTurn = true;
    if (foreground && _pendingRecovery != null) unawaited(_recover());
  }

  Future<void> _recover() async {
    final id = _pendingRecovery;
    _pendingRecovery = null;
    if (id == null || !ref.mounted || state.conversationId != id || state.busy) return;
    try {
      final detail = await ref.read(backendProvider).conversation(id);
      if (!ref.mounted || state.conversationId != id || state.busy) return;
      state = state.copyWith(items: detail.items, notice: interruptedNotice);
    } on BackendException catch (error) {
      _set((s) => s.copyWith(
            notice: interruptedNotice,
            items: [...s.items, ErrorItem(error.message)],
          ));
    }
  }

  static String _describe(Object error) => switch (error) {
        _Stopped() => 'Stopped.',
        BackendException(:final message) => message,
        _ => 'Something went wrong: $error',
      };
}

/// Completes a turn that the user stopped.
class _Stopped implements Exception {
  const _Stopped();
}
