import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../data/models/agent.dart';
import '../../../domain/agents_controller.dart';
import '../../../domain/chat_controller.dart';
import '../../shared/agent_avatar.dart';

const lockedAgentMessage = 'This chat\'s agent is fixed. Start a new chat to use a different agent.';

/// The agent name with a ▾ in the top bar. Opens the agent picker, or, once
/// the chat has started, explains that its agent is fixed.
class AgentTitleButton extends ConsumerWidget {
  const AgentTitleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final agent = ref.watch(currentAgentProvider);
    final selected = ref.watch(selectedAgentProvider);
    final locked = ref.watch(chatControllerProvider.select((chat) => chat.agentLocked));
    final label = agent?.name ?? (selected != null ? '$selected (not found)' : 'Select an agent');

    return Semantics(
      button: true,
      label: locked ? 'Agent: $label. Locked for this chat.' : 'Agent: $label. Change agent.',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('agent-title'),
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (locked) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text(lockedAgentMessage)));
          } else {
            showAgentPicker(context);
          }
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: locked ? palette.muted : palette.text,
                        ),
                  ),
                ),
                if (!locked) Icon(Icons.expand_more_rounded, color: palette.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing every agent; picking one makes it the default.
Future<void> showAgentPicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AgentPickerSheet(),
    );

class _AgentPickerSheet extends ConsumerWidget {
  const _AgentPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agents = ref.watch(agentsProvider);
    final current = ref.watch(currentAgentProvider);
    final palette = context.palette;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Semantics(
                header: true,
                child: Text('Choose an agent', style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            Flexible(
              child: switch (agents) {
                AsyncData(value: final List<Agent> list) when list.isEmpty =>
                  const Padding(padding: EdgeInsets.all(24), child: Text('No agents found on the computer.')),
                AsyncData(value: final List<Agent> list) => ListView(
                    shrinkWrap: true,
                    children: [
                      for (final agent in list)
                        ListTile(
                          key: Key('agent-option-${agent.id}'),
                          leading: AgentAvatar(agent: agent, size: 36),
                          title: Text(agent.name),
                          subtitle: Text(
                            [agent.description, agent.model].where((s) => s.isNotEmpty).join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected: agent.id == current?.id,
                          trailing: agent.id == current?.id
                              ? Icon(Icons.check_rounded, color: palette.primary, semanticLabel: 'Selected')
                              : null,
                          onTap: () {
                            ref.read(selectedAgentProvider.notifier).choose(agent.id);
                            Navigator.pop(context);
                          },
                        ),
                    ],
                  ),
                AsyncError() => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Could not load the agents. Check the connection and try again.'),
                  ),
                _ => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
