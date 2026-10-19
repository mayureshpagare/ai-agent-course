import '../../core/utils/json.dart';

/// An agent from `GET /api/agents`.
class Agent {
  const Agent({
    required this.id,
    required this.name,
    this.description = '',
    this.model = '',
    this.logo,
  });

  factory Agent.fromJson(Json json) => Agent(
        id: requireString(json, 'id'),
        name: optionalString(json, 'name') ?? requireString(json, 'id'),
        description: optionalString(json, 'description') ?? '',
        model: optionalString(json, 'model') ?? '',
        logo: optionalString(json, 'logo'),
      );

  final String id;
  final String name;
  final String description;
  final String model;

  /// Server path of the logo, e.g. `/api/agents/x/logo?v=1712345678`, or null
  /// when the agent has none. The `v` query changes when the file changes.
  /// Turn it into a URL with `AgentBackend.logoUrl`.
  final String? logo;

  /// Initial shown when there is no logo.
  String get initial => name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();

  Json toJson() => {'id': id, 'name': name, 'description': description, 'model': model, 'logo': logo};
}
