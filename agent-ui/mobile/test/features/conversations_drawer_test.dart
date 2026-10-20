import 'dart:typed_data';

import 'package:agent_ui_mobile/app.dart';
import 'package:agent_ui_mobile/core/errors.dart';
import 'package:agent_ui_mobile/data/models/agent.dart';
import 'package:agent_ui_mobile/data/models/chat_item.dart';
import 'package:agent_ui_mobile/domain/chat_controller.dart';
import 'package:agent_ui_mobile/domain/logo_loader.dart';
import 'package:agent_ui_mobile/features/chat/widgets/agent_picker.dart';
import 'package:agent_ui_mobile/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_agent_backend.dart';
import '../support/harness.dart';

void main() {
  late Harness harness;

  Future<void> openDrawer(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Open chats'));
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    harness = await Harness.create();
    harness.backend.seed('Groceries list', agentId: 'notes');
    harness.backend.seed('Sum of numbers', items: const [UserItem('1+2?'), AssistantItem('3')]);
    harness.backend.seed('Tax maths');
    await harness.pumpApp(tester);
    await openDrawer(tester);
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

  testWidgets('lists every chat newest first, across agents', (tester) async {
    await start(tester);
    final titles = tester
        .widgetList<ListTile>(find.byWidgetPredicate((w) => w is ListTile && w.key.toString().contains('chat-row')))
        .map((tile) => (tile.title! as Text).data)
        .toList();
    expect(titles, ['Tax maths', 'Sum of numbers', 'Groceries list']);
  });

  testWidgets('search filters by title, case-insensitively, and can be cleared', (tester) async {
    await start(tester);
    await tester.enterText(find.byKey(const Key('drawer-search')), 'MATHS');
    await tester.pump();
    expect(find.text('Tax maths'), findsOneWidget);
    expect(find.text('Groceries list'), findsNothing);

    await tester.enterText(find.byKey(const Key('drawer-search')), 'nothing like this');
    await tester.pump();
    expect(find.text('No chats match your search.'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.text('Groceries list'), findsOneWidget);
  });

  testWidgets('tapping a chat opens it and closes the drawer', (tester) async {
    await start(tester);
    await tester.tap(find.text('Sum of numbers'));
    await tester.pumpAndSettle();
    expect(harness.backend.calls, contains('get:c2'));
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('assistant: 3'), findsOneWidget);
  });

  testWidgets('long-press, Rename saves the new title', (tester) async {
    await start(tester);
    await tester.longPress(find.text('Tax maths'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('rename-field')), 'Tax return');
    await tester.tap(find.byKey(const Key('rename-save')));
    await tester.pumpAndSettle();

    expect(harness.backend.calls, contains('rename:c3:Tax return'));
    expect(find.text('Tax return'), findsOneWidget);
  });

  testWidgets('long-press, Delete asks first; cancel keeps the chat', (tester) async {
    await start(tester);
    await tester.longPress(find.text('Groceries list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete chat?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(harness.backend.calls.where((c) => c.startsWith('delete')), isEmpty);
    expect(find.text('Groceries list'), findsOneWidget);
  });

  testWidgets('swipe to delete calls the backend after confirming', (tester) async {
    await start(tester);
    await tester.drag(find.text('Groceries list'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(harness.backend.calls, contains('delete:c1'));
    expect(find.text('Groceries list'), findsNothing);
  });

  testWidgets('deleting the open chat starts a new chat', (tester) async {
    await start(tester);
    await tester.tap(find.text('Sum of numbers'));
    await tester.pumpAndSettle();
    await openDrawer(tester);
    await tester.longPress(find.text('Sum of numbers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(container(tester).read(chatControllerProvider).conversationId, isNull);
  });

  testWidgets('New chat and Settings', (tester) async {
    await start(tester);
    await tester.tap(find.text('Sum of numbers'));
    await tester.pumpAndSettle();
    await openDrawer(tester);
    await tester.tap(find.byKey(const Key('drawer-new-chat')));
    await tester.pumpAndSettle();
    expect(container(tester).read(chatControllerProvider).isNewChat, isTrue);

    await openDrawer(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('a failed load shows Retry', (tester) async {
    harness = await Harness.create();
    harness.backend.failWith = const UnreachableException('Cannot reach 192.168.1.20:8000.');
    await harness.pumpApp(tester);
    harness.backend.failWith = null;
    await openDrawer(tester);
    expect(find.text('Retry'), findsOneWidget);
    harness.backend.seed('Back online');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Back online'), findsOneWidget);
  });

  group('agent picker', () {
    testWidgets('a new chat can pick an agent, which becomes the default', (tester) async {
      harness = await Harness.create();
      await harness.pumpApp(tester);
      expect(find.text('Calculator'), findsWidgets);

      await tester.tap(find.byKey(const Key('agent-title')));
      await tester.pumpAndSettle();
      expect(find.text('Choose an agent'), findsOneWidget);
      await tester.tap(find.byKey(const Key('agent-option-notes')));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byKey(const Key('agent-title')), matching: find.text('Notes')), findsOneWidget);
      expect(harness.store.lastAgentId, 'notes');
    });

    testWidgets('is locked once a conversation is open', (tester) async {
      harness = await Harness.create();
      harness.backend.seed('Old chat', agentId: 'notes');
      await harness.pumpApp(tester);
      await openDrawer(tester);
      await tester.tap(find.text('Old chat'));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byKey(const Key('agent-title')), matching: find.text('Notes')), findsOneWidget);
      expect(find.byIcon(Icons.expand_more_rounded), findsNothing, reason: 'no chevron when locked');
      await tester.tap(find.byKey(const Key('agent-title')));
      await tester.pumpAndSettle();
      expect(find.text('Choose an agent'), findsNothing);
      expect(find.text(lockedAgentMessage), findsOneWidget);
      expect(harness.store.lastAgentId, isNull, reason: 'opening a chat does not change the default');
    });

    testWidgets('a chat whose agent was removed says so', (tester) async {
      harness = await Harness.create();
      harness.backend.seed('Orphan', agentId: 'gone');
      await harness.pumpApp(tester);
      await openDrawer(tester);
      await tester.tap(find.text('Orphan'));
      await tester.pumpAndSettle();
      expect(find.text('gone (not found)'), findsOneWidget);
    });
  });

  group('avatars', () {
    testWidgets('show the logo bytes when present, else the initial', (tester) async {
      harness = await Harness.create(
        backend: FakeAgentBackend(agents: const [
          Agent(id: 'calc', name: 'Calculator', logo: '/api/agents/calc/logo?v=1'),
          Agent(id: 'notes', name: 'Notes'),
        ]),
      );
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...harness.overrides,
          logoBytesProvider.overrideWith((ref, url) async => url.path.contains('calc') ? png : null),
        ],
        retry: noAutomaticRetry,
        child: const AgentApp(),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsWidgets, reason: 'calc has a logo');
    });

    test('isSvg tells SVG from raster images', () {
      expect(isSvg(Uint8List.fromList('<svg xmlns="..."/>'.codeUnits)), isTrue);
      expect(isSvg(Uint8List.fromList('  <?xml version="1.0"?><svg/>'.codeUnits)), isTrue);
      expect(isSvg(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47])), isFalse);
    });
  });
}
