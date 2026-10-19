import 'dart:async';

import '../../core/errors.dart';
import '../models/agent.dart';
import '../models/auth_status.dart';
import '../models/conversation.dart';
import '../models/stream_event.dart';
import 'agent_backend.dart';

/// Wraps a backend and calls [onUnauthorized] whenever the server rejects the
/// credentials, so a 401 from any request signs the app out in one place.
class AuthGuardedBackend implements AgentBackend {
  AuthGuardedBackend(this.inner, {required this.onUnauthorized});

  final AgentBackend inner;
  final void Function() onUnauthorized;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on UnauthorizedException {
      onUnauthorized();
      rethrow;
    }
  }

  @override
  Future<AuthStatus> auth() => _guard(() async {
        final status = await inner.auth();
        if (!status.authorized) throw const UnauthorizedException();
        return status;
      });

  @override
  Future<List<Agent>> agents() => _guard(inner.agents);

  @override
  Uri? logoUrl(Agent agent) => inner.logoUrl(agent);

  @override
  Map<String, String> get authHeaders => inner.authHeaders;

  @override
  Future<List<Conversation>> conversations() => _guard(inner.conversations);

  @override
  Future<Conversation> createConversation(String agentId) => _guard(() => inner.createConversation(agentId));

  @override
  Future<ConversationDetail> conversation(String id) => _guard(() => inner.conversation(id));

  @override
  Future<void> rename(String id, String title) => _guard(() => inner.rename(id, title));

  @override
  Future<void> delete(String id) => _guard(() => inner.delete(id));

  @override
  Future<void> approve(String conversationId, String callId, {required bool approved}) =>
      _guard(() => inner.approve(conversationId, callId, approved: approved));

  @override
  Future<void> stop(String conversationId) => _guard(() => inner.stop(conversationId));

  @override
  Stream<StreamEvent> sendMessage(String conversationId, String content) =>
      inner.sendMessage(conversationId, content).transform(
            StreamTransformer.fromHandlers(handleError: (error, stackTrace, sink) {
              if (error is UnauthorizedException) onUnauthorized();
              sink.addError(error, stackTrace);
            }),
          );

  @override
  void close() => inner.close();
}
