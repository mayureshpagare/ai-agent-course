import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/tokens.dart';
import '../../domain/agents_controller.dart';
import '../../domain/session_controller.dart';

/// Temporary home screen until the chat UI lands: shows that pairing worked
/// and which agents the server offers.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final agents = ref.watch(agentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent UI'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (session is SignedIn) Text('Connected to ${session.profile.label}'),
          const SizedBox(height: 16),
          ...switch (agents) {
            AsyncData(:final value) => [for (final agent in value) ListTile(title: Text(agent.name))],
            AsyncError(:final error) => [Text('$error', style: TextStyle(color: context.palette.error))],
            _ => [const Center(child: CircularProgressIndicator())],
          },
        ],
      ),
    );
  }
}
