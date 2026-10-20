import 'package:agent_ui_mobile/core/errors.dart';
import 'package:agent_ui_mobile/data/models/chat_item.dart';
import 'package:agent_ui_mobile/data/models/stream_event.dart';
import 'package:agent_ui_mobile/domain/agents_controller.dart';
import 'package:agent_ui_mobile/domain/chat_controller.dart';
import 'package:agent_ui_mobile/domain/conversations_controller.dart';
import 'package:agent_ui_mobile/domain/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  late Harness harness;
  late ProviderContainer container;

  ChatState chat() => container.read(chatControllerProvider);
  ChatController controller() => container.read(chatControllerProvider.notifier);
  ToolItem tool(String id) => chat().items.whereType<ToolItem>().firstWhere((t) => t.id == id);

  setUp(() async {
    harness = await Harness.create();
    container = await harness.container();
    container.listen(chatControllerProvider, (_, _) {});
    container.listen(currentAgentProvider, (_, _) {});
    await container.read(agentsProvider.future);
    await container.read(conversationsProvider.future);
  });

  /// Sends [text] and waits until the turn's stream is open. [turn]
  /// completes when the turn ends.
  late Future<void> turn;
  Future<void> startTurn(String text) async {
    turn = controller().send(text);
    await pumpEventQueue();
    expect(harness.backend.turn, isNotNull, reason: 'the turn should be streaming');
  }

  test('a full turn: create, status, title, tool, approval, result, final', () async {
    await startTurn('  What is 1+2?  ');

    final id = chat().conversationId!;
    expect(harness.backend.calls, containsAllInOrder(['create:calc', 'send:$id:What is 1+2?']));
    expect(chat().busy, isTrue);
    expect(chat().agentLocked, isTrue);
    expect(chat().status, 'Thinking...');
    expect(chat().items.single, isA<UserItem>());
    expect(harness.devices.awake, isTrue);
    expect(container.read(conversationsProvider).value!.first.id, id);

    harness.backend.emit(const StatusEvent('Starting Calculator...'));
    harness.backend.emit(const TitleEvent('What is 1+2?'));
    harness.backend.emit(const ThinkingEvent('Use add.'));
    harness.backend.emit(const ToolCallEvent(callId: 't1', name: 'add', args: {'a': 1, 'b': 2}));
    await pumpEventQueue();
    expect(chat().status, 'Running add...');
    expect(tool('t1').status, ToolStatus.running);
    expect(container.read(conversationsProvider).value!.first.title, 'What is 1+2?');

    harness.backend.emit(const ApprovalRequiredEvent(callId: 't1', name: 'add', warning: 'Adds numbers.'));
    await pumpEventQueue();
    expect(chat().status, 'Waiting for your approval...');
    expect(tool('t1').status, ToolStatus.approval);
    expect(tool('t1').warning, 'Adds numbers.');
    expect(chat().awaitingApproval, isTrue);
    expect(harness.devices.approvalHaptics, 1);

    await controller().decide('t1', approved: true);
    expect(harness.backend.approvals.single.approved, isTrue);
    expect(tool('t1').status, ToolStatus.running);
    expect(chat().status, 'Running approved action...');

    harness.backend.emit(const ToolResultEvent(callId: 't1', name: 'add', content: '3'));
    harness.backend.emit(const FinalEvent('The answer is **3**.'));
    await pumpEventQueue();
    expect(tool('t1').result, '3');
    expect(tool('t1').status, ToolStatus.done);
    expect(chat().status, 'Thinking...');

    await harness.backend.finishTurn();
    await turn;
    expect(chat().busy, isFalse);
    expect(chat().status, '');
    expect(chat().items.map((i) => i.kind), ['user', 'thinking', 'tool', 'assistant']);
    expect(harness.devices.awake, isFalse);
  });

  test('denying an approval says Cancelling', () async {
    await startTurn('delete it');
    harness.backend.emit(const ToolCallEvent(callId: 'd', name: 'delete_file'));
    harness.backend.emit(const ApprovalRequiredEvent(callId: 'd', name: 'delete_file', warning: 'Deletes.'));
    await pumpEventQueue();
    await controller().decide('d', approved: false);
    expect(chat().status, 'Cancelling...');
    expect(harness.backend.approvals.single.approved, isFalse);
    await harness.backend.finishTurn();
    await turn;
  });

  test('an error event is shown inline', () async {
    await startTurn('hi');
    harness.backend.emit(const ErrorEvent('Agent error.'));
    await harness.backend.finishTurn();
    await turn;
    expect(chat().items.last, isA<ErrorItem>().having((e) => e.content, 'content', 'Agent error.'));
  });

  test('a failed approve call is shown inline', () async {
    await startTurn('hi');
    harness.backend.emit(const ToolCallEvent(callId: 'x', name: 'n'));
    await pumpEventQueue();
    harness.backend.failWith = const ServerException('No running turn is waiting for approval.', statusCode: 409);
    await controller().decide('x', approved: true);
    expect((chat().items.last as ErrorItem).content, contains('No running turn'));
    harness.backend.failWith = null;
    await harness.backend.finishTurn();
    await turn;
  });

  test('stop tells the server, cancels the stream, marks tools done and says Stopped once', () async {
    await startTurn('long job');
    harness.backend.emit(const ToolCallEvent(callId: 't1', name: 'slow'));
    harness.backend.emit(const ApprovalRequiredEvent(callId: 't1', name: 'slow', warning: 'w'));
    await pumpEventQueue();

    await controller().stop();
    await turn;
    expect(harness.backend.calls, contains('stop:${chat().conversationId}'));
    expect(harness.backend.turnCancelled, isTrue);
    expect(chat().busy, isFalse);
    expect(tool('t1').status, ToolStatus.done);
    expect(chat().items.whereType<ErrorItem>().map((e) => e.content), ['Stopped.']);
    expect(harness.devices.awake, isFalse);
  });

  test('events that arrive after Stop are ignored', () async {
    await startTurn('x');
    final stopping = controller().stop();
    harness.backend.emit(const ErrorEvent('Stopped.'));
    await stopping;
    await turn;
    expect(chat().items.whereType<ErrorItem>(), hasLength(1));
  });

  test('a dropped connection in the foreground is reported as an error', () async {
    await startTurn('x');
    harness.backend.failTurn(const UnreachableException('Lost the connection to 192.168.1.20:8000.'));
    await turn;
    expect(chat().busy, isFalse);
    expect((chat().items.last as ErrorItem).content, 'Lost the connection to 192.168.1.20:8000.');
    expect(chat().notice, isNull);
  });

  test('a turn cut off in the background reloads from the server on resume', () async {
    await startTurn('x');
    final id = chat().conversationId!;
    harness.backend.emit(const ToolCallEvent(callId: 't', name: 'n'));
    await pumpEventQueue();

    controller().setForeground(false);
    harness.backend.failTurn(const UnreachableException('Lost the connection.'));
    await turn;
    expect(chat().busy, isFalse, reason: 'no spinner left hanging');
    expect(chat().items.whereType<ErrorItem>(), isEmpty);
    expect(harness.backend.calls.where((c) => c == 'get:$id'), isEmpty);

    controller().setForeground(true);
    await pumpEventQueue();
    expect(harness.backend.calls, contains('get:$id'));
    expect(chat().items.map((i) => i.kind), ['user'], reason: 'what the server saved');
    expect(chat().notice, interruptedNotice);
    controller().dismissNotice();
    expect(chat().notice, isNull);
  });

  test('a 401 during a turn signs the app out', () async {
    await startTurn('x');
    harness.backend.failTurn(const UnauthorizedException());
    await turn;
    await pumpEventQueue();
    expect(container.read(sessionProvider), isA<SignedOut>());
  });

  test('a failure creating the conversation is shown', () async {
    harness.backend.failWith = const UnreachableException('Can\'t reach it.');
    await controller().send('hello');
    expect(chat().busy, isFalse);
    expect((chat().items.single as ErrorItem).content, 'Can\'t reach it.');
  });

  test('empty text, a busy turn or no agent do nothing', () async {
    await controller().send('   ');
    expect(harness.backend.calls, isNot(contains(startsWith('create'))));
    await startTurn('first');
    await controller().send('second');
    expect(harness.backend.calls.where((c) => c.startsWith('send')), hasLength(1));
    controller().newChat();
    expect(chat().busy, isTrue, reason: 'new chat is blocked while busy');
    await harness.backend.finishTurn();
    await turn;
  });

  group('opening chats and the agent lock', () {
    test('opening a chat loads its items and follows its agent without saving it', () async {
      final saved = harness.backend.seed('Notes chat', agentId: 'notes', items: const [
        UserItem('hi'),
        ThinkingItem('t'),
        AssistantItem('hello'),
      ]);
      await controller().openConversation(saved.id);
      expect(chat().items.map((i) => i.kind), ['user', 'thinking', 'assistant']);
      expect(chat().agentLocked, isTrue);
      expect(container.read(currentAgentProvider)!.id, 'notes');
      expect(harness.store.lastAgentId, isNull);

      controller().newChat();
      expect(chat().isNewChat, isTrue);
      expect(chat().agentLocked, isFalse);
      expect(container.read(currentAgentProvider)!.id, 'notes', reason: 'keeps the agent of the last chat');
    });

    test('a failed load can be retried', () async {
      final saved = harness.backend.seed('x');
      harness.backend.failWith = const UnreachableException('offline');
      await controller().openConversation(saved.id);
      expect(chat().loadError, 'offline');
      harness.backend.failWith = null;
      await controller().retryLoad();
      expect(chat().loadError, isNull);
    });

    test('choosing an agent saves it; a missing saved agent falls back to the first', () async {
      expect(container.read(currentAgentProvider)!.id, 'calc');
      container.read(selectedAgentProvider.notifier).choose('notes');
      expect(container.read(currentAgentProvider)!.id, 'notes');
      expect(harness.store.lastAgentId, 'notes');
      container.read(selectedAgentProvider.notifier).follow('deleted-agent');
      expect(container.read(currentAgentProvider)!.id, 'calc');
    });

    test('a chat whose agent no longer exists has no current agent', () async {
      final saved = harness.backend.seed('Old', agentId: 'gone');
      await controller().openConversation(saved.id);
      expect(container.read(currentAgentProvider), isNull);
    });
  });

  group('conversations', () {
    test('rename trims, updates the list and ignores blank titles', () async {
      final saved = harness.backend.seed('Old');
      await container.read(conversationsProvider.notifier).refresh();
      await container.read(conversationsProvider.notifier).rename(saved.id, '  New title ');
      expect(harness.backend.calls, contains('rename:${saved.id}:New title'));
      expect(container.read(conversationsProvider).value!.single.title, 'New title');
      await container.read(conversationsProvider.notifier).rename(saved.id, '  ');
      expect(harness.backend.calls.where((c) => c.startsWith('rename')), hasLength(1));
    });

    test('deleting the open chat starts a new chat', () async {
      final saved = harness.backend.seed('Doomed');
      await container.read(conversationsProvider.notifier).refresh();
      await controller().openConversation(saved.id);
      await container.read(conversationsProvider.notifier).delete(saved.id);
      expect(chat().conversationId, isNull);
      expect(container.read(conversationsProvider).value, isEmpty);
    });

    test('a refresh failure is kept for the error banner', () async {
      harness.backend.failWith = const UnreachableException('down');
      await container.read(conversationsProvider.notifier).refresh();
      expect(container.read(conversationsProvider).error, isA<UnreachableException>());
    });
  });
}
