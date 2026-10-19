import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../core/utils/json.dart';
import '../../core/utils/qr_link_parser.dart';
import '../../core/utils/sse_parser.dart';
import '../models/agent.dart';
import '../models/auth_status.dart';
import '../models/conversation.dart';
import '../models/stream_event.dart';
import 'agent_backend.dart';

/// Talks to `agent-ui/backend` on the local network: JSON over HTTP, chat
/// turns over SSE, and the access token as `Authorization: Bearer` on every
/// request. It never uses the cookie or redirect sign-in (`GET /api/login`).
class LanAgentBackend implements AgentBackend {
  LanAgentBackend({
    required this.baseUrl,
    required String token,
    http.Client? client,
    this.timeout = requestTimeout,
  })  : _token = token, // ignore: prefer_initializing_formals, keeps the public parameter name `token`
        _client = client ?? IOClient(HttpClient()..connectionTimeout = connectTimeout);

  final Uri baseUrl;
  final String _token;
  final http.Client _client;
  final Duration timeout;

  String get _address => displayAddress(baseUrl);

  @override
  Map<String, String> get authHeaders => {'Authorization': 'Bearer $_token'};

  @override
  Future<AuthStatus> auth() async => _parse(await _request('GET', '/api/auth'), (body) => AuthStatus.fromJson(_object(body)));

  @override
  Future<List<Agent>> agents() async =>
      _parse(await _request('GET', '/api/agents'), (body) => _list(body).map(Agent.fromJson).toList());

  @override
  Uri? logoUrl(Agent agent) {
    final logo = agent.logo;
    if (logo == null) return null;
    final path = Uri.tryParse(logo);
    if (path == null) return null;
    // Keep the `?v=` cache-busting query the server adds.
    return _url(path.path, path.hasQuery ? path.queryParameters : null);
  }

  @override
  Future<List<Conversation>> conversations() async =>
      _parse(await _request('GET', '/api/conversations'), (body) => _list(body).map(Conversation.fromJson).toList());

  @override
  Future<Conversation> createConversation(String agentId) async =>
      _parse(await _request('POST', '/api/conversations', body: {'agent_id': agentId}),
          (body) => Conversation.fromJson(_object(body)));

  @override
  Future<ConversationDetail> conversation(String id) async =>
      _parse(await _request('GET', '/api/conversations/${_segment(id)}'),
          (body) => ConversationDetail.fromJson(_object(body)));

  @override
  Future<void> rename(String id, String title) =>
      _request('PATCH', '/api/conversations/${_segment(id)}', body: {'title': title});

  @override
  Future<void> delete(String id) => _request('DELETE', '/api/conversations/${_segment(id)}');

  @override
  Future<void> approve(String conversationId, String callId, {required bool approved}) => _request(
        'POST',
        '/api/conversations/${_segment(conversationId)}/approve',
        body: {'call_id': callId, 'approved': approved},
      );

  @override
  Future<void> stop(String conversationId) =>
      _request('POST', '/api/conversations/${_segment(conversationId)}/stop');

