import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'domain/session_controller.dart';
import 'features/chat/chat_screen.dart';
import 'features/pairing/pairing_screen.dart';
import 'features/pairing/scan_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/theme_mode_controller.dart';

abstract final class Routes {
  static const loading = '/loading';
  static const pair = '/pair';
  static const scan = '/pair/scan';
  static const chat = '/';
  static const settings = '/settings';
}

/// Riverpod providers never retry on their own: failures show an error with
/// a Retry button instead.
Duration? noAutomaticRetry(int retryCount, Object error) => null;

/// Sends the user to pairing whenever they are signed out, and away from it
/// once they are signed in.
final routerProvider = Provider<GoRouter>((ref) {
  final sessionChanged = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => sessionChanged.value++);

  final router = GoRouter(
    initialLocation: Routes.chat,
    refreshListenable: sessionChanged,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onPairing = location.startsWith(Routes.pair);
      return switch (ref.read(sessionProvider)) {
        SessionLoading() => location == Routes.loading ? null : Routes.loading,
        SignedOut() => onPairing ? null : Routes.pair,
        SignedIn() => onPairing || location == Routes.loading ? Routes.chat : null,
      };
    },
    routes: [
      GoRoute(path: Routes.loading, builder: (_, _) => const _LoadingScreen()),
      GoRoute(
        path: Routes.pair,
        builder: (_, _) => const PairingScreen(),
        routes: [GoRoute(path: 'scan', builder: (_, _) => const ScanScreen())],
      ),
      GoRoute(path: Routes.chat, builder: (_, _) => const ChatScreen()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    sessionChanged.dispose();
  });
  return router;
});

class AgentApp extends ConsumerWidget {
  const AgentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Agent UI',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ref.watch(themeModeProvider),
        routerConfig: ref.watch(routerProvider),
      );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading')));
}
