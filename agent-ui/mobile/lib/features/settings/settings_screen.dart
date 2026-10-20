import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/errors.dart';
import '../../core/theme/tokens.dart';
import '../../domain/session_controller.dart';
import 'theme_mode_controller.dart';

/// "1.2.0 (5)"; overridden in tests.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// Checks the saved token against the server each time Settings opens.
final connectionCheckProvider = FutureProvider.autoDispose<void>((ref) async {
  await ref.watch(backendProvider).auth();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session is! SignedIn) return const Scaffold();
    final palette = context.palette;
    final check = ref.watch(connectionCheckProvider);
    final version = ref.watch(appVersionProvider);

    final (statusText, statusColor, statusIcon) = switch (check) {
      AsyncData() => ('Connected', palette.tertiary, Icons.check_circle_rounded),
      AsyncError(:final error) => (
          error is BackendException ? error.message : 'Not connected.',
          palette.error,
          Icons.error_rounded,
        ),
      _ => ('Checking...', palette.muted, Icons.sync_rounded),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _Header('Connection'),
          ListTile(
            leading: const Icon(Icons.computer_rounded),
            title: const Text('Server'),
            subtitle: Text(session.profile.label),
          ),
          ListTile(
            leading: Icon(statusIcon, color: statusColor),
            title: const Text('Status'),
            subtitle: Text(statusText, style: TextStyle(color: statusColor)),
            trailing: check.isLoading
                ? null
                : IconButton(
                    tooltip: 'Check again',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => ref.invalidate(connectionCheckProvider),
                  ),
          ),
          ListTile(
            leading: const Icon(Icons.link_off_rounded),
            title: const Text('Disconnect'),
            subtitle: const Text('Sign out. The address is kept for next time.'),
            onTap: () => ref.read(sessionProvider.notifier).disconnect(),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: palette.error),
            title: Text('Forget this server', style: TextStyle(color: palette.error)),
            subtitle: const Text('Remove the address and access token from this phone.'),
            onTap: () => _confirmForget(context, ref),
          ),
          const _Header('Appearance'),
          // Radio rows rather than a segmented button: they still fit at 320dp
          // with large text.
          RadioGroup<ThemeMode>(
            groupValue: ref.watch(themeModeProvider),
            onChanged: (mode) {
              if (mode != null) ref.read(themeModeProvider.notifier).set(mode);
            },
            child: const Column(
              children: [
                RadioListTile(value: ThemeMode.system, title: Text('System'), secondary: Icon(Icons.brightness_auto)),
                RadioListTile(value: ThemeMode.light, title: Text('Light'), secondary: Icon(Icons.light_mode)),
                RadioListTile(value: ThemeMode.dark, title: Text('Dark'), secondary: Icon(Icons.dark_mode)),
              ],
            ),
          ),
          const _Header('About'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('App version'),
            subtitle: Text(version.value ?? '...'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmForget(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget this server?'),
        content: const Text('You will need to scan the QR code or enter the token again to reconnect.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Forget')),
        ],
      ),
    );
    if (confirmed ?? false) await ref.read(sessionProvider.notifier).disconnect(forget: true);
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.palette.primary),
          ),
        ),
      );
}
