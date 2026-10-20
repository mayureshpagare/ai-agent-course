import 'dart:convert';

import 'package:agent_ui_mobile/core/device_services.dart';
import 'package:agent_ui_mobile/core/utils/sse_parser.dart';
import 'package:agent_ui_mobile/data/backend/lan_agent_backend.dart';
import 'package:agent_ui_mobile/data/models/connection_profile.dart';
import 'package:agent_ui_mobile/data/models/stream_event.dart';
import 'package:agent_ui_mobile/data/storage/secret_store.dart';
import 'package:agent_ui_mobile/data/storage/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Checks, on a real device or emulator, the platform pieces the app relies
/// on: Keystore/Keychain storage, preferences, the wakelock, and streaming.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profiles and tokens survive a reload from real storage', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    const secrets = SecureSecretStore();
    final store = SettingsStore(prefs, secrets);
    final profile = ConnectionProfile(
      id: 'smoke',
      label: 'Smoke test',
      baseUrl: Uri.parse('http://192.168.1.20:8000'),
      authKind: AuthKind.lanToken,
      createdAt: DateTime(2026),
    );

    await store.saveProfile(profile, credential: 'device-token');
    final reloaded = SettingsStore(await SharedPreferences.getInstance(), secrets);
    expect(reloaded.activeProfile()!.baseUrl, profile.baseUrl);
    expect(await reloaded.credential('smoke'), 'device-token');

    await reloaded.removeProfile('smoke');
    expect(await reloaded.credential('smoke'), isNull);
    expect(reloaded.profiles(), isEmpty);
  });

  testWidgets('the wakelock turns on and off', (tester) async {
    const PlatformDeviceServices().setKeepAwake(true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(await WakelockPlus.enabled, isTrue);
    const PlatformDeviceServices().setKeepAwake(false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(await WakelockPlus.enabled, isFalse);
  });

  testWidgets('a chunked SSE turn streams through the backend on device', (tester) async {
    final backend = LanAgentBackend(
      baseUrl: Uri.parse('http://192.168.1.20:8000'),
      token: 't',
      client: MockClient.streaming((_, _) async => http.StreamedResponse(
            Stream.fromIterable([
              'data: {"type":"status","message":"Thinking..."}\n\ndata: {"type":"fin',
              'al","content":"done"}\r\n\r\n',
            ].map(utf8.encode)),
            200,
          )),
    );
    final events = await backend.sendMessage('c1', 'hi').toList();
    expect(events.map((e) => e.runtimeType), [StatusEvent, FinalEvent]);
    expect(SseParser().add('data: x\n\n'), ['x']);
  });
}
