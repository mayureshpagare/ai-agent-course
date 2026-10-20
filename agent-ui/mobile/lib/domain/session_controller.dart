import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors.dart';
import '../core/utils/qr_link_parser.dart';
import '../data/backend/agent_backend.dart';
import '../data/backend/auth_guarded_backend.dart';
import '../data/backend/lan_agent_backend.dart';
import '../data/models/connection_profile.dart';
import '../data/storage/settings_store.dart';

/// Overridden in `main()` (and in tests) with a store backed by real storage.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw UnimplementedError('settingsStoreProvider must be overridden'),
);

/// Builds the backend for a profile. The only place that picks a transport:
/// a hosted profile kind would get its own backend class here.
typedef BackendFactory = AgentBackend Function(ConnectionProfile profile, String credential);

final backendFactoryProvider = Provider<BackendFactory>(
  (ref) => (profile, credential) => switch (profile.authKind) {
        AuthKind.lanToken => LanAgentBackend(baseUrl: profile.baseUrl, token: credential),
      },
);

sealed class SessionState {
  const SessionState();
}

/// Reading saved credentials at start-up.
final class SessionLoading extends SessionState {
  const SessionLoading();
}

final class SignedOut extends SessionState {
  const SignedOut({this.message, this.lastAddress});

  /// Why the app was signed out, shown on the pairing screen.
  final String? message;

  /// The previous server, to prefill the address field.
  final Uri? lastAddress;
}

final class SignedIn extends SessionState {
  const SignedIn(this.profile, this.backend);

  final ConnectionProfile profile;
  final AgentBackend backend;
}

/// Thrown by [SessionController.pair] with a message for the pairing screen.
class PairingException implements Exception {
  const PairingException(this.message);

  final String message;

  @override
  String toString() => message;
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

/// The signed-in backend. Only read it below the signed-in part of the app.
final backendProvider = Provider<AgentBackend>((ref) {
  final session = ref.watch(sessionProvider);
  if (session is SignedIn) return session.backend;
  throw StateError('Not signed in.');
});

/// Signs in and out, and restores the saved server at start-up.
class SessionController extends Notifier<SessionState> {
  SettingsStore get _store => ref.read(settingsStoreProvider);

  /// The signed-in backend, kept here because `onDispose` may not read [state].
  AgentBackend? _backend;

  @override
  SessionState build() {
    ref.onDispose(() => _backend?.close());
    unawaited(_restore());
    return const SessionLoading();
  }

  Future<void> _restore() async {
    await Future<void>.value(); // let build() return before the state changes
    final profile = _store.activeProfile();
    final credential = profile == null ? null : await _store.credential(profile.id);
    if (!ref.mounted) return;
    // Opening the app again skips pairing; a stale token is caught by the
    // first request's 401.
    _replace(profile != null && credential != null
        ? SignedIn(profile, _connect(profile, credential))
        : SignedOut(lastAddress: profile?.baseUrl));
  }

  AgentBackend _connect(ConnectionProfile profile, String credential) => AuthGuardedBackend(
        ref.read(backendFactoryProvider)(profile, credential),
        onUnauthorized: () => unawaited(_unauthorized(profile)),
      );

  /// Checks [token] against the server at [baseUrl] and saves the pair.
  /// Throws [PairingException] with a message for the user.
  Future<void> pair(Uri baseUrl, String token) async {
    final profile = ConnectionProfile(
      id: 'lan:${baseUrl.host}:${baseUrl.port}${baseUrl.path}',
      label: displayAddress(baseUrl),
      baseUrl: baseUrl,
      authKind: AuthKind.lanToken,
      createdAt: DateTime.now(),
    );
    final backend = ref.read(backendFactoryProvider)(profile, token);
    try {
      final status = await backend.auth();
      if (!status.authorized) throw const UnauthorizedException();
    } on UnauthorizedException {
      backend.close();
      throw const PairingException(
          'Wrong access token. Scan the QR code again, or copy the token from agent-ui/backend/data/remote_token.txt.');
    } on BackendException catch (error) {
      backend.close();
      throw PairingException(error.message);
    }
    backend.close();
    await _store.saveProfile(profile, credential: token);
    _replace(SignedIn(profile, _connect(profile, token)));
  }

  Future<void> _unauthorized(ConnectionProfile profile) async {
    final current = state;
    if (current is! SignedIn || current.profile.id != profile.id) return;
    await _store.deleteCredential(profile.id);
    _replace(SignedOut(
      lastAddress: profile.baseUrl,
      message: 'The server no longer accepts this phone\'s access token. '
          'It may have been reset. Pair again to continue.',
    ));
  }

  /// Signs out but keeps the address. With [forget], removes the server too.
  Future<void> disconnect({bool forget = false}) async {
    final current = state;
    if (current is! SignedIn) return;
    if (forget) {
      await _store.removeProfile(current.profile.id);
    } else {
      await _store.deleteCredential(current.profile.id);
    }
    _replace(SignedOut(lastAddress: forget ? null : current.profile.baseUrl));
  }

  void _replace(SessionState next) {
    final previous = _backend;
    _backend = next is SignedIn ? next.backend : null;
    state = next;
    if (!identical(previous, _backend)) previous?.close();
  }
}
