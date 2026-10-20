import 'package:agent_ui_mobile/app.dart';
import 'package:agent_ui_mobile/core/device_services.dart';
import 'package:agent_ui_mobile/data/models/connection_profile.dart';
import 'package:agent_ui_mobile/data/storage/secret_store.dart';
import 'package:agent_ui_mobile/data/storage/settings_store.dart';
import 'package:agent_ui_mobile/domain/session_controller.dart';
import 'package:agent_ui_mobile/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_agent_backend.dart';

class FakeDeviceServices implements DeviceServices {
  final List<bool> keepAwake = [];
  int approvalHaptics = 0;

  bool get awake => keepAwake.isNotEmpty && keepAwake.last;

  @override
  void setKeepAwake(bool on) => keepAwake.add(on);

  @override
  void approvalNeeded() => approvalHaptics++;
}

final testProfile = ConnectionProfile(
  id: 'lan:192.168.1.20:8000',
  label: '192.168.1.20:8000',
  baseUrl: Uri.parse('http://192.168.1.20:8000'),
  authKind: AuthKind.lanToken,
  createdAt: DateTime(2026),
);

/// Everything a test needs to run the app against a [FakeAgentBackend].
class Harness {
  Harness._(this.backend, this.store, this.secrets, this.devices);

  final FakeAgentBackend backend;
  final SettingsStore store;
  final MemorySecretStore secrets;
  final FakeDeviceServices devices;

  /// Builds a harness. With [signedIn], a paired server is already saved, as
  /// when the app is opened again after pairing.
  static Future<Harness> create({FakeAgentBackend? backend, bool signedIn = true, String? lastAgentId}) async {
    SharedPreferences.setMockInitialValues({'last_agent_id': ?lastAgentId});
    final secrets = MemorySecretStore();
    final store = SettingsStore(await SharedPreferences.getInstance(), secrets);
    final fake = backend ?? FakeAgentBackend();
    if (signedIn) await store.saveProfile(testProfile, credential: fake.token);
    return Harness._(fake, store, secrets, FakeDeviceServices());
  }

  List<Override> get overrides => [
        settingsStoreProvider.overrideWithValue(store),
        backendFactoryProvider.overrideWithValue((profile, credential) {
          backend.presentedToken = credential;
          return backend;
        }),
        deviceServicesProvider.overrideWithValue(devices),
        appVersionProvider.overrideWith((ref) async => '0.1.0 (1)'),
      ];

  /// A container whose session has finished restoring.
  Future<ProviderContainer> container() async {
    final container = ProviderContainer.test(overrides: overrides, retry: noAutomaticRetry);
    container.listen(sessionProvider, (_, _) {});
    await pumpEventQueue();
    return container;
  }

  /// Pumps the whole app.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(overrides: overrides, retry: noAutomaticRetry, child: const AgentApp()));
    await tester.pumpAndSettle();
  }
}

/// Wraps [child] in a themed MaterialApp for single-widget tests.
Widget themed(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: child),
    );