  @override
  Stream<StreamEvent> sendMessage(String conversationId, String content) {
    final abort = Completer<void>();
    StreamSubscription<String>? subscription;
    late final StreamController<StreamEvent> controller;

    Future<void> start() async {
      final request = http.AbortableRequest(
        'POST',
        _url('/api/conversations/${_segment(conversationId)}/messages'),
        abortTrigger: abort.future,
      )
        ..headers.addAll({...authHeaders, 'Content-Type': 'application/json', 'Accept': 'text/event-stream'})
        ..body = jsonEncode({'content': content});

      // No overall timeout: the server holds the response until the agent is
      // free, and a turn can legitimately run for minutes.
      final http.StreamedResponse response;
      try {
        response = await _client.send(request);
      } on Object catch (error) {
        if (!abort.isCompleted) controller.addError(_connectionError(error));
        await controller.close();
        return;
      }
      if (abort.isCompleted) {
        unawaited(response.stream.listen(null).cancel());
        return;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString().catchError((Object _) => '');
        controller.addError(_statusError(response.statusCode, body));
        await controller.close();
        return;
      }

      subscription = sseData(response.stream.transform(utf8.decoder)).listen(
        (data) {
          final event = StreamEvent.tryParse(data);
          if (event != null) controller.add(event);
        },
        onError: (Object error) {
          if (!abort.isCompleted) controller.addError(_connectionError(error));
        },
        onDone: controller.close,
      );
    }

    controller = StreamController<StreamEvent>(
      onListen: start,
      onCancel: () async {
        if (!abort.isCompleted) abort.complete();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  void close() => _client.close();

  // ---------------------------------------------------------------------------

  Uri _url(String path, [Map<String, String>? query]) {
    final prefix = baseUrl.path.endsWith('/') ? baseUrl.path.substring(0, baseUrl.path.length - 1) : baseUrl.path;
    return baseUrl.replace(path: '$prefix$path', queryParameters: query);
  }

  static String _segment(String id) => Uri.encodeComponent(id);

  /// Sends a JSON request and returns the decoded body (null when empty).
  Future<Object?> _request(String method, String path, {Object? body}) async {
    final request = http.Request(method, _url(path))
      ..headers.addAll({...authHeaders, 'Accept': 'application/json'});
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await _client.send(request).then(http.Response.fromStream).timeout(timeout);
    } on Object catch (error) {
      throw _connectionError(error);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _statusError(response.statusCode, response.body);
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw ServerException('The server at $_address sent an unexpected response. Is this the Agent UI?',
          statusCode: response.statusCode);
    }
  }

  /// Turns a decoded body into a model. A payload of the wrong shape becomes a
  /// [ServerException] instead of a raw [FormatException].
  T _parse<T>(Object? body, T Function(Object? body) convert) {
    try {
      return convert(body);
    } on FormatException catch (error) {
      throw ServerException('The server at $_address sent data this app does not understand (${error.message}).',
          statusCode: 200);
    }
  }

  static Json _object(Object? body) =>
      asJson(body) ?? (throw const FormatException('Expected a JSON object from the server.'));

  static List<Json> _list(Object? body) {
    if (body is! List) throw const FormatException('Expected a JSON list from the server.');
    return [for (final item in body) if (asJson(item) case final Json json) json];
  }

  BackendException _statusError(int status, String body) {
    String? detail;
    try {
      final decoded = asJson(jsonDecode(body));
      if (decoded?['detail'] case final String text) detail = text;
    } on FormatException {
      // Not JSON: fall back to the status code below.
    }
    if (status == 401) {
      return UnauthorizedException(detail ?? 'The server did not accept this device\'s access token.');
    }
    return ServerException(detail ?? 'The server answered with error $status.', statusCode: status);
  }

  // OS error codes on Linux/Android, iOS/macOS and Windows.
  static const _refusedCodes = {111, 61, 10061};
  static const _noRouteCodes = {113, 65, 101, 51, 10065, 10051};
  static const _timeoutCodes = {110, 60, 10060};

  BackendException _connectionError(Object error) {
    if (error is BackendException) return error;
    if (error is TimeoutException) return _unreachable(UnreachableReason.timeout);
    if (error is SocketException) {
      final code = error.osError?.errorCode;
      final text = '${error.message} ${error.osError?.message ?? ''}'.toLowerCase();
      if (_refusedCodes.contains(code) || text.contains('refused')) {
        return _unreachable(UnreachableReason.refused);
      }
      if (_noRouteCodes.contains(code) || text.contains('no route') || text.contains('unreachable')) {
        return _unreachable(UnreachableReason.noRoute);
      }
      if (_timeoutCodes.contains(code) || text.contains('timed out')) {
        return _unreachable(UnreachableReason.timeout);
      }
      if (text.contains('host lookup')) {
        return UnreachableException('Could not find the computer called "${baseUrl.host}". Try its IP address.',
            reason: UnreachableReason.noRoute);
      }
    }
    if (error is HandshakeException) {
      return UnreachableException('Secure connection to $_address failed. Use http:// for a computer on your Wi-Fi.');
    }
    if (error is FormatException) {
      return ServerException('The server at $_address sent an unexpected response.', statusCode: 200);
    }
    return UnreachableException('Lost the connection to $_address.');
  }

  UnreachableException _unreachable(UnreachableReason reason) => UnreachableException(
        switch (reason) {
          UnreachableReason.refused =>
            'Nothing is answering at $_address. Check that run_ui.ps1 is running on the computer and that the port is right.',
          UnreachableReason.noRoute =>
            'Can\'t reach $_address. Your phone is probably not on the same Wi-Fi as the computer.',
          UnreachableReason.timeout =>
            'Timed out reaching $_address. Make sure your phone is on the same Wi-Fi as the computer, '
                'and that Windows Firewall allows the port.',
          UnreachableReason.other => 'Lost the connection to $_address.',
        },
        reason: reason,
      );
}
