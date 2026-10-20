import 'package:agent_ui_mobile/core/errors.dart';
import 'package:agent_ui_mobile/domain/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  test('restores a saved pair without asking again', () async {
    final harness = await Harness.create();
    final container = await harness.container();
    final session = container.read(sessionProvider);
    expect(session, isA<SignedIn>());
    expect((session as SignedIn).profile.baseUrl, testProfile.baseUrl);
    expect(container.read(backendProvider), isNotNull);
  });

  test('starts signed out when nothing is saved', () async {
    final harness = await Harness.create(signedIn: false);
    final container = await harness.container();
    expect(container.read(sessionProvider), isA<SignedOut>());
    expect(() => container.read(backendProvider), throwsA(anything));
  });

  group('pair', () {
    test('saves the profile and token after /api/auth says authorized', () async {
      final harness = await Harness.create(signedIn: false);
      final container = await harness.container();
      await container.read(sessionProvider.notifier).pair(Uri.parse('http://10.0.0.5:5173'), 'good-token');

      final session = container.read(sessionProvider) as SignedIn;
      expect(session.profile.label, '10.0.0.5:5173');
      expect(harness.store.activeProfile()!.baseUrl.port, 5173);
      expect(await harness.store.credential(session.profile.id), 'good-token');
      expect(harness.backend.calls, contains('auth'));
    });

    test('a wrong token is a clear error and nothing is saved', () async {
      final harness = await Harness.create(signedIn: false);
      final container = await harness.container();
      await expectLater(
        container.read(sessionProvider.notifier).pair(Uri.parse('http://10.0.0.5:8000'), 'bad'),
        throwsA(isA<PairingException>().having((e) => e.message, 'message', startsWith('Wrong access token'))),
      );
      expect(harness.store.profiles(), isEmpty);
      expect(container.read(sessionProvider), isA<SignedOut>());
    });

    test('an unreachable server passes on the network message', () async {
      final harness = await Harness.create(signedIn: false);
      harness.backend.failWith = const UnreachableException('Can\'t reach 10.0.0.5:8000. Not the same Wi-Fi.',
          reason: UnreachableReason.noRoute);
      final container = await harness.container();
      await expectLater(
        container.read(sessionProvider.notifier).pair(Uri.parse('http://10.0.0.5:8000'), 'good-token'),
        throwsA(isA<PairingException>().having((e) => e.message, 'message', contains('Not the same Wi-Fi'))),
      );
    });
  });

  test('a 401 from any request signs out with a message and keeps the address', () async {
    final harness = await Harness.create();
    final container = await harness.container();
    harness.backend.failWith = const UnauthorizedException();
    await expectLater(container.read(backendProvider).conversations(), throwsA(isA<UnauthorizedException>()));
    await pumpEventQueue();

    final session = container.read(sessionProvider);
    expect(session, isA<SignedOut>());
    expect((session as SignedOut).message, contains('Pair again'));
    expect(session.lastAddress, testProfile.baseUrl);
    expect(await harness.store.credential(testProfile.id), isNull);
  });

  test('disconnect keeps the address; forget removes it', () async {
    final harness = await Harness.create();
    final container = await harness.container();
    await container.read(sessionProvider.notifier).disconnect();
    expect((container.read(sessionProvider) as SignedOut).lastAddress, testProfile.baseUrl);
    expect(harness.store.activeProfile(), isNotNull);
    expect(harness.backend.calls, contains('close'));

    await container.read(sessionProvider.notifier).pair(testProfile.baseUrl, 'good-token');
    await container.read(sessionProvider.notifier).disconnect(forget: true);
    expect((container.read(sessionProvider) as SignedOut).lastAddress, isNull);
    expect(harness.store.profiles(), isEmpty);
  });
}
