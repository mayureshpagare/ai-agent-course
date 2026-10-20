import 'package:agent_ui_mobile/core/theme/app_theme.dart';
import 'package:agent_ui_mobile/data/models/chat_item.dart';
import 'package:agent_ui_mobile/features/chat/widgets/activity_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<(String, bool)> decisions;

  Future<void> pump(WidgetTester tester, List<ActivityStep> steps, {String? liveStatus}) => tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActivityGroup(
                steps: steps,
                liveStatus: liveStatus,
                onDecide: (id, {required approved}) => decisions.add((id, approved)),
              ),
            ),
          ),
        ),
      );

  setUp(() => decisions = []);

  const done = [
    ThinkingItem('I should add the numbers.'),
    ToolItem(id: 't1', name: 'add', args: {'a': 1, 'b': 2.0}, result: '{"sum": 3}', status: ToolStatus.done),
  ];

  testWidgets('collapsed by default with a summary; expands on tap', (tester) async {
    await pump(tester, done);
    expect(find.text('Thought, used 1 tool'), findsOneWidget);
    expect(find.text('I should add the numbers.'), findsNothing);

    await tester.tap(find.byKey(const Key('activity-header')));
    await tester.pumpAndSettle();
    expect(find.text('I should add the numbers.'), findsOneWidget);
    expect(find.textContaining('a=1, b=2'), findsOneWidget);
    expect(find.text('{\n  "sum": 3\n}'), findsOneWidget, reason: 'result is pretty-printed JSON');

    await tester.tap(find.byKey(const Key('activity-header')));
    await tester.pumpAndSettle();
    expect(find.text('I should add the numbers.'), findsNothing);
  });

  testWidgets('shows the live status with a spinner while running', (tester) async {
    await pump(tester, const [ToolItem(id: 't1', name: 'add')], liveStatus: 'Running add...');
    expect(find.text('Running add...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Used 1 tool'), findsNothing);
  });

  testWidgets('is forced open with working Approve and Deny while approval is pending', (tester) async {
    await pump(
      tester,
      const [ToolItem(id: 'd1', name: 'delete_note', args: {'name': 'x'}, status: ToolStatus.approval, warning: 'Deletes a note.')],
      liveStatus: 'Waiting for your approval...',
    );
    expect(find.textContaining('Deletes a note.'), findsOneWidget);

    // Tapping the header can't hide a pending approval.
    await tester.tap(find.byKey(const Key('activity-header')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Deletes a note.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('approve-d1')));
    await tester.tap(find.byKey(const Key('deny-d1')));
    expect(decisions, [('d1', true), ('d1', false)]);
  });
}
