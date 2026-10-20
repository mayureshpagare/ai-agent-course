import 'package:agent_ui_mobile/data/models/agent.dart';
import 'package:agent_ui_mobile/data/models/auth_status.dart';
import 'package:agent_ui_mobile/data/models/chat_item.dart';
import 'package:agent_ui_mobile/data/models/connection_profile.dart';
import 'package:agent_ui_mobile/data/models/conversation.dart';
import 'package:agent_ui_mobile/data/models/stream_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Agent', () {
    test('parses /api/agents items', () {
      final agent = Agent.fromJson({
        'id': '01-calc-agent',
        'name': 'Calculator',
        'description': 'Maths',
        'model': 'qwen3:8b',
        'logo': '/api/agents/01-calc-agent/logo?v=17',
      });
      expect(agent.name, 'Calculator');
      expect(agent.logo, '/api/agents/01-calc-agent/logo?v=17');
      expect(agent.initial, 'C');
      expect(Agent.fromJson(agent.toJson()).model, 'qwen3:8b');
    });

    test('falls back to the id and no logo', () {
      final agent = Agent.fromJson({'id': 'x', 'logo': null});
      expect(agent.name, 'x');
      expect(agent.logo, isNull);
      expect(const Agent(id: 'e', name: '').initial, '?');
    });

    test('requires an id', () {
      expect(() => Agent.fromJson({'name': 'n'}), throwsFormatException);
    });
  });

  test('AuthStatus parses /api/auth', () {
    final status = AuthStatus.fromJson({'required': true, 'authorized': false, 'local': false});
    expect(status.required, isTrue);
    expect(status.authorized, isFalse);
    expect(AuthStatus.fromJson({}).authorized, isFalse);
  });

  group('Conversation', () {
    final json = {
      'id': 'abc',
      'agent_id': 'calc',
      'title': 'Sum',
      'created_at': 1712345678.25,
      'updated_at': 1712345679,
    };

    test('parses float and int timestamps', () {
      final conversation = Conversation.fromJson(json);
      expect(conversation.createdAt, 1712345678.25);
      expect(conversation.updatedAt, 1712345679.0);
      expect(conversation.updated.millisecondsSinceEpoch, 1712345679000);
      expect(conversation.copyWith(title: 'New').title, 'New');
      expect(Conversation.fromJson(conversation.toJson()).agentId, 'calc');
    });

    test('ConversationDetail parses items and skips unknown kinds', () {
      final detail = ConversationDetail.fromJson({
        ...json,
        'items': [
          {'kind': 'user', 'content': 'hi'},
          {'kind': 'thinking', 'content': 'hmm'},
          {
            'kind': 'tool',
            'id': 'h1-0',
            'name': null,
            'args': {'a': 1},
            'result': '{"ok": true}',
            'status': 'done',
          },
          {'kind': 'assistant', 'content': 'done'},
          {'kind': 'error', 'content': 'oops'},
          {'kind': 'video', 'content': '?'},
          'not an object',
        ],
      });
      expect(detail.items.map((i) => i.kind), ['user', 'thinking', 'tool', 'assistant', 'error']);
      final tool = detail.items[2] as ToolItem;
      expect(tool.name, 'tool');
      expect(tool.status, ToolStatus.done);
      expect(tool.args, {'a': 1});
    });
  });

  group('ChatItem', () {
    test('round-trips through JSON', () {
      const items = <ChatItem>[
        UserItem('u'),
        AssistantItem('a'),
        ErrorItem('e'),
        ThinkingItem('t'),
        ToolItem(id: '1', name: 'add', args: {'x': 1}, status: ToolStatus.approval, warning: 'careful'),
      ];
      for (final item in items) {
        expect(ChatItem.tryFromJson(item.toJson())!.toJson(), item.toJson());
      }
    });

    test('a tool without an id is skipped, and odd args are kept', () {
      expect(ChatItem.tryFromJson({'kind': 'tool', 'name': 'x'}), isNull);
      expect(ChatItem.tryFromJson(null), isNull);
      expect(ToolItem.parseArgs('raw'), {'value': 'raw'});
      expect(ToolItem.parseArgs(null), isEmpty);
    });

    test('unknown tool status defaults to done; copyWith keeps fields', () {
      final tool = ToolItem.fromJson({'id': '1', 'name': 'n', 'status': 'weird'});
      expect(tool.status, ToolStatus.done);
      final updated = tool.copyWith(result: 'r');
      expect(updated.result, 'r');
      expect(updated.name, 'n');
    });
  });

  group('StreamEvent', () {
    test('parses every event type', () {
      final events = [
        '{"type":"status","message":"Thinking..."}',
        '{"type":"title","title":"Sum of numbers"}',
        '{"type":"thinking","content":"Let me add."}',
        '{"type":"tool_call","call_id":"c1","name":"add","args":{"a":1,"b":2}}',
        '{"type":"approval_required","call_id":"c1","name":"delete","args":{},"warning":"Deletes a file."}',
        '{"type":"tool_result","call_id":"c1","name":"add","content":"3"}',
        '{"type":"final","content":"It is **3**."}',
        '{"type":"error","message":"Agent error."}',
      ].map(StreamEvent.tryParse).toList();

      expect(events[0], isA<StatusEvent>().having((e) => e.message, 'message', 'Thinking...'));
      expect(events[1], isA<TitleEvent>().having((e) => e.title, 'title', 'Sum of numbers'));
      expect(events[2], isA<ThinkingEvent>().having((e) => e.content, 'content', 'Let me add.'));
      expect(events[3], isA<ToolCallEvent>().having((e) => e.args, 'args', {'a': 1, 'b': 2}));
      expect(events[4], isA<ApprovalRequiredEvent>().having((e) => e.warning, 'warning', 'Deletes a file.'));
      expect(events[5], isA<ToolResultEvent>().having((e) => e.content, 'content', '3'));
      expect(events[6], isA<FinalEvent>().having((e) => e.content, 'content', 'It is **3**.'));
      expect(events[7], isA<ErrorEvent>().having((e) => e.message, 'message', 'Agent error.'));
    });

    test('ignores unknown types, bad JSON and malformed events', () {
      expect(StreamEvent.tryParse('{"type":"progress","value":3}'), isNull);
      expect(StreamEvent.tryParse('{not json'), isNull);
      expect(StreamEvent.tryParse('[1,2]'), isNull);
      expect(StreamEvent.tryParse('{"type":"tool_call","name":"x"}'), isNull);
      expect(StreamEvent.tryParse('{"type":"title"}'), isNull);
    });
  });

  group('ConnectionProfile', () {
    test('round-trips and rejects unknown auth kinds', () {
      final profile = ConnectionProfile(
        id: 'p1',
        label: 'My PC',
        baseUrl: Uri.parse('http://192.168.1.20:8000'),
        authKind: AuthKind.lanToken,
        createdAt: DateTime.utc(2026, 10, 19),
      );
      final copy = ConnectionProfile.tryFromJson(profile.toJson())!;
      expect(copy.baseUrl, profile.baseUrl);
      expect(copy.createdAt, profile.createdAt);
      expect(ConnectionProfile.tryFromJson({...profile.toJson(), 'authKind': 'oauth'}), isNull);
    });
  });
}
