import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_ui_mobile/core/errors.dart';
import 'package:agent_ui_mobile/data/backend/lan_agent_backend.dart';
import 'package:agent_ui_mobile/data/models/agent.dart';
import 'package:agent_ui_mobile/data/models/chat_item.dart';
import 'package:agent_ui_mobile/data/models/stream_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final base = Uri.parse('http://192.168.1.20:8000');

LanAgentBackend backendWith(MockClient client) =>
    LanAgentBackend(baseUrl: base, token: 'secret', client: client, timeout: const Duration(milliseconds: 200));

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  group('JSON endpoints', () {
    late List<http.Request> requests;
    late LanAgentBackend backend;

    setUp(() {
      requests = [];
      backend = backendWith(MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        return switch ((request.method, path)) {
          ('GET', '/api/auth') => jsonResponse({'required': true, 'authorized': true, 'local': false}),
          ('GET', '/api/agents') => jsonResponse([
              {'id': 'calc', 'name': 'Calc', 'description': '', 'model': 'm', 'logo': '/api/agents/calc/logo?v=5'},
            ]),
          ('GET', '/api/conversations') => jsonResponse([
              {'id': 'c1', 'agent_id': 'calc', 'title': 'Hi', 'created_at': 1.5, 'updated_at': 2.5},
            ]),
          ('POST', '/api/conversations') => jsonResponse(
              {'id': 'c2', 'agent_id': 'calc', 'title': 'New chat', 'created_at': 3, 'updated_at': 3}),
          ('GET', '/api/conversations/c1') => jsonResponse({
              'id': 'c1',
              'agent_id': 'calc',
              'title': 'Hi',
              'created_at': 1,
              'updated_at': 2,
              'items': [
                {'kind': 'user', 'content': 'hello'},
              ],
            }),
          _ => jsonResponse({'ok': true}),
        };
      }));
    });

    test('every request carries the Bearer token', () async {
      await backend.auth();
      await backend.agents();
      await backend.conversations();
      expect(requests.map((r) => r.headers['Authorization']), everyElement('Bearer secret'));
      expect(backend.authHeaders, {'Authorization': 'Bearer secret'});
    });

    test('parses auth, agents, conversations and detail', () async {
      expect((await backend.auth()).authorized, isTrue);
      final agents = await backend.agents();
      expect(agents.single.name, 'Calc');
      expect((await backend.conversations()).single.updatedAt, 2.5);
      expect((await backend.createConversation('calc')).id, 'c2');
      expect(jsonDecode(requests.last.body), {'agent_id': 'calc'});
      final detail = await backend.conversation('c1');
      expect(detail.items.single, isA<UserItem>());
    });

    test('logoUrl keeps the cache-busting query and is null without a logo', () async {
      final agent = (await backend.agents()).single;
      expect(backend.logoUrl(agent).toString(), 'http://192.168.1.20:8000/api/agents/calc/logo?v=5');
      expect(backend.logoUrl(const Agent(id: 'x', name: 'x')), isNull);
    });

    test('rename, delete, approve and stop send the right requests', () async {
      await backend.rename('c1', 'New title');
      await backend.delete('c1');
      await backend.approve('c1', 'call-9', approved: false);
      await backend.stop('c1');
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'PATCH /api/conversations/c1',
        'DELETE /api/conversations/c1',
        'POST /api/conversations/c1/approve',
        'POST /api/conversations/c1/stop',
      ]);
      expect(jsonDecode(requests[0].body), {'title': 'New title'});
      expect(jsonDecode(requests[2].body), {'call_id': 'call-9', 'approved': false});
    });
  });

  test('a base URL with a path prefix keeps it', () async {
    late Uri seen;
    final backend = LanAgentBackend(
      baseUrl: Uri.parse('https://pc.ts.net/agents'),
      token: 't',
      client: MockClient((request) async {
        seen = request.url;
        return jsonResponse([]);
      }),
    );
    await backend.agents();
    expect(seen.toString(), 'https://pc.ts.net/agents/api/agents');
  });

  group('errors', () {
    test('401 becomes UnauthorizedException with the server detail', () async {
      final backend = backendWith(MockClient((_) async => jsonResponse({'detail': 'Not signed in.'}, 401)));
      await expectLater(
        backend.agents(),
        throwsA(isA<UnauthorizedException>().having((e) => e.message, 'message', 'Not signed in.')),
      );
    });

    test('other statuses become ServerException', () async {
      final backend = backendWith(MockClient((_) async => jsonResponse({'detail': 'Conversation not found'}, 404)));
      await expectLater(
        backend.conversation('x'),
        throwsA(isA<ServerException>().having((e) => e.statusCode, 'status', 404)),
      );
      final plain = backendWith(MockClient((_) async => http.Response('boom', 500)));
      await expectLater(plain.conversations(), throwsA(isA<ServerException>()));
    });

    test('non-JSON or wrongly shaped bodies become ServerException', () async {
      final html = backendWith(MockClient((_) async => http.Response('<html>', 200)));
      await expectLater(html.agents(), throwsA(isA<ServerException>()));
      final shape = backendWith(MockClient((_) async => jsonResponse({'not': 'a list'})));
      await expectLater(shape.agents(), throwsA(isA<ServerException>()));
    });

    Future<UnreachableException> unreachable(Object error) async {
      final backend = backendWith(MockClient((_) async => throw error));
      try {
        await backend.auth();
      } on UnreachableException catch (e) {
        return e;
      }
      fail('expected UnreachableException');
    }

    test('socket errors map to a reason', () async {
      expect(
        (await unreachable(const SocketException('x', osError: OSError('Connection refused', 111)))).reason,
        UnreachableReason.refused,
      );
      expect(
        (await unreachable(const SocketException('x', osError: OSError('No route to host', 113)))).reason,
        UnreachableReason.noRoute,
      );
      expect(
        (await unreachable(const SocketException('Connection timed out'))).reason,
        UnreachableReason.timeout,
      );
      expect((await unreachable(const SocketException('Failed host lookup: pc'))).message, contains('"192.168.1.20"'));
      expect((await unreachable(http.ClientException('reset'))).reason, UnreachableReason.other);
      expect((await unreachable(const HandshakeException('tls'))).message, contains('Secure connection'));
    });

    test('a slow server times out', () async {
      final backend = backendWith(MockClient((_) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return jsonResponse({});
      }));
      await expectLater(
        backend.auth(),
        throwsA(isA<UnreachableException>().having((e) => e.reason, 'reason', UnreachableReason.timeout)),
      );
    });
  });

  group('sendMessage', () {
    test('streams events from chunked SSE and skips unknown ones', () async {
      late http.BaseRequest sent;
      late String sentBody;
      final backend = backendWith(MockClient.streaming((request, body) async {
        sent = request;
        sentBody = await body.bytesToString();
        final chunks = [
          'data: {"type":"status","message":"Thinking..."}\n\ndata: {"type":"ti',
          'tle","title":"Hello"}\n\ndata: {"type":"future_thing"}\n\n',
          'data: {"type":"final","content":"Hi ☃"}\n\n',
        ];
        return http.StreamedResponse(Stream.fromIterable(chunks.map(utf8.encode)), 200);
      }));

      final events = await backend.sendMessage('c1', 'hello').toList();
      expect(sent.url.path, '/api/conversations/c1/messages');
      expect(sent.headers['Authorization'], 'Bearer secret');
      expect(jsonDecode(sentBody), {'content': 'hello'});
      expect(events.map((e) => e.runtimeType), [StatusEvent, TitleEvent, FinalEvent]);
      expect((events.last as FinalEvent).content, 'Hi ☃');
    });

    test('decodes UTF-8 split in the middle of a character', () async {
      final bytes = utf8.encode('data: {"type":"final","content":"été"}\n\n');
      final backend = backendWith(MockClient.streaming((_, _) async => http.StreamedResponse(
            Stream.fromIterable([bytes.sublist(0, 33), bytes.sublist(33)]),
            200,
          )));
      final events = await backend.sendMessage('c1', 'x').toList();
      expect((events.single as FinalEvent).content, 'été');
    });

    test('a 401 response is an UnauthorizedException on the stream', () async {
      final backend = backendWith(MockClient.streaming(
          (_, _) async => http.StreamedResponse(Stream.value(utf8.encode('{"detail":"Not signed in."}')), 401)));
      await expectLater(backend.sendMessage('c1', 'x'), emitsError(isA<UnauthorizedException>()));
    });

    test('a failed connection is an UnreachableException on the stream', () async {
      final backend = backendWith(MockClient.streaming((_, _) async => throw const SocketException('refused')));
      await expectLater(backend.sendMessage('c1', 'x'), emitsError(isA<UnreachableException>()));
    });

    test('a connection dropped mid-stream is reported', () async {
      final backend = backendWith(MockClient.streaming((_, _) async {
        final controller = StreamController<List<int>>();
        controller
          ..add(utf8.encode('data: {"type":"status","message":"a"}\n\n'))
          ..addError(http.ClientException('Connection closed while receiving data'));
        unawaited(controller.close());
        return http.StreamedResponse(controller.stream, 200);
      }));
      await expectLater(
        backend.sendMessage('c1', 'x'),
        emitsInOrder([isA<StatusEvent>(), emitsError(isA<UnreachableException>()), emitsDone]),
      );
    });

    test('cancelling the subscription closes the response stream', () async {
      final body = StreamController<List<int>>();
      var bodyCancelled = false;
      body.onCancel = () => bodyCancelled = true;
      final backend = backendWith(MockClient.streaming((_, _) async => http.StreamedResponse(body.stream, 200)));

      final first = Completer<StreamEvent>();
      final subscription = backend.sendMessage('c1', 'x').listen(first.complete);
      body.add(utf8.encode('data: {"type":"status","message":"a"}\n\n'));
      await first.future;
      await subscription.cancel();
      expect(bodyCancelled, isTrue);
      await body.close();
    });
  });

  test('close closes the client', () {
    var closed = false;
    final client = _ClosingClient(() => closed = true);
    LanAgentBackend(baseUrl: base, token: 't', client: client).close();
    expect(closed, isTrue);
  });
}

class _ClosingClient extends http.BaseClient {
  _ClosingClient(this.onClose);

  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => throw UnimplementedError();

  @override
  void close() => onClose();
}
