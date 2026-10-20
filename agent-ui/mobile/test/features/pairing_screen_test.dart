import 'package:agent_ui_mobile/core/errors.dart';
import 'package:agent_ui_mobile/features/chat/chat_screen.dart';
import 'package:agent_ui_mobile/features/pairing/pairing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  final address = find.byKey(const Key('pairing-address'));
  final token = find.byKey(const Key('pairing-token'));
  final connect = find.byKey(const Key('pairing-connect'));

  /// Taps Connect, scrolling it into view first.
  Future<void> tapConnect(WidgetTester tester) async {
    await tester.ensureVisible(connect);
    await tester.tap(connect);
  }

  Future<Harness> openPairing(WidgetTester tester) async {
    final harness = await Harness.create(signedIn: false);
    await harness.pumpApp(tester);
    expect(find.byType(PairingScreen), findsOneWidget);
    return harness;
  }

  testWidgets('validates the address and token before connecting', (tester) async {
    final harness = await openPairing(tester);

    await tapConnect(tester);
    await tester.pump();
    expect(find.textContaining('Enter the computer\'s address'), findsOneWidget);

    await tester.enterText(address, '192.168.1.20:port');
    await tapConnect(tester);
    await tester.pump();
    expect(find.textContaining('doesn\'t look like an address'), findsOneWidget);

    await tester.enterText(address, '192.168.1.20');
    await tapConnect(tester);
    await tester.pump();
    expect(find.text('Paste the access token.'), findsOneWidget);
    expect(harness.backend.calls, isEmpty);
  });

  testWidgets('a wrong token shows a clear error and stays on pairing', (tester) async {
    final harness = await openPairing(tester);
    await tester.enterText(address, '192.168.1.20:8000');
    await tester.enterText(token, 'wrong');
    await tapConnect(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Wrong access token'), findsOneWidget);
    expect(find.byType(PairingScreen), findsOneWidget);
    expect(harness.store.profiles(), isEmpty);
  });

  testWidgets('an unreachable server shows the network message', (tester) async {
    final harness = await openPairing(tester);
    harness.backend.failWith = const UnreachableException(
      'Timed out reaching 192.168.1.20:8000. Make sure your phone is on the same Wi-Fi as the computer.',
      reason: UnreachableReason.timeout,
    );
    await tester.enterText(address, '192.168.1.20:8000');
    await tester.enterText(token, 'good-token');
    await tapConnect(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('same Wi-Fi as the computer'), findsOneWidget);
  });

  testWidgets('a successful pair opens the chat', (tester) async {
    final harness = await openPairing(tester);
    await tester.enterText(address, '192.168.1.20:8000');
    await tester.enterText(token, 'good-token');
    await tapConnect(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(harness.store.activeProfile()!.label, '192.168.1.20:8000');
    expect(await harness.store.credential(harness.store.activeProfile()!.id), 'good-token');
  });

  testWidgets('a sign-in link pasted into the address field pairs directly', (tester) async {
    await openPairing(tester);
    await tester.enterText(address, 'http://192.168.1.20:5173/api/login?token=good-token');
    await tapConnect(tester);
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
  });

  testWidgets('the token can be shown and hidden', (tester) async {
    await openPairing(tester);
    TextField field() => tester.widget<TextField>(token);
    expect(field().obscureText, isTrue);
    await tester.ensureVisible(find.byTooltip('Show token'));
    await tester.tap(find.byTooltip('Show token'));
    await tester.pump();
    expect(field().obscureText, isFalse);
  });

  testWidgets('reopening the app after pairing skips the pairing screen', (tester) async {
    final harness = await Harness.create();
    await harness.pumpApp(tester);
    expect(find.byType(PairingScreen), findsNothing);
    expect(find.byType(ChatScreen), findsOneWidget);
  });
}
