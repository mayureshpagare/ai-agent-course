import 'dart:async';

import 'package:agent_ui_mobile/core/errors.dart';
import 'package:agent_ui_mobile/data/backend/agent_backend.dart';
import 'package:agent_ui_mobile/data/models/agent.dart';
import 'package:agent_ui_mobile/data/models/auth_status.dart';
import 'package:agent_ui_mobile/data/models/chat_item.dart';
import 'package:agent_ui_mobile/data/models/conversation.dart';
import 'package:agent_ui_mobile/data/models/stream_event.dart';

/// An in-memory [AgentBackend] for widget, controller and integration tests.
///
/// Turns are scripted: each [sendMessage] call opens a [StreamController]
/// that the test feeds with [emit] and ends with [finishTurn].
class FakeAgentBackend implements AgentBackend {
  FakeAgentBackend({
    List<Agent>? agents,
    this.token = 'good-token',
  }) : agentList = agents ??
            const [
              Agent(id: 'calc', name: 'Calculator', description: 'Does maths with tools.', model: 'qwen3'),
              Agent(id: 'notes', name: 'Notes', description: 'Reads and writes notes.', model: 'llama3'),
            ];

  final List<Agent> agentList;
  final String token;
  final Map<String, Conversation> chats = {};
  final Map<String, List<ChatItem>> history = {};
  final List<String> calls = [];
  final List<({String conversationId, String callId, bool approved})> approvals = [];

  /// When set, every call throws this (e.g. an [UnauthorizedException]).
  BackendException? failWith;

  /// When set, [auth] reports unauthorized for any other token.
  String? presentedToken;

  StreamController<StreamEvent>? turn;
  bool turnCancelled = false;
  var _nextId = 1;
  var _clock = 1000.0;

  void _check(String call) {
    calls.add(call);
    final failure = failWith;
    if (failure != null) throw failure;
  }

  /// Adds a saved chat with [items] as its history.
  Conversation seed(String title, {String agentId = 'calc', List<ChatItem> items = const []}) {
    final conversation = Conversation(
      id: 'c${_nextId++}',
      agentId: agentId,
      title: title,
      createdAt: _clock,
      updatedAt: _clock++,
    );
    chats[conversation.id] = conversation;
    history[conversation.id] = [...items];
    return conversation;
  }

  void emit(StreamEvent event) => turn!.add(event);

  void failTurn(Object error) => turn!.addError(error);

  Future<void> finishTurn() async {
    final controller = turn;
    turn = null;
    await controller?.close();
  }

  @override
  Future<AuthStatus> auth() async {
    _check('auth');
    final ok = presentedToken == null || presentedToken == token;
    return AuthStatus(required: true, authorized: ok, local: false);
  }

  @override
  Future<List<Agent>> agents() async {
    _check('agents');
    return agentList;
  }

  @override
  Uri? logoUrl(Agent agent) => null;

  @override
  Map<String, String> get authHeaders => {'Authorization': 'Bearer $token'};

  @override
  Future<List<Conversation>> conversations() async {
    _check('conversations');
    return chats.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<Conversation> createConversation(String agentId) async {
    _check('create:$agentId');
    return seed('New chat', agentId: agentId);
  }

  @override
  Future<ConversationDetail> conversation(String id) async {
    _check('get:$id');
    final chat = chats[id];
    if (chat == null) throw const ServerException('Conversation not found', statusCode: 404);
    return ConversationDetail(conversation: chat, items: [...?history[id]]);
  }

  @override
  Future<void> rename(String id, String title) async {
    _check('rename:$id:$title');
    chats[id] = chats[id]!.copyWith(title: title);
  }

  @override
  Future<void> delete(String id) async {
    _check('delete:$id');
    chats.remove(id);
    history.remove(id);
  }

  @override
  Future<void> approve(String conversationId, String callId, {required bool approved}) async {
    _check('approve:$callId:$approved');
    approvals.add((conversationId: conversationId, callId: callId, approved: approved));
  }

  @override
  Future<void> stop(String conversationId) async {
    _check('stop:$conversationId');
  }

  @override
  Stream<StreamEvent> sendMessage(String conversationId, String content) {
    _check('send:$conversationId:$content');
    history[conversationId]?.add(UserItem(content));
    turnCancelled = false;
    final controller = StreamController<StreamEvent>();
    controller.onCancel = () => turnCancelled = true;
    turn = controller;
    return controller.stream;
  }

  @override
  void close() => calls.add('close');
}
