import 'package:agent_ui_mobile/data/models/chat_item.dart';
import 'package:agent_ui_mobile/domain/activity.dart';
import 'package:agent_ui_mobile/domain/chat_blocks.dart';
import 'package:flutter_test/flutter_test.dart';

ToolItem tool(String id) => ToolItem(id: id, name: 'add');

void main() {
  group('toBlocks', () {
    test('returns nothing for no items', () {
      expect(toBlocks(const []), isEmpty);
    });

    test('merges consecutive thinking and tool items into one activity block', () {
      final blocks = toBlocks([
        const UserItem('What is 1+2?'),
        const ThinkingItem('Use add.'),
        tool('t1'),
        tool('t2'),
        const AssistantItem('3'),
      ]);
      expect(blocks.map((b) => b.key), ['m0', 'a1', 'm4']);
      final activity = blocks[1] as ActivityBlock;
      expect(activity.steps, hasLength(3));
      expect((blocks[2] as MessageBlock).item.content, '3');
    });

    test('a message between activity runs starts a new block', () {
      final blocks = toBlocks([tool('t1'), const ErrorItem('x'), const ThinkingItem('again')]);
      expect(blocks.map((b) => b.runtimeType), [ActivityBlock, MessageBlock, ActivityBlock]);
      expect(blocks.map((b) => b.key), ['a0', 'm1', 'a2']);
    });

    test('keys stay stable as items are appended', () {
      final before = toBlocks([const UserItem('q'), const ThinkingItem('t')]);
      final after = toBlocks([const UserItem('q'), const ThinkingItem('t'), tool('t1')]);
      expect(after.map((b) => b.key), before.map((b) => b.key));
    });
  });

  group('activitySummary', () {
    test('matches the web app wording', () {
      expect(activitySummary([const ThinkingItem('x')]), 'Thought');
      expect(activitySummary([tool('1')]), 'Used 1 tool');
      expect(activitySummary([tool('1'), tool('2')]), 'Used 2 tools');
      expect(activitySummary([const ThinkingItem('x'), tool('1'), tool('2')]), 'Thought, used 2 tools');
      expect(activitySummary(const []), '');
    });
  });

  group('argSummary and prettyResult', () {
    test('formats args like JSON.stringify', () {
      expect(argSummary({'path': 'a.txt', 'n': 3.0, 'flag': true, 'list': [1, 2.5]}),
          'path="a.txt", n=3, flag=true, list=[1,2.5]');
      expect(argSummary(const {}), '');
    });

    test('pretty-prints JSON results and keeps plain text', () {
      expect(prettyResult('{"a":1,"b":[1,2]}'), '{\n  "a": 1,\n  "b": [\n    1,\n    2\n  ]\n}');
      expect(prettyResult('plain text'), 'plain text');
      expect(prettyResult({'x': 2.0}), '{\n  "x": 2\n}');
    });
  });
}
