import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/agent.dart';
import 'session_controller.dart';

/// Every agent the server offers.
final agentsProvider = FutureProvider<List<Agent>>((ref) => ref.watch(backendProvider).agents());

/// The agent new chats use. Picking one in the agent picker also saves it as
/// the default for next time; opening a chat follows that chat's agent
/// without changing the saved default, as in the web app.
final selectedAgentProvider = NotifierProvider<SelectedAgentController, String?>(SelectedAgentController.new);

class SelectedAgentController extends Notifier<String?> {
  @override
  String? build() => ref.read(settingsStoreProvider).lastAgentId;

  /// Chosen in the picker: remembered as the default for new chats.
  void choose(String agentId) {
    state = agentId;
    ref.read(settingsStoreProvider).setLastAgentId(agentId).ignore();
  }

  /// An opened chat's agent: shown, but not saved as the default.
  void follow(String agentId) => state = agentId;
}
