import 'package:agent_ui_mobile/core/errors.dart';
import 'package:agent_ui_mobile/data/backend/auth_guarded_backend.dart';
import 'package:agent_ui_mobile/data/models/agent.dart';
import 'package:agent_ui_mobile/data/models/connection_profile.dart';
import 'package:agent_ui_mobile/data/storage/secret_store.dart';
import 'package:agent_ui_mobile/data/storage/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_agent_backend.dart';

ConnectionProfile profile(String id, String url) => ConnectionProfile(
      id: id,
      label: id,
      baseUrl: Uri.parse(url),
      authKind: AuthKind.lanToken,
      createdAt: DateTime(2026),
    );

void main() {
  group('SettingsStore', () {
    late MemorySecretStore secrets;
    late SettingsStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      secrets = MemorySecretStore();
      store = SettingsStore(await SharedPreferences.getInstance(), secrets);
    });

    test('saves profiles as a list, credentials in the secret store', () async {
      await store.saveProfile(profile('a', 'http://1.2.3.4:8000'), credential: 'tok-a');
      await store.saveProfile(profile('b', 'http://5.6.7.8:8000'), credential: 'tok-b');
      expect(store.profiles().map((p) => p.id), ['a', 'b']);
      expect(store.activeProfile()!.id, 'b');
      expect(await store.credential('a'), 'tok-a');
      expect(secrets.values.values, isNot(contains(contains('http'))));

      await store.saveProfile(profile('a', 'http://9.9.9.9:8000'), credential: 'tok-a2');
      expect(store.profiles().map((p) => p.id), ['b', 'a']);
      expect(store.activeProfile()!.baseUrl.host, '9.9.9.9');
    });

    test('deleteCredential keeps the profile; removeProfile drops both', () async {
      await store.saveProfile(profile('a', 'http://1.2.3.4:8000'), credential: 't');
      await store.deleteCredential('a');
      expect(store.activeProfile(), isNotNull);
      expect(await store.credential('a'), isNull);

      await store.saveProfile(profile('a', 'http://1.2.3.4:8000'), credential: 't');
      await store.removeProfile('a');
      expect(store.profiles(), isEmpty);
      expect(store.activeProfile(), isNull);
      expect(await store.credential('a'), isNull);
    });

    test('remembers the last agent and theme', () async {
      expect(store.lastAgentId, isNull);
      expect(store.themeMode, 'system');
      await store.setLastAgentId('calc');
      await store.setThemeMode('dark');
      expect(store.lastAgentId, 'calc');
      expect(store.themeMode, 'dark');
    });

    test('ignores corrupt saved profiles', () async {
      SharedPreferences.setMockInitialValues({'connection_profiles': '{oops'});
      final corrupt = SettingsStore(await SharedPreferences.getInstance(), secrets);
      expect(corrupt.profiles(), isEmpty);
    });
  });

  group('AuthGuardedBackend', () {
    test('calls onUnauthorized on a 401 from any call and rethrows', () async {
      final fake = FakeAgentBackend()..failWith = const UnauthorizedException();
      var signedOut = 0;
      final guarded = AuthGuardedBackend(fake, onUnauthorized: () => signedOut++);
      await expectLater(guarded.agents(), throwsA(isA<UnauthorizedException>()));
      await expectLater(guarded.rename('x', 'y'), throwsA(isA<UnauthorizedException>()));
      expect(signedOut, 2);
    });

    test('treats authorized=false as unauthorized', () async {
      final fake = FakeAgentBackend()..presentedToken = 'wrong';
      var signedOut = false;
      final guarded = AuthGuardedBackend(fake, onUnauthorized: () => signedOut = true);
      await expectLater(guarded.auth(), throwsA(isA<UnauthorizedException>()));
      expect(signedOut, isTrue);
    });

    test('passes other calls and errors through', () async {
      final fake = FakeAgentBackend();
      var signedOut = false;
      final guarded = AuthGuardedBackend(fake, onUnauthorized: () => signedOut = true);
      final chat = fake.seed('Hi');
      expect((await guarded.auth()).authorized, isTrue);
      expect(await guarded.conversations(), hasLength(1));
      expect((await guarded.createConversation('calc')).agentId, 'calc');
      expect((await guarded.conversation(chat.id)).conversation.title, 'Hi');
      await guarded.approve(chat.id, 'c', approved: true);
      await guarded.stop(chat.id);
      await guarded.delete(chat.id);
      expect(guarded.logoUrl(const Agent(id: 'a', name: 'a')), isNull);
      expect(guarded.authHeaders, fake.authHeaders);

      final events = guarded.sendMessage('c2', 'hi');
      final errors = <Object>[];
      final sub = events.listen(null, onError: errors.add);
      fake.failTurn(const UnauthorizedException());
      fake.failTurn(const UnreachableException('gone'));
      await fake.finishTurn();
      await sub.cancel();
      expect(errors, [isA<UnauthorizedException>(), isA<UnreachableException>()]);
      expect(signedOut, isTrue);

      guarded.close();
      expect(fake.calls.last, 'close');
    });
  });
}
