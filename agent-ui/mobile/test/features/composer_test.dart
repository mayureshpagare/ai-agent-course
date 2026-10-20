import 'package:agent_ui_mobile/core/theme/app_theme.dart';
import 'package:agent_ui_mobile/features/chat/widgets/composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final field = find.byKey(const Key('composer-field'));
  final send = find.byKey(const Key('composer-send'));
  final stop = find.byKey(const Key('composer-stop'));

  late List<String> sent;
  late int stops;

  Future<void> pump(WidgetTester tester, {bool busy = false, bool enabled = true}) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Composer(
            agentName: 'Calculator',
            enabled: enabled,
            busy: busy,
            onSend: sent.add,
            onStop: () => stops++,
          ),
        ),
      ),
    ));
  }

  IconButton button(WidgetTester tester, Finder finder) =>
      tester.widget<IconButton>(find.descendant(of: finder, matching: find.byType(IconButton)));

  setUp(() {
    sent = [];
    stops = 0;
  });

  testWidgets('send is disabled while the input is empty or blank', (tester) async {
    await pump(tester);
    expect(button(tester, send).onPressed, isNull);
    await tester.enterText(field, '   ');
    await tester.pump();
    expect(button(tester, send).onPressed, isNull);
    expect(find.text('Runs locally with Ollama. Agents can make mistakes.'), findsOneWidget);
    expect(find.text('Message Calculator'), findsOneWidget);
  });

  testWidgets('sends trimmed text and clears the box', (tester) async {
    await pump(tester);
    await tester.enterText(field, '  What is 2+2?  ');
    await tester.pump();
    await tester.tap(send);
    await tester.pump();
    expect(sent, ['What is 2+2?']);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
  });

  testWidgets('becomes a stop button while busy', (tester) async {
    await pump(tester, busy: true);
    expect(send, findsNothing);
    expect(find.byTooltip('Stop'), findsOneWidget);
    await tester.tap(stop);
    expect(stops, 1);
    expect(sent, isEmpty);
  });

  testWidgets('Enter adds a new line instead of sending', (tester) async {
    await pump(tester);
    final textField = tester.widget<TextField>(field);
    expect(textField.keyboardType, TextInputType.multiline);
    expect(textField.textInputAction, TextInputAction.newline);
    expect(textField.maxLines, 6);

    await tester.enterText(field, 'line one');
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.enterText(field, 'line one\nline two');
    await tester.pump();
    expect(sent, isEmpty);
    expect(tester.widget<TextField>(field).controller!.text, 'line one\nline two');
  });

  testWidgets('disabled without an agent', (tester) async {
    await pump(tester, enabled: false);
    expect(tester.widget<TextField>(field).enabled, isFalse);
    expect(button(tester, send).onPressed, isNull);
  });
}
