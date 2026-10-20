import 'package:agent_ui_mobile/data/models/stream_event.dart';
import 'package:agent_ui_mobile/features/chat/widgets/activity_group.dart';
import 'package:agent_ui_mobile/features/chat/widgets/message_widgets.dart';
import 'package:agent_ui_mobile/features/pairing/pairing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/harness.dart';

/// The full happy path against `FakeAgentBackend`:
/// pair → pick agent → send → tool card → approve → Markdown answer →
/// rename → delete.
///
/// Shared by integration_test/app_test.dart (on a device) and
/// test/happy_path_test.dart (on the VM, so `flutter test` covers it too).
Future<void> runHappyPath(WidgetTester tester) async {
  Future<void> frames([int count = 10]) async {
    // Spinners never settle while a turn runs, so pump a fixed number of frames.
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  final harness = await Harness.create(signedIn: false);
  final backend = harness.backend;
  await harness.pumpApp(tester);

  // 1. Pair by hand.
  expect(find.byType(PairingScreen), findsOneWidget);
  await tester.enterText(find.byKey(const Key('pairing-address')), '192.168.1.20:8000');
  await tester.enterText(find.byKey(const Key('pairing-token')), backend.token);
  await tester.ensureVisible(find.byKey(const Key('pairing-connect')));
  await tester.tap(find.byKey(const Key('pairing-connect')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('greeting-name')), findsOneWidget);

  // 2. Pick the notes agent for this new chat.
  await tester.tap(find.byKey(const Key('agent-title')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('agent-option-notes')));
  await tester.pumpAndSettle();
  expect(find.text('Reads and writes notes.'), findsOneWidget);

  // 3. Send a message.
  await tester.enterText(find.byKey(const Key('composer-field')), 'Clean up my notes');
  await tester.pump();
  await tester.tap(find.byKey(const Key('composer-send')));
  await frames();
  expect(backend.calls, contains('create:notes'));
  expect(find.byType(UserBubble), findsOneWidget);

  // 4. A tool card that needs approval.
  backend.emit(const TitleEvent('Clean up my notes'));
  backend.emit(const ThinkingEvent('The user wants old notes removed.'));
  backend.emit(const ToolCallEvent(callId: 'call-1', name: 'delete_all_notes'));
  backend.emit(const ApprovalRequiredEvent(
    callId: 'call-1',
    name: 'delete_all_notes',
    warning: 'This will permanently delete ALL saved notes.',
  ));
  await frames();
  expect(find.byType(ActivityGroup), findsOneWidget);
  expect(find.textContaining('permanently delete ALL'), findsOneWidget);

  // 5. Approve it.
  await tester.tap(find.byKey(const Key('approve-call-1')));
  await frames();
  expect(backend.approvals.single.approved, isTrue);

  // 6. The final Markdown answer.
  backend.emit(const ToolResultEvent(callId: 'call-1', name: 'delete_all_notes', content: '{"deleted": 3}'));
  backend.emit(const FinalEvent('Done. **3 notes** were deleted:\n\n| id | title |\n|---|---|\n| 1 | a |'));
  await backend.finishTurn();
  await tester.pumpAndSettle();
  expect(find.byType(AssistantMessage), findsOneWidget);
  expect(find.byType(Table), findsOneWidget);
  expect(find.text('Thought, used 1 tool'), findsOneWidget);

  // 7. Rename it from the drawer.
  await tester.tap(find.byTooltip('Open chats'));
  await tester.pumpAndSettle();
  final row = find.descendant(of: find.byType(Drawer), matching: find.text('Clean up my notes'));
  await tester.longPress(row);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Rename'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('rename-field')), 'Notes clean-up');
  await tester.tap(find.byKey(const Key('rename-save')));
  await tester.pumpAndSettle();
  expect(find.descendant(of: find.byType(Drawer), matching: find.text('Notes clean-up')), findsOneWidget);
  // 8. Delete it by swiping (rename above used long-press), after confirming.
  await tester.drag(
    find.descendant(of: find.byType(Drawer), matching: find.text('Notes clean-up')),
    const Offset(-500, 0),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('confirm-delete')));
  await tester.pumpAndSettle();
  expect(backend.chats, isEmpty);
  expect(find.text('No chats yet.'), findsOneWidget);
}
