import 'package:agent_ui_mobile/core/errors.dart';
import 'package:agent_ui_mobile/features/pairing/pairing_screen.dart';
import 'package:agent_ui_mobile/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  late Harness harness;

  Future<void> openSettings(WidgetTester tester) async {
    harness = await Harness.create();
    await harness.pumpApp(tester);
    await tester.tap(find.byTooltip('Open chats'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  }

  testWidgets('shows the server and a connected status', (tester) async {
    await openSettings(tester);
    expect(find.text('192.168.1.20:8000'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('shows why the connection check failed, and can check again', (tester) async {
    await openSettings(tester);
    harness.backend.failWith = const UnreachableException('Can not reach 192.168.1.20:8000.');
    await tester.tap(find.byTooltip('Check again'));
    await tester.pumpAndSettle();
    expect(find.text('Can not reach 192.168.1.20:8000.'), findsOneWidget);
  });

  testWidgets('Disconnect returns to pairing with the address filled in', (tester) async {
    await openSettings(tester);
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.byType(PairingScreen), findsOneWidget);
    final address = tester.widget<TextField>(find.byKey(const Key('pairing-address')));
    expect(address.controller!.text, '192.168.1.20:8000');
    expect(harness.store.activeProfile(), isNotNull);
    expect(await harness.store.credential(testProfile.id), isNull);
  });

  testWidgets('Forget asks first, then removes the server', (tester) async {
    await openSettings(tester);
    await tester.tap(find.text('Forget this server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.text('Forget this server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forget'));
    await tester.pumpAndSettle();
    expect(find.byType(PairingScreen), findsOneWidget);
    expect(harness.store.profiles(), isEmpty);
  });

  testWidgets('the theme choice applies at once and is saved', (tester) async {
    await openSettings(tester);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(SettingsScreen))).brightness, Brightness.dark);
    expect(harness.store.themeMode, 'dark');
  });
}
