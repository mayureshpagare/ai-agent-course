// Optional check against a real running backend. Skipped unless both values
// are passed, for example:
//
//   flutter test test/live_smoke_test.dart \
//     --dart-define=LIVE_BASE_URL=http://192.168.1.20:8000 \
//     --dart-define=LIVE_TOKEN=<token from remote_token.txt>
//
// Use the computer's LAN address, not localhost: the backend trusts requests
// from its own machine without a token, so localhost would not test auth.
@TestOn('vm')
library;

import 'package:agent_ui_mobile/core/errors.dart';
import 'package:agent_ui_mobile/data/backend/lan_agent_backend.dart';
import 'package:flutter_test/flutter_test.dart';

const baseUrl = String.fromEnvironment('LIVE_BASE_URL');
const token = String.fromEnvironment('LIVE_TOKEN');
const skip = baseUrl == '' || token == '' ? 'Pass --dart-define=LIVE_BASE_URL=... and LIVE_TOKEN=... to run.' : false;

void main() {
  group('live backend', skip: skip, () {
    test('the token is accepted and agents are listed', () async {
      final backend = LanAgentBackend(baseUrl: Uri.parse(baseUrl), token: token);
      addTearDown(backend.close);

      final status = await backend.auth();
      expect(status.authorized, isTrue, reason: 'the token should be accepted');

      final agents = await backend.agents();
      expect(agents, isNotEmpty);
      for (final agent in agents) {
        expect(agent.id, isNotEmpty);
        if (backend.logoUrl(agent) case final Uri logo) expect(logo.queryParameters, contains('v'));
      }
      expect(await backend.conversations(), isA<List<Object>>());
    });

    test('a wrong token is rejected', () async {
      final backend = LanAgentBackend(baseUrl: Uri.parse(baseUrl), token: 'definitely-wrong');
      addTearDown(backend.close);
      expect((await backend.auth()).authorized, isFalse);
      await expectLater(backend.agents(), throwsA(isA<UnauthorizedException>()));
    });
  });
}
