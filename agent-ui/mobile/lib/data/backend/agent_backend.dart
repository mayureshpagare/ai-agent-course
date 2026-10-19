import '../models/agent.dart';
import '../models/auth_status.dart';
import '../models/conversation.dart';
import '../models/stream_event.dart';

/// Everything the app needs from an agent server. Widgets and controllers
/// depend only on this interface, never on URLs or a transport.
///
/// Today's implementation is `LanAgentBackend` (HTTP + SSE + Bearer token on
/// the local network). A hosted version adds another implementation; see
/// docs/FUTURE_REMOTE.md.
///
/// Failures are thrown as `BackendException` subclasses from core/errors.dart.
abstract interface class AgentBackend {
  /// Checks the credentials. `authorized` is false for a wrong token.
  Future<AuthStatus> auth();

  Future<List<Agent>> agents();

  /// Where to load [agent]'s logo from, or null when it has none. Requests
  /// for it must carry [authHeaders].
  Uri? logoUrl(Agent agent);

  /// Headers that authenticate a request made outside this class, such as an
  /// image load.
  Map<String, String> get authHeaders;

  /// Every conversation, across all agents, newest first.
  Future<List<Conversation>> conversations();

  Future<Conversation> createConversation(String agentId);

  Future<ConversationDetail> conversation(String id);

  Future<void> rename(String id, String title);

  Future<void> delete(String id);

  Future<void> approve(String conversationId, String callId, {required bool approved});

  /// Asks the server to stop the running turn. The caller still cancels its
  /// [sendMessage] subscription.
  Future<void> stop(String conversationId);

  /// Sends a user message and streams the turn's events until it ends.
  /// Cancelling the subscription drops the connection, which makes the
  /// server end the turn.
  Stream<StreamEvent> sendMessage(String conversationId, String content);

  /// Releases network resources. The backend is unusable afterwards.
  void close();
}
