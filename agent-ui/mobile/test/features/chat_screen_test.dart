import 'package:agent_ui_mobile/core/errors.dart';
import 'package:agent_ui_mobile/data/models/chat_item.dart';
import 'package:agent_ui_mobile/data/models/stream_event.dart';
import 'package:agent_ui_mobile/domain/chat_controller.dart';
import 'package:agent_ui_mobile/features/chat/widgets/activity_group.dart';
import 'package:agent_ui_mobile/features/chat/widgets/message_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';

import '../support/harness.dart';

const markdownReply = '''
The answer is **3**.

| a | b | sum |
|---|---|-----|
| 1 | 2 | 3 |

```python
print(1 + 2)
```

Inline math: \$a^2 + b^2 = c^2\$
''';

void main() {
  late Harness harness;
  final field = find.byKey(const Key('composer-field'));
  final send = find.byKey(const Key('composer-send'));
  final stop = find.byKey(const Key('composer-stop'));

  /// Spinners never settle, so busy screens are pumped frame by frame for a
  /// fixed time, long enough for auto-scroll and expand animations to finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

  Future<void> start(WidgetTester tester) async {
    harness = await Harness.create();
    await harness.pumpApp(tester);
  }

  Future<void> sendText(WidgetTester tester, String text) async {
    await tester.enterText(field, text);
    await tester.pump();
    await tester.tap(send);
    await settle(tester);
  }

  testWidgets('a new chat greets with the agent, then streams a full turn', (tester) async {
    await start(tester);
    expect(find.byKey(const Key('greeting-name')), findsOneWidget);
    expect(find.text('Does maths with tools.'), findsOneWidget);
    expect(find.text('Ask Calculator anything...'), findsOneWidget);

    await sendText(tester, 'What is 1+2?');
    expect(find.byType(UserBubble), findsOneWidget);
    expect(find.text('What is 1+2?'), findsOneWidget);
    expect(find.text('Thinking...'), findsOneWidget);
    expect(stop, findsOneWidget);

    harness.backend.emit(const ToolCallEvent(callId: 't1', name: 'add', args: {'a': 1, 'b': 2}));
    await settle(tester);
    expect(find.byType(ActivityGroup), findsOneWidget);
    expect(find.text('Running add...'), findsOneWidget);

    harness.backend.emit(const ApprovalRequiredEvent(callId: 't1', name: 'add', warning: 'Adds numbers.'));
    await settle(tester);
    expect(find.textContaining('Adds numbers.'), findsOneWidget, reason: 'forced open');
    expect(harness.devices.approvalHaptics, 1);
    await tester.tap(find.byKey(const Key('approve-t1')));
    await settle(tester);
    expect(harness.backend.approvals.single.approved, isTrue);

    harness.backend.emit(const ToolResultEvent(callId: 't1', name: 'add', content: '3'));
    harness.backend.emit(const FinalEvent(markdownReply));
    await harness.backend.finishTurn();
    await tester.pumpAndSettle();

    expect(stop, findsNothing);
    expect(find.text('Used 1 tool'), findsOneWidget);
    expect(find.byType(AssistantMessage), findsOneWidget);
    expect(find.byType(CodeField), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(harness.devices.awake, isFalse);
  });

  testWidgets('stop ends the turn and says Stopped.', (tester) async {
    await start(tester);
    await sendText(tester, 'long job');
    harness.backend.emit(const ToolCallEvent(callId: 't1', name: 'slow'));
    await settle(tester);

    await tester.tap(stop);
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Stopped.'), findsOneWidget);
    expect(find.byType(ErrorMessage), findsOneWidget);
    expect(harness.backend.turnCancelled, isTrue);
    expect(send, findsOneWidget);
  });

  testWidgets('error events show inline', (tester) async {
    await start(tester);
    await sendText(tester, 'hi');
    harness.backend.emit(const ErrorEvent('Could not start agent: Ollama is not running.'));
    await harness.backend.finishTurn();
    await tester.pumpAndSettle();
    expect(find.textContaining('Ollama is not running'), findsOneWidget);
  });

  testWidgets('an unreachable backend shows a banner with Retry', (tester) async {
    harness = await Harness.create();
    harness.backend.failWith = const UnreachableException('Can\'t reach 192.168.1.20:8000.');
    await harness.pumpApp(tester);
    expect(find.byKey(const Key('connection-banner')), findsOneWidget);
    expect(find.textContaining('Can\'t reach'), findsOneWidget);

    harness.backend.failWith = null;
    await tester.tap(find.descendant(of: find.byKey(const Key('connection-banner')), matching: find.text('Retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('connection-banner')), findsNothing);
    expect(find.byKey(const Key('greeting-name')), findsOneWidget);
  });

  testWidgets('a turn interrupted in the background reloads and explains', (tester) async {
    await start(tester);
    await sendText(tester, 'hi');
    final controller = container(tester).read(chatControllerProvider.notifier);
    controller.setForeground(false);
    harness.backend.failTurn(const UnreachableException('Lost the connection.'));
    await settle(tester);
    expect(stop, findsNothing, reason: 'no spinner left hanging');

    controller.setForeground(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notice-banner')), findsOneWidget);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notice-banner')), findsNothing);
  });

  testWidgets('history renders with the same widgets as live items', (tester) async {
    harness = await Harness.create();
    final saved = harness.backend.seed('Saved', items: const [
      UserItem('hello'),
      ThinkingItem('hmm'),
      ToolItem(id: 'h1-0', name: 'add', args: {'a': 1}, result: '2', status: ToolStatus.done),
      AssistantItem('Hi **there**'),
      ErrorItem('Stopped.'),
    ]);
    await harness.pumpApp(tester);
    await container(tester).read(chatControllerProvider.notifier).openConversation(saved.id);
    await tester.pumpAndSettle();
    expect(find.byType(UserBubble), findsOneWidget);
    expect(find.byType(ActivityGroup), findsOneWidget);
    expect(find.text('Thought, used 1 tool'), findsOneWidget);
    expect(find.byType(AssistantMessage), findsOneWidget);
    expect(find.byType(ErrorMessage), findsOneWidget);
  });

  testWidgets('scrolling up stops following and shows Jump to latest', (tester) async {
    harness = await Harness.create();
    final saved = harness.backend.seed('Long', items: [
      for (var i = 0; i < 30; i++) ...[UserItem('Question $i'), AssistantItem('Answer $i with some words.')],
    ]);
    await harness.pumpApp(tester);
    await container(tester).read(chatControllerProvider.notifier).openConversation(saved.id);
    await tester.pumpAndSettle();
    expect(find.text('Question 29'), findsOneWidget, reason: 'opens at the bottom');
    expect(find.byKey(const Key('jump-to-latest')), findsNothing);

    await tester.fling(find.byKey(const Key('chat-list')), const Offset(0, 2000), 3000);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('jump-to-latest')), findsOneWidget);

    await tester.tap(find.byKey(const Key('jump-to-latest')));
    await tester.pumpAndSettle();
    expect(find.text('Question 29'), findsOneWidget);
    expect(find.byKey(const Key('jump-to-latest')), findsNothing);
  });

  testWidgets('long-press a message to copy it', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    await start(tester);
    await sendText(tester, 'copy me');
    await harness.backend.finishTurn();
    await tester.pumpAndSettle();

    await tester.longPress(find.text('copy me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, 'copy me');
    expect(find.text('Copied'), findsOneWidget);
  });
}
