// End-to-end check on a device against a real running backend with Ollama.
// Skipped unless both values are passed:
//
//   flutter test integration_test/live_e2e_test.dart -d <device> \
//     --dart-define=LIVE_BASE_URL=http://192.168.1.20:8000 \
//     --dart-define=LIVE_TOKEN=<token>
//
// It pairs through the UI, chats with the Calculator agent, triggers the
// notes agent's approval prompt and always DENIES it (so nothing is deleted),
// renames a chat, then deletes the chats it created. Lines starting with
// E2E_SHOT mark moments a host script can screenshot.
import 'package:agent_ui_mobile/app.dart';
import 'package:agent_ui_mobile/data/storage/secret_store.dart';
import 'package:agent_ui_mobile/data/storage/settings_store.dart';
import 'package:agent_ui_mobile/domain/session_controller.dart';
import 'package:agent_ui_mobile/features/chat/widgets/activity_group.dart';
import 'package:agent_ui_mobile/features/chat/widgets/message_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const baseUrl = String.fromEnvironment('LIVE_BASE_URL');
const token = String.fromEnvironment('LIVE_TOKEN');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps in real time until [finder] matches or [timeout] passes.
  Future<void> waitFor(WidgetTester tester, Finder finder,
      {Duration timeout = const Duration(minutes: 3), String? what}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await tester.pump();
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for ${what ?? finder}');
  }

  Future<void> pause(WidgetTester tester, Duration duration) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
  }

  /// Prints a marker and holds the screen still for a host-side screenshot.
  Future<void> shot(WidgetTester tester, String name) async {
    debugPrint('E2E_SHOT:$name');
    await pause(tester, const Duration(seconds: 4));
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('composer-field')), text);
    await tester.pump();
    await tester.tap(find.byKey(const Key('composer-send')));
    await tester.pump();
  }

  Future<void> openDrawer(WidgetTester tester) async {
    if (find.byType(Drawer).evaluate().isNotEmpty) return; // already open
    await tester.tap(find.byTooltip('Open chats'));
    await pause(tester, const Duration(milliseconds: 600));
  }

  /// A chat row in the open drawer (the same text can also be a message
  /// bubble behind it).
  Finder chatRow(String titlePart) =>
      find.descendant(of: find.byType(Drawer), matching: find.textContaining(titlePart)).first;

  Future<void> deleteChat(WidgetTester tester, String titlePart) async {
    await openDrawer(tester);
    await tester.longPress(chatRow(titlePart));
    await pause(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Delete'));
    await pause(tester, const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await pause(tester, const Duration(seconds: 1));
  }

  testWidgets('pair, chat, deny an approval, rename and delete against the real backend',
      skip: baseUrl == '' || token == '', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final store = SettingsStore(prefs, const SecureSecretStore());
    await tester.pumpWidget(ProviderScope(
      retry: noAutomaticRetry,
      overrides: [settingsStoreProvider.overrideWithValue(store)],
      child: const AgentApp(),
    ));
    await pause(tester, const Duration(seconds: 1));

    // Pair by hand with the real address and token.
    await tester.enterText(find.byKey(const Key('pairing-address')), baseUrl);
    await tester.enterText(find.byKey(const Key('pairing-token')), token);
    await tester.ensureVisible(find.byKey(const Key('pairing-connect')));
    await tester.tap(find.byKey(const Key('pairing-connect')));
    await waitFor(tester, find.byKey(const Key('greeting-name')), timeout: const Duration(seconds: 20), what: 'chat');

    // Calculator: a real tool call and a Markdown answer.
    await tester.tap(find.byKey(const Key('agent-title')));
    await pause(tester, const Duration(milliseconds: 800));
    await tester.tap(find.byKey(const Key('agent-option-01-calc-agent')));
    await pause(tester, const Duration(milliseconds: 800));
    await send(tester, 'What is 12 * 7 + 3? Use your tools.');
    await waitFor(tester, find.byType(AssistantMessage), what: 'the calculator answer');
    await pause(tester, const Duration(seconds: 1));
    expect(find.byType(ActivityGroup), findsWidgets, reason: 'the agent used a tool');
    await tester.tap(find.byKey(const Key('activity-header')).first);
    await shot(tester, 'calc-answer');

    // Rename that chat through the drawer.
    await openDrawer(tester);
    await tester.longPress(chatRow('12 * 7'));
    await pause(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Rename'));
    await pause(tester, const Duration(milliseconds: 600));
    await tester.enterText(find.byKey(const Key('rename-field')), 'E2E calculator chat');
    await tester.tap(find.byKey(const Key('rename-save')));
    await pause(tester, const Duration(seconds: 1));
    expect(chatRow('E2E calculator chat'), findsOneWidget);
    await shot(tester, 'drawer-renamed');
    await tester.tap(find.byKey(const Key('drawer-new-chat')));
    await pause(tester, const Duration(seconds: 1));

    // Notes agent: trigger the approval prompt, then DENY it.
    await tester.tap(find.byKey(const Key('agent-title')));
    await pause(tester, const Duration(milliseconds: 800));
    await tester.tap(find.byKey(const Key('agent-option-02-file-notes-agent')));
    await pause(tester, const Duration(milliseconds: 800));
    await send(
      tester,
      'Call the delete_all_notes tool exactly once. If it is cancelled, do not call any other tool; '
      'just tell me it was cancelled.',
    );
    final deny = find.byWidgetPredicate((w) => w is FilledButton && '${w.key}'.contains('deny-'));
    await waitFor(tester, deny, what: 'the approval prompt');
    await shot(tester, 'approval');
    await tester.tap(deny.first);
    await waitFor(tester, find.byType(AssistantMessage), what: 'the reply after denying');
    await shot(tester, 'denied');

    // Clean up: delete both chats this test created, then forget the server.
    await deleteChat(tester, 'E2E calculator chat');
    await deleteChat(tester, 'delete_all_notes');
    await shot(tester, 'cleaned-up');
    await store.removeProfile(store.activeProfile()!.id);
  });
}
